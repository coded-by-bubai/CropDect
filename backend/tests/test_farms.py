from fastapi.testclient import TestClient
from app.main import app
from app.core.config import settings
from fastapi import status
from sqlalchemy.orm import Session
from app.db.database import SessionLocal
import pytest

client = TestClient(app)

@pytest.fixture
def db() -> Session:
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

def get_auth_token():
    client.post(
        f"{settings.API_V1_STR}/auth/register",
        json={
            "phone": "5551234567",
            "password": "strongpassword123",
            "name": "Farm Owner",
            "role": "FARMER"
        }
    )
    response = client.post(
        f"{settings.API_V1_STR}/auth/login",
        data={
            "username": "5551234567",
            "password": "strongpassword123"
        }
    )
    return response.json().get("access_token")

def test_create_farm():
    token = get_auth_token()
    response = client.post(
        f"{settings.API_V1_STR}/farms/",
        headers={"Authorization": f"Bearer {token}"},
        json={
            "name": "My New Farm",
            "area": 10.5,
            "soil_type": "Loam",
            "latitude": 37.7749,
            "longitude": -122.4194
        }
    )
    assert response.status_code == 200
    data = response.json()
    assert data["name"] == "My New Farm"
    assert data["latitude"] == 37.7749
    assert data["longitude"] == -122.4194

def test_create_crop():
    token = get_auth_token()
    # Assume farm from previous test was created
    farms_response = client.get(
        f"{settings.API_V1_STR}/farms/",
        headers={"Authorization": f"Bearer {token}"}
    )
    farm_id = farms_response.json()[0]["id"]

    response = client.post(
        f"{settings.API_V1_STR}/crops/",
        headers={"Authorization": f"Bearer {token}"},
        json={
            "farm_id": farm_id,
            "crop_type": "Wheat",
            "variety": "Durum"
        }
    )
    assert response.status_code == 200
    data = response.json()
    assert data["crop_type"] == "Wheat"
    assert data["status"] == "ACTIVE"
