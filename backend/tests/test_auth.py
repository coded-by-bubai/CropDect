from fastapi.testclient import TestClient
from app.main import app
from app.core.config import settings
from app.db.base import Base
from app.db.database import engine, SessionLocal
from sqlalchemy.orm import Session
import pytest
import random

client = TestClient(app)

@pytest.fixture(scope="session", autouse=True)
def setup_db():
    Base.metadata.create_all(bind=engine)
    yield

@pytest.fixture
def db() -> Session:
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

def get_random_phone():
    return str(random.randint(1000000000, 9999999999))

def test_register_user():
    phone = get_random_phone()
    response = client.post(
        f"{settings.API_V1_STR}/auth/register",
        json={
            "phone": phone,
            "password": "strongpassword123",
            "name": "Test Farmer",
            "role": "FARMER"
        }
    )
    assert response.status_code == 200
    data = response.json()
    assert data["phone"] == phone
    assert data["name"] == "Test Farmer"
    assert data["role"] == "FARMER"
    assert "id" in data

def test_login_user():
    phone = get_random_phone()
    # Register first
    client.post(
        f"{settings.API_V1_STR}/auth/register",
        json={
            "phone": phone,
            "password": "strongpassword123",
            "name": "Test Farmer",
            "role": "FARMER"
        }
    )
    # Login requires form data
    response = client.post(
        f"{settings.API_V1_STR}/auth/login",
        data={
            "username": phone,
            "password": "strongpassword123"
        }
    )
    assert response.status_code == 200
    data = response.json()
    assert "access_token" in data
    assert data["token_type"] == "bearer"

def test_read_users_me():
    phone = get_random_phone()
    # Register first
    client.post(
        f"{settings.API_V1_STR}/auth/register",
        json={
            "phone": phone,
            "password": "strongpassword123",
            "name": "Test Farmer Me",
            "role": "FARMER"
        }
    )
    # Login to get token
    login_response = client.post(
        f"{settings.API_V1_STR}/auth/login",
        data={
            "username": phone,
            "password": "strongpassword123"
        }
    )
    token = login_response.json()["access_token"]

    # Use token to access /me
    response = client.get(
        f"{settings.API_V1_STR}/users/me",
        headers={"Authorization": f"Bearer {token}"}
    )
    assert response.status_code == 200
    data = response.json()
    assert data["phone"] == phone
    assert data["name"] == "Test Farmer Me"
