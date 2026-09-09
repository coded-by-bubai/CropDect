import pytest
from fastapi.testclient import TestClient
from app.main import app
from app.core.config import settings
import httpx
import random

client = TestClient(app)

def get_auth_token():
    phone = str(random.randint(1000000000, 9999999999))
    client.post(
        f"{settings.API_V1_STR}/auth/register",
        json={
            "phone": phone,
            "password": "password",
            "name": "Weather Test",
            "role": "FARMER"
        }
    )
    response = client.post(
        f"{settings.API_V1_STR}/auth/login",
        data={
            "username": phone,
            "password": "password"
        }
    )
    return response.json()["access_token"]

class MockResponse:
    def __init__(self, json_data, status_code):
        self.json_data = json_data
        self.status_code = status_code

    def json(self):
        return self.json_data
        
    def raise_for_status(self):
        if self.status_code >= 400:
            raise Exception("HTTP Error")

def test_get_farm_weather(monkeypatch):
    token = get_auth_token()
    
    # Create farm
    farm_res = client.post(
        f"{settings.API_V1_STR}/farms/",
        headers={"Authorization": f"Bearer {token}"},
        json={"name": "Weather Farm", "area": 10.0, "latitude": 34.05, "longitude": -118.24}
    )
    farm_id = farm_res.json()["id"]
    
    class MockClient:
        def __enter__(self): return self
        def __exit__(self, *args): pass
        def get(self, url, timeout=None):
            return MockResponse({
                "current": {
                    "temperature_2m": 35.0,
                    "relative_humidity_2m": 15,
                    "precipitation": 0.0
                },
                "daily": {
                    "time": ["2026-09-02", "2026-09-03", "2026-09-04"],
                    "temperature_2m_max": [36.0, 37.0, 35.0],
                    "temperature_2m_min": [20.0, 21.0, 19.0],
                    "precipitation_sum": [0.0, 0.0, 0.0]
                }
            }, 200)

    monkeypatch.setattr("app.services.weather_service.httpx.Client", MockClient)

    weather_res = client.get(
        f"{settings.API_V1_STR}/farms/{farm_id}/weather",
        headers={"Authorization": f"Bearer {token}"}
    )
    
    assert weather_res.status_code == 200
    data = weather_res.json()
    assert data["farm_id"] == farm_id
    assert data["current_temp_c"] == 35.0
    assert data["risk_level"] == "HIGH_PEST_RISK"
