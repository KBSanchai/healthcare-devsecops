import pytest
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
os.environ["API_TOKEN"] = "test-token-12345"

from main import app

@pytest.fixture
def client():
    app.config["TESTING"] = True
    with app.test_client() as client:
        yield client

def test_health_check(client):
    response = client.get("/health")
    assert response.status_code == 200
    assert response.get_json()["status"] == "healthy"

def test_create_patient_unauthorized(client):
    response = client.post("/api/patients",
                           json={"name": "John", "dob": "1990-01-01"})
    assert response.status_code == 401

def test_create_patient_authorized(client):
    response = client.post("/api/patients",
                           json={"name": "Jane Doe", "dob": "1985-06-15"},
                           headers={"X-API-Token": "test-token-12345"})
    assert response.status_code == 201
    assert "patient_id" in response.get_json()

def test_get_nonexistent_patient(client):
    response = client.get("/api/patients/nonexistent",
                          headers={"X-API-Token": "test-token-12345"})
    assert response.status_code == 404

def test_no_sql_injection(client):
    response = client.get("/api/patients/' OR 1=1--",
                          headers={"X-API-Token": "test-token-12345"})
    assert response.status_code == 404
