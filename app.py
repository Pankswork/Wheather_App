from dotenv import load_dotenv
from flask import Flask, request, render_template, jsonify
import requests
import os
import time
import mysql.connector
from datetime import datetime
from mysql.connector import Error
import logging
import boto3
from botocore.exceptions import ClientError
import json
from prometheus_client import Counter, Histogram, Gauge, generate_latest, CollectorRegistry, CONTENT_TYPE_LATEST
from werkzeug.middleware.dispatcher import DispatcherMiddleware
from prometheus_client import make_wsgi_app

app = Flask(__name__)

# Configure structured logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Prometheus Metrics
registry = CollectorRegistry()

REQUEST_COUNT = Counter('weather_requests_total', 'Total weather requests', ['method', 'endpoint', 'status'], registry=registry)
REQUEST_DURATION = Histogram('weather_request_duration_seconds', 'Request duration', registry=registry)
ACTIVE_CONNECTIONS = Gauge('weather_active_connections', 'Active database connections', registry=registry)
API_RESPONSE_TIME = Histogram('weather_api_response_time_seconds', 'Weather API response time', registry=registry)
WEATHER_QUERIES = Counter('weather_queries_total', 'Total weather queries', ['city', 'status'], registry=registry)
DATABASE_QUERIES = Counter('database_queries_total', 'Total database queries', ['operation'], registry=registry)

# CloudWatch client for custom metrics
cloudwatch = boto3.client('cloudwatch', region_name=os.getenv('AWS_REGION', 'us-east-1'))

# Weather API Setup
load_dotenv()

API_KEY = os.getenv("WEATHER_API_KEY")
BASE_URL = "http://api.weatherapi.com/v1/current.json"

# Validate API key is set
if not API_KEY:
    logger.error("WEATHER_API_KEY environment variable is not set!")

# MySQL connection with connection pooling
db_config = {
    'host': os.getenv("DB_HOST"),
    'user': os.getenv("DB_USER"),
    'password': os.getenv("DB_PASSWORD"),
    'database': os.getenv("DB_NAME"),
    'pool_name': 'weather_app_pool',
    'pool_size': 5,
    'pool_reset_session': True
}

def get_db_connection():
    try:
        conn = mysql.connector.connect(**db_config)
        ACTIVE_CONNECTIONS.inc()
        DATABASE_QUERIES.labels(operation='connect').inc()
        return conn
    except Error as err:
        logger.error(f"Database connection error: {err}")
        DATABASE_QUERIES.labels(operation='connect_error').inc()
        raise

def release_db_connection(conn):
    try:
        if conn.is_connected():
            conn.close()
            ACTIVE_CONNECTIONS.dec()
            DATABASE_QUERIES.labels(operation='disconnect').inc()
    except Error as err:
        logger.error(f"Error closing database connection: {err}")
        DATABASE_QUERIES.labels(operation='disconnect_error').inc()

def put_custom_metric(metric_name, value, unit='Count'):
    try:
        cloudwatch.put_metric_data(
            Namespace='WeatherApp',
            MetricData=[
                {
                    'MetricName': metric_name,
                    'Value': value,
                    'Unit': unit,
                    'Timestamp': datetime.utcnow()
                }
            ]
        )
    except ClientError as err:
        logger.error(f"Failed to put custom metric {metric_name}: {err}")

@app.before_request
def before_request():
    request.start_time = time.time()

@app.after_request
def after_request(response):
    duration = time.time() - request.start_time
    REQUEST_DURATION.observe(duration)
    REQUEST_COUNT.labels(
        method=request.method,
        endpoint=request.endpoint or 'unknown',
        status=response.status_code
    ).inc()
    
    # Log slow requests
    if duration > 2.0:
        logger.warning(f"Slow request: {request.method} {request.endpoint} took {duration:.2f}s")
    
    return response

