import requests
import mysql.connector
from datetime import datetime

# Connect to MySQL
db = mysql.connector.connect(
    host="localhost",
    user="root",
    password="598684",  # your password
    database="weather_app"
)
cursor = db.cursor()

# Fetch weather from wttr.in (free API)
def fetch_weather(city):
    url = f"https://wttr.in/{city}?format=j1"
    try:
        response = requests.get(url)
        if response.status_code == 200:
            data = response.json()
            temp = data["current_condition"][0]["temp_C"]
            desc = data["current_condition"][0]["weatherDesc"][0]["value"]
            return temp, desc
        else:
            return None, None
    except:
        return None, None

# Save to MySQL
def save_to_db(city, temp, desc):
    sql = "INSERT INTO weather_history (city, temperature, description) VALUES (%s, %s, %s)"
    values = (city, temp, desc)
    cursor.execute(sql, values)
    db.commit()

# View history
def view_history():
    cursor.execute("SELECT * FROM weather_history ORDER BY id DESC")
    rows = cursor.fetchall()
    if rows:
        print("\n--- Weather Search History ---")
        for row in rows:
            print(f"{row[4]} | {row[1]}: {row[2]}°C, {row[3]}")
    else:
        print("No history found.")

# CLI App Loop
while True:
    print("\nWeather App")
    print("1. Get weather by city")
    print("2. View search history")
    print("3. Exit")

    choice = input("Choose an option: ")

    if choice == "1":
        city = input("Enter city name: ")
        temp, desc = fetch_weather(city)
        if temp:
            print(f"{city}: {temp}°C, {desc}")
            save_to_db(city, temp, desc)
        else:
            print("Could not fetch weather data.")
    elif choice == "2":
        view_history()
    elif choice == "3":
        print("Goodbye!")
        break
    else:
        print("Invalid option.")
