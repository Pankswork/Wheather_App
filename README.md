📘 README.md
🚀 Part 1 – Project Overview (for Developers)

This project is a Weather App built with Flask + MySQL, containerized using Docker and orchestrated with Docker Compose.

🔧 Tech Stack

Flask (Python) → Backend for weather queries and history storage.

MySQL 8.0 → Database for storing city weather history.

Docker + Docker Compose → Containerized application and DB.

GitHub Actions → CI/CD pipeline to build & push Docker images to Docker Hub.

⚙️ Workflow

Local Development

Write Flask app with .env for API keys & DB credentials.

Use docker-compose.yml to run Flask + MySQL locally.

Database schema auto-creates via init.sql.

CI/CD

GitHub Actions build pipeline runs on every push to main.

Image is built and pushed to Docker Hub.

Secrets like DOCKERHUB_USERNAME and DOCKERHUB_TOKEN are stored in GitHub Secrets.

.env is not uploaded — each user provides their own.

🖥️ Part 2 – User Guide (How to Run)
1️⃣ Clone Repo
git clone https://github.com/<your-username>/weather-app.git
cd weather-app

2️⃣ Create .env

Create a .env file in the root directory:

# Weather API key from https://www.weatherapi.com/
WEATHER_API_KEY=your_api_key_here

# MySQL credentials
DB_HOST=db
DB_USER=root
DB_PASSWORD=examplepassword
DB_NAME=weather_app

3️⃣ Run with Docker Compose
docker-compose up --build


This will:

Start MySQL on port 3306

Start Flask app on port 5000

4️⃣ Open App

Go to:
👉 http://localhost:5000

Enter a city name and get live weather updates.

5️⃣ Example
POST / with city = "London"


Response in app:

City: London
Temperature: 19 °C
Description: Cloudy

6️⃣ Check History

Visit 👉 http://localhost:5000/history