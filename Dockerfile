<<<<<<< HEAD
# Use an official Python base image
FROM python:3.10-slim
=======
# Use non-root base image
FROM python:3.10-slim-bullseye

# Create non-root user
RUN groupadd -r appuser && useradd -r -g appuser appuser
>>>>>>> master

# Set working directory
WORKDIR /app

<<<<<<< HEAD
# Copy requirements and install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy rest of the app code
COPY . .

# Set environment variable for Flask
ENV FLASK_APP=app.py
ENV FLASK_RUN_HOST=0.0.0.0
=======
# Install security updates and system dependencies
RUN apt-get update && \
    apt-get upgrade -y && \
    apt-get install -y --no-install-recommends \
        gcc \
        curl && \
    rm -rf /var/lib/apt/lists/*

# Copy requirements first for better caching
COPY requirements.txt .
RUN pip install --no-cache-dir --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY . .

# Change ownership to non-root user
RUN chown -R appuser:appuser /app

# Switch to non-root user
USER appuser

# Set environment variables
ENV FLASK_APP=app.py
ENV FLASK_RUN_HOST=0.0.0.0
ENV PYTHONPATH=/app
>>>>>>> master

# Expose port
EXPOSE 5000

<<<<<<< HEAD
# Run the Flask app with Gunicorn (production-ready WSGI server)
CMD ["gunicorn", "--bind", "0.0.0.0:5000", "--workers", "4", "--timeout", "120", "app:app"]
=======
# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:5000/health || exit 1

# Run with Gunicorn as non-root user
CMD ["gunicorn", "--bind", "0.0.0.0:5000", "--workers", "4", "--timeout", "120", "--user", "appuser", "app:app"]
>>>>>>> master
