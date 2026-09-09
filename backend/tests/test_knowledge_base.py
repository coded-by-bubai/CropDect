from fastapi.testclient import TestClient
from app.main import app
from app.core.config import settings
from sqlalchemy.orm import Session
from app.db.database import SessionLocal
import pytest
import random

client = TestClient(app)

@pytest.fixture
def db() -> Session:
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

def get_auth_token(role: str = "FARMER"):
    phone = str(random.randint(1000000000, 9999999999))
    client.post(
        f"{settings.API_V1_STR}/auth/register",
        json={
            "phone": phone,
            "password": "password",
            "name": f"Test {role}",
            "role": role
        }
    )
    response = client.post(
        f"{settings.API_V1_STR}/auth/login",
        data={
            "username": phone,
            "password": "password"
        }
    )
    return response.json().get("access_token")

def test_kb_expert_access():
    token = get_auth_token("EXPERT")
    response = client.post(
        f"{settings.API_V1_STR}/knowledge-base/",
        headers={"Authorization": f"Bearer {token}"},
        json={
            "name": "Wheat Rust",
            "scientific_name": "Puccinia triticina",
            "category": "DISEASE",
            "affected_crops": "Wheat, Barley",
            "symptoms": "Brown pustules on leaves",
            "treatment_recommendations": "Apply fungicide"
        }
    )
    assert response.status_code == 200
    data = response.json()
    assert data["name"] == "Wheat Rust"

def test_kb_farmer_denied():
    token = get_auth_token("FARMER")
    response = client.post(
        f"{settings.API_V1_STR}/knowledge-base/",
        headers={"Authorization": f"Bearer {token}"},
        json={
            "name": "Wheat Rust 2",
            "category": "DISEASE",
            "symptoms": "Brown pustules on leaves"
        }
    )
    assert response.status_code == 403

def test_kb_farmer_can_read():
    token = get_auth_token("FARMER")
    response = client.get(
        f"{settings.API_V1_STR}/knowledge-base/",
        headers={"Authorization": f"Bearer {token}"}
    )
    assert response.status_code == 200
    assert isinstance(response.json(), list)
