import pytest
import uuid
import random
from fastapi.testclient import TestClient
from app.main import app
from app.core.config import settings

client = TestClient(app)

def get_auth_token(role: str = "FARMER"):
    phone = str(random.randint(1000000000, 9999999999))
    client.post(
        f"{settings.API_V1_STR}/auth/register",
        json={
            "phone": phone,
            "password": "password",
            "name": f"Chat Test {role}",
            "role": role
        }
    )
    res = client.post(
        f"{settings.API_V1_STR}/auth/login",
        data={"username": phone, "password": "password"}
    )
    return res.json()["access_token"]

def test_chat_rag():
    farmer_token = get_auth_token("FARMER")
    expert_token = get_auth_token("EXPERT")
    
    # 1. Setup KB entry with unique keyword
    unique_disease_name = f"Mildew_{uuid.uuid4().hex[:6]}"
    unique_keyword = f"magicpotion_{uuid.uuid4().hex[:6]}"
    
    client.post(
        f"{settings.API_V1_STR}/knowledge-base/",
        headers={"Authorization": f"Bearer {expert_token}"},
        json={
            "name": unique_disease_name,
            "category": "DISEASE",
            "symptoms": f"White powder and {unique_keyword}",
            "treatment_recommendations": "Use sulfur spray"
        }
    )
    
    # 2. Ask question
    res = client.post(
        f"{settings.API_V1_STR}/chat/ask",
        headers={"Authorization": f"Bearer {farmer_token}"},
        json={
            "query": f"How do I treat {unique_keyword} on my leaves?"
        }
    )
    
    assert res.status_code == 200
    data = res.json()
    assert unique_disease_name in data["context_used"]
    assert "sulfur spray" in data["answer"].lower()