@app.route("/", methods=["GET", "POST"])
def index():
    weather_data = None
    background = "default.jpg"

    if request.method == "POST":
        city = request.form.get("city", "").strip()
        
        # Input validation
        if not city or len(city) > 50:
            weather_data = {"error": "Invalid city name"}
            WEATHER_QUERIES.labels(city=city, status='validation_error').inc()
            return render_template("index.html", weather=weather_data, history=[], background=background)
        
        # Sanitize input
        city = ''.join(c for c in city if c.isalnum() or c.isspace() or c in '-.,')
        
        try:
            start_time = time.time()
            params = {"key": API_KEY, "q": city}
            response = requests.get(BASE_URL, params=params, timeout=10)
            api_duration = time.time() - start_time
            API_RESPONSE_TIME.observe(api_duration)
            
            if response.status_code == 200:
                data = response.json()
                temperature = str(data["current"]["temp_c"]) + " °C"
                description = data["current"]["condition"]["text"]
                temp_c = data["current"]["temp_c"]

                # Save to DB with connection pooling
                conn = get_db_connection()
                try:
                    cursor = conn.cursor()
                    cursor.execute(
                        "INSERT INTO weather_history (city, temperature, description) VALUES (%s, %s, %s)",
                        (city, temperature, description)
                    )
                    conn.commit()
                    DATABASE_QUERIES.labels(operation='insert').inc()
                    
                    # Custom metrics
                    put_custom_metric('SuccessfulWeatherQueries', 1, 'Count')
                    WEATHER_QUERIES.labels(city=city, status='success').inc()
                    
                except Error as err:
                    logger.error(f"Database error: {err}")
                    conn.rollback()
                    DATABASE_QUERIES.labels(operation='insert_error').inc()
                finally:
                    cursor.close()
                    release_db_connection(conn)

                # Choose background based on weather
                if "rain" in description.lower():
                    background = "rain.jpg"
                elif "cloud" in description.lower():
                    background = "cloudy.jpg"
                elif "sun" in description.lower() or temp_c >= 30:
                    background = "sunny.jpg"
                elif temp_c < 15:
                    background = "cold.jpg"
                else:
                    background = "default.jpg"

                weather_data = {
                    "city": city,
                    "temperature": temperature,
                    "description": description
                }
                
                logger.info(f"Weather query successful for city: {city}")
            else:
                weather_data = {"error": "City not found or API error"}
                put_custom_metric('FailedWeatherQueries', 1, 'Count')
                WEATHER_QUERIES.labels(city=city, status='api_error').inc()
                logger.warning(f"Weather API failed for city: {city}, status: {response.status_code}")
                
        except requests.RequestException as err:
            logger.error(f"Weather API error: {err}")
            weather_data = {"error": "Service temporarily unavailable"}
            put_custom_metric('APIErrorCount', 1, 'Count')
            WEATHER_QUERIES.labels(city=city, status='request_error').inc()
        except Exception as err:
            logger.error(f"Unexpected error: {err}")
            weather_data = {"error": "Internal server error"}
            put_custom_metric('UnexpectedErrorCount', 1, 'Count')
            WEATHER_QUERIES.labels(city=city, status='unexpected_error').inc()

    # Get history with connection pooling
    conn = get_db_connection()
    try:
        cursor = conn.cursor()
        cursor.execute("SELECT city, temperature, description, timestamp FROM weather_history ORDER BY timestamp DESC LIMIT 10")
        history = cursor.fetchall()
        DATABASE_QUERIES.labels(operation='select').inc()
    except Error as err:
        logger.error(f"Database error fetching history: {err}")
        history = []
        DATABASE_QUERIES.labels(operation='select_error').inc()
    finally:
        cursor.close()
        release_db_connection(conn)

    return render_template("index.html", weather=weather_data, history=history, background=background)


@app.route("/history")
def history():
    conn = get_db_connection()
    try:
        cursor = conn.cursor()
        cursor.execute("SELECT city, temperature, description, timestamp FROM weather_history ORDER BY timestamp DESC")
        rows = cursor.fetchall()
        DATABASE_QUERIES.labels(operation='select_history').inc()
        return render_template("history.html", history=rows)
    except Error as err:
        logger.error(f"Database error: {err}")
        DATABASE_QUERIES.labels(operation='select_history_error').inc()
        return render_template("history.html", history=[])
    finally:
        cursor.close()
        release_db_connection(conn)

@app.route("/health")
def health():
    """Enhanced health check endpoint"""
    try:
        # Check database connection
        conn = get_db_connection()
        try:
            cursor = conn.cursor()
            cursor.execute("SELECT 1")
            db_status = "healthy"
            db_connections = cursor.rowcount
        finally:
            cursor.close()
            release_db_connection(conn)
    except Error:
        db_status = "unhealthy"
        db_connections = 0
    
    # Check external API
    api_status = "healthy"
    try:
        response = requests.get(f"{BASE_URL}?key={API_KEY}&q=London", timeout=5)
        if response.status_code != 200:
            api_status = "unhealthy"
    except:
        api_status = "unhealthy"
    
    overall_status = "healthy" if db_status == "healthy" and api_status == "healthy" else "unhealthy"
    
    health_data = {
        "status": overall_status,
        "timestamp": datetime.utcnow().isoformat(),
        "checks": {
            "database": {
                "status": db_status,
                "connections": db_connections
            },
            "api": {
                "status": api_status
            }
        }
    }
    
    status_code = 200 if overall_status == "healthy" else 503
    return jsonify(health_data), status_code

@app.route("/metrics")
def metrics():
    """Prometheus metrics endpoint"""
    return generate_latest(registry), 200, {'Content-Type': CONTENT_TYPE_LATEST}

# Add Prometheus WSGI middleware
app_dispatch = DispatcherMiddleware(app, make_wsgi_app(registry))

if __name__ == "__main__":
    logger.info("Starting Weather App with Prometheus metrics")
    app.run(debug=False, host='0.0.0.0', port=5000)
