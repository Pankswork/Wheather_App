# README.md

## Part 1 – Project Overview (for Developers)

This project is a Weather App built with Flask + MySQL, containerized using Docker and orchestrated with Docker Compose.

### Tech Stack

Flask (Python) → Backend for weather queries and history storage.

MySQL 8.0 → Database for storing city weather history.

Docker + Docker Compose → Containerized application and DB.

GitHub Actions → CI/CD pipeline to build & push Docker images to Docker Hub.

### Workflow

Local Development

Write Flask app with .env for API keys & DB credentials.

Use docker-compose.yml to run Flask + MySQL locally.

Database schema auto-creates via init.sql.

### CI/CD

GitHub Actions build pipeline runs on every push to main.

Image is built and pushed to Docker Hub.

Secrets like DOCKERHUB_USERNAME and DOCKERHUB_TOKEN are stored in GitHub Secrets.

.env is not uploaded — each user provides their own.

## Part 2 – User Guide (How to Run)

### Weather API key from https://www.weatherapi.com/
WEATHER_API_KEY=your_api_key_here

1. Clone the repository

```bash
git clone https://github.com/<your-username>/<your-repo>.git
cd <your-repo>
```

3. Create a .env file

Copy the example below into a .env file in the root directory:

### API key
WEATHER_API_KEY=your_api_key_here

### Database settings
DB_HOST=db
DB_USER=app_user
DB_PASSWORD=your_password_here
DB_NAME=weather_app


Make sure you replace your_api_key_here with your OpenWeather API key.

3. Build and start the containers

```bash
docker-compose up --build
```


The app will be available at http://localhost:5000

### Managing Containers

Stop and Remove Containers

### Stop a container and Remove a container
```bash
docker stop <container_name_or_id>

docker rm <container_name_or_id>
```

```bash

# Force Remove
docker rm -f mysql-db

# Remove the database volume ( deletes all data)
docker volume rm pythonapp_db_data

### Rebuild and start again
docker-compose up --build
```

### Project Structure
.
├── app.py               # Flask application
├── requirements.txt     # Python dependencies
├── Dockerfile           # Docker image for Flask app
├── docker-compose.yml   # Compose configuration
├── init.sql             # MySQL initialization script
└── .env                 # Environment variables (not committed)

Visit http://localhost:5000/history



