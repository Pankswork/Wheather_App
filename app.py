from dotenv import load_dotenv
from flask import Flask, request, render_template
import requests
import os
import time
import mysql.connector
from datetime import datetime
from mysql.connector import Error

app = Flask(__name__)

# Weather API Setup
load_dotenv()

API_KEY = os.getenv("WEATHER_API_KEY")
BASE_URL = "http://api.weatherapi.com/v1/current.json"

# Validate API key is set
if not API_KEY:
    print("WARNING: WEATHER_API_KEY environment variable is not set!")

# MySQL connection using .env variables
for attempt in range(10):
    try:
        conn = mysql.connector.connect(
            host=os.getenv("DB_HOST"),
            user=os.getenv("DB_USER"),
            password=os.getenv("DB_PASSWORD"),
            database=os.getenv("DB_NAME")
        )
        cursor = conn.cursor()
        print(" Connected to MySQL successfully.")
        break
    except Error as err:
        print(f"Attempt {attempt + 1}: Database connection error: {err}")
        time.sleep(2)
else:
    print("Could not connect to MySQL after multiple attempts.")
    exit(1)

@app.route("/", methods=["GET", "POST"])
def index():
    weather_data = None
    background = "default.jpg"  # fallback wallpaper

    if request.method == "POST":
        city = request.form["city"]
        params = {"key": API_KEY, "q": city}
        response = requests.get(BASE_URL, params=params)

        if response.status_code == 200:
            data = response.json()
            temperature = str(data["current"]["temp_c"]) + " °C"
            description = data["current"]["condition"]["text"]
            temp_c = data["current"]["temp_c"]

            # Save to DB
            cursor.execute(
                "INSERT INTO weather_history (city, temperature, description) VALUES (%s, %s, %s)",
                (city, temperature, description)
            )
            conn.commit()

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
        else:
            weather_data = {"error": "City not found or API error."}

    # Get history
    cursor.execute("SELECT city, temperature, description, timestamp FROM weather_history ORDER BY timestamp DESC LIMIT 10")
    history = cursor.fetchall()

    return render_template("index.html", weather=weather_data, history=history, background=background)


@app.route("/history")
def history():
    cursor.execute("SELECT city, temperature, description, timestamp FROM weather_history ORDER BY timestamp DESC")
    rows = cursor.fetchall()
    return render_template("history.html", history=rows)

@app.route("/health")
def health():
    """Health check endpoint for ALB and Kubernetes probes"""
    try:
        # Check database connection
        cursor.execute("SELECT 1")
        db_status = "healthy"
    except Error:
        db_status = "unhealthy"
    
    if db_status == "healthy":
        return {"status": "healthy", "database": "connected"}, 200
    else:
        return {"status": "unhealthy", "database": "disconnected"}, 503

if __name__ == "__main__":
    app.run(debug=True)
