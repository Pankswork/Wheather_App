import logging
import os
import time
from datetime import datetime

import boto3
from botocore.exceptions import ClientError
from dotenv import load_dotenv
from flask import Flask, request, render_template, jsonify
import mysql.connector
from mysql.connector import Error
from prometheus_client import (
    Counter, Histogram, Gauge, generate_latest,
    CollectorRegistry, CONTENT_TYPE_LATEST, make_wsgi_app
)
import requests
from werkzeug.middleware.dispatcher import DispatcherMiddleware

app = Flask(__name__)

# Configure structured logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# Prometheus Metrics
registry = CollectorRegistry()

REQUEST_COUNT = Counter(
    'weather_requests_total', 'Total weather requests',
    ['method', 'endpoint', 'status'], registry=registry
)
REQUEST_DURATION = Histogram(
    'weather_request_duration_seconds', 'Request duration', registry=registry
)
ACTIVE_CONNECTIONS = Gauge(
    'weather_active_connections', 'Active database connections', registry=registry
)
API_RESPONSE_TIME = Histogram(
    'weather_api_response_time_seconds', 'Weather API response time', registry=registry
)
WEATHER_QUERIES = Counter(
    'weather_queries_total', 'Total weather queries',
    ['city', 'status'], registry=registry
)
DATABASE_QUERIES = Counter(
    'database_queries_total', 'Total database queries',
    ['operation'], registry=registry
)

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
        logger.error("Database connection error: %s", err)
        DATABASE_QUERIES.labels(operation='connect_error').inc()
        raise

def release_db_connection(conn):
    try:
        if conn.is_connected():
            conn.close()
            ACTIVE_CONNECTIONS.dec()
            DATABASE_QUERIES.labels(operation='disconnect').inc()
    except Error as err:
        logger.error("Error closing database connection: %s", err)
        DATABASE_QUERIES.labels(operation='disconnect_error').inc()

