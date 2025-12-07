CREATE DATABASE IF NOT EXISTS weather_app;

USE weather_app;

CREATE TABLE IF NOT EXISTS weather_history (
    id INT AUTO_INCREMENT PRIMARY KEY,
    city VARCHAR(100),
    temperature VARCHAR(20),
    description VARCHAR(255),
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
