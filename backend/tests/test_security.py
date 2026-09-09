import pytest
import uuid
import random
from fastapi.testclient import TestClient
from app.main import app
from app.core.config import settings
from app.core.limiter import limiter

client = TestClient(app)

def test_secure_headers():
    # Hit health endpoint
    response = client.get("/health")
    assert response.status_code == 200
    
    # Check headers
    assert response.headers.get("X-Content-Type-Options") == "nosniff"
    assert response.headers.get("X-Frame-Options") == "DENY"
    assert response.headers.get("X-XSS-Protection") == "1; mode=block"
    assert "Strict-Transport-Security" in response.headers

def test_rate_limiting_auth():
    limiter.enabled = True
    # Try logging in 6 times quickly (limit is 5/minute)
    phone = str(random.randint(1000000000, 9999999999))
    client.post(
        f"{settings.API_V1_STR}/auth/register",
        json={
            "phone": phone,
            "password": "password",
            "name": "Rate Limit Test",
            "role": "FARMER"
        }
    )
    
    # Send 5 requests
    for i in range(5):
        res = client.post(
            f"{settings.API_V1_STR}/auth/login",
            data={"username": phone, "password": "password"}
        )
        assert res.status_code == 200
        
    # The 6th request should fail with 429
    res = client.post(
        f"{settings.API_V1_STR}/auth/login",
        data={"username": phone, "password": "password"}
    )
    assert res.status_code == 429
    assert "5 per 1 minute" in res.text
    limiter.enabled = False