def init_db():
    """Initialize database schema."""
    conn = None
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS weather_history (
                id INT AUTO_INCREMENT PRIMARY KEY,
                city VARCHAR(255) NOT NULL,
                temperature VARCHAR(50),
                description VARCHAR(255),
                timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        """)
        conn.commit()
        cursor.close()
        logger.info("Database schema initialized.")
    except Error as err:
        logger.error("Failed to initialize database: %s", err)
    finally:
        if conn:
            release_db_connection(conn)

# Initialize DB immediately (Force Rebuild)
init_db()

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
    except Exception as err:
        logger.error("Failed to put custom metric %s: %s", metric_name, err)

def save_weather_data(city, temperature, description):
    """Save weather query to database."""
    conn = get_db_connection()
    try:
        cursor = conn.cursor()
        cursor.execute(
            "INSERT INTO weather_history (city, temperature, description) VALUES (%s, %s, %s)",
            (city, temperature, description)
        )
        conn.commit()
        DATABASE_QUERIES.labels(operation='insert').inc()
        cursor.close()
    except Error as err:
        logger.error("Database error during insert: %s", err)
        conn.rollback()
        DATABASE_QUERIES.labels(operation='insert_error').inc()
        raise
    finally:
        release_db_connection(conn)

def fetch_weather_from_api(city):
    """Fetch weather data from external API."""
    start_time = time.time()
    params = {"key": API_KEY, "q": city}
    try:
        response = requests.get(BASE_URL, params=params, timeout=10)
        api_duration = time.time() - start_time
        API_RESPONSE_TIME.observe(api_duration)
        return response
    except requests.RequestException as err:
        logger.error("Weather API error: %s", err)
        raise

def determine_background(description, temp_c):
    """Determine background image based on weather condition."""
    desc_lower = description.lower()
    if "rain" in desc_lower:
        return "rain.jpg"
    if "cloud" in desc_lower:
        return "cloudy.jpg"
    if "sun" in desc_lower or temp_c >= 30:
        return "sunny.jpg"
    if temp_c < 15:
        return "cold.jpg"
    return "default.jpg"

@app.before_request
def before_request():
    request.start_time = time.time() # pylint: disable=attribute-defined-outside-init

@app.after_request
def after_request(response):
    if hasattr(request, 'start_time'):
        duration = time.time() - request.start_time
        REQUEST_DURATION.observe(duration)
        REQUEST_COUNT.labels(
            method=request.method,
            endpoint=request.endpoint or 'unknown',
            status=response.status_code
        ).inc()

        # Log slow requests
        if duration > 2.0:
            logger.warning("Slow request: %s %s took %.2fs",
                           request.method, request.endpoint, duration)

    return response

@app.route("/", methods=["GET", "POST"])
def index():
    weather_data = None
    background = "default.jpg"
    history_data = []

    if request.method == "POST":
        city = request.form.get("city", "").strip()

        # Input validation
        if not city or len(city) > 50:
            weather_data = {"error": "Invalid city name"}
            WEATHER_QUERIES.labels(city=city, status='validation_error').inc()
        else:
            # Sanitize input
            city = ''.join(c for c in city if c.isalnum() or c.isspace() or c in '-.,')
            try:
                response = fetch_weather_from_api(city)

                if response.status_code == 200:
                    data = response.json()
                    temp_c = data["current"]["temp_c"]
                    temperature = str(temp_c) + " \u00b0C"
                    description = data["current"]["condition"]["text"]

                    background = determine_background(description, temp_c)

                    try:
                        save_weather_data(city, temperature, description)
                        # Custom metrics
                        put_custom_metric('SuccessfulWeatherQueries', 1, 'Count')
                        WEATHER_QUERIES.labels(city=city, status='success').inc()
                        logger.info("Weather query successful for city: %s", city)
                    except Error:
                        # Error already logged in save_weather_data
                        pass

                    weather_data = {
                        "city": city,
                        "temperature": temperature,
                        "description": description
                    }
                else:
                    weather_data = {"error": "City not found or API error"}
                    put_custom_metric('FailedWeatherQueries', 1, 'Count')
                    WEATHER_QUERIES.labels(city=city, status='api_error').inc()
                    logger.warning("Weather API failed for city: %s, status: %d",
                                   city, response.status_code)

            except requests.RequestException:
                weather_data = {"error": "Service temporarily unavailable"}
                put_custom_metric('APIErrorCount', 1, 'Count')
                WEATHER_QUERIES.labels(city=city, status='request_error').inc()
            except Exception as err: # pylint: disable=broad-except
                logger.error("Unexpected error: %s", err)
                weather_data = {"error": "Internal server error"}
                put_custom_metric('UnexpectedErrorCount', 1, 'Count')
                WEATHER_QUERIES.labels(city=city, status='unexpected_error').inc()

    # Get history
    conn = get_db_connection()
    try:
        cursor = conn.cursor()
        cursor.execute(
            "SELECT city, temperature, description, timestamp "
            "FROM weather_history ORDER BY timestamp DESC LIMIT 10"
        )
        history_data = cursor.fetchall()
        DATABASE_QUERIES.labels(operation='select').inc()
    except Error as err:
        logger.error("Database error fetching history: %s", err)
        DATABASE_QUERIES.labels(operation='select_error').inc()
    finally:
        release_db_connection(conn)

    return render_template("index.html", weather=weather_data,
                           history=history_data, background=background)


@app.route("/history")
def history():
    conn = get_db_connection()
    try:
        cursor = conn.cursor()
        cursor.execute(
            "SELECT city, temperature, description, timestamp "
            "FROM weather_history ORDER BY timestamp DESC"
        )
        rows = cursor.fetchall()
        DATABASE_QUERIES.labels(operation='select_history').inc()
        return render_template("history.html", history=rows)
    except Error as err:
        logger.error("Database error: %s", err)
        DATABASE_QUERIES.labels(operation='select_history_error').inc()
        return render_template("history.html", history=[])
    finally:
        release_db_connection(conn)

@app.route("/health")
def health():
    """Enhanced health check endpoint"""
    db_status = "unhealthy"
    db_connections = 0
    try:
        conn = get_db_connection()
        try:
            cursor = conn.cursor()
            cursor.execute("SELECT 1")
            db_status = "healthy"
            db_connections = cursor.rowcount
            cursor.close()
        finally:
            release_db_connection(conn)
    except Error:
        pass

    # Check external API
    api_status = "unhealthy"
    try:
        response = requests.get(f"{BASE_URL}?key={API_KEY}&q=London", timeout=5)
        if response.status_code == 200:
            api_status = "healthy"
    except requests.RequestException:
        pass

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
