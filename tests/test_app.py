import pytest
from app import app

@pytest.fixture
def client():
    app.config['TESTING'] = True
    with app.test_client() as client:
        yield client

def test_health_check(client):
    """Test the health check endpoint"""
    response = client.get('/health')
    assert response.status_code in [200, 503] # Depending on if DB is up
    assert response.is_json

def test_home_page(client):
    """Test the home page loads"""
    response = client.get('/')
    assert response.status_code == 200
    assert b"Weather App" in response.data

def test_metrics_endpoint(client):
    """Test that metrics endpoint is exposed"""
    response = client.get('/metrics')
    assert response.status_code == 200
    assert b"weather_requests_total" in response.data
