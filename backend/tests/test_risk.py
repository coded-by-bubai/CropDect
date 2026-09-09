import pytest
from fastapi.testclient import TestClient
from app.main import app
from app.core.config import settings
import random

client = TestClient(app)

def get_auth_token(role: str = "FARMER"):
    phone = str(random.randint(1000000000, 9999999999))
    client.post(
        f"{settings.API_V1_STR}/auth/register",
        json={
            "phone": phone,
            "password": "password",
            "name": f"Risk Test {role}",
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
    return response.json()["access_token"]

def test_risk_assessment(monkeypatch):
    token = get_auth_token()
    
    # 1. Create a Farm
    farm_res = client.post(
        f"{settings.API_V1_STR}/farms/",
        headers={"Authorization": f"Bearer {token}"},
        json={"name": "Risk Farm", "area": 5.0, "latitude": 37.77, "longitude": -122.41}
    )
    farm_id = farm_res.json()["id"]

    # 2. Create a Crop (Tomato)
    import uuid
    unique_crop = f"Tomato_{uuid.uuid4().hex[:6]}"
    client.post(
        f"{settings.API_V1_STR}/crops/",
        headers={"Authorization": f"Bearer {token}"},
        json={"farm_id": farm_id, "crop_type": unique_crop}
    )
    
    # 3. Create a Knowledge Base entry for a Tomato disease triggered by humidity
    import uuid
    unique_disease_name = f"Late Blight {uuid.uuid4().hex[:6]}"
    expert_token = get_auth_token("EXPERT")
    client.post(
        f"{settings.API_V1_STR}/knowledge-base/",
        headers={"Authorization": f"Bearer {expert_token}"},
        json={
            "name": unique_disease_name,
            "category": "DISEASE",
            "affected_crops": f"{unique_crop}, Potato",
            "symptoms": "Brown spots",
            "trigger_conditions": "High humidity and rain",
            "treatment_recommendations": "Fungicide"
        }
    )
    
    # 4. Mock Weather Service to return high humidity
    import app.services.risk_service
    from app.schemas.weather import WeatherResponse
    
    def mock_fetch_weather(*args, **kwargs):
        return WeatherResponse(
            farm_id=farm_id,
            current_temp_c=25.0,
            current_humidity_percent=85.0, # High humidity!
            current_precipitation_mm=10.0,
            forecast=[],
            risk_level="HIGH_FUNGAL_RISK"
        )
        
    monkeypatch.setattr(app.services.risk_service, "fetch_weather_for_farm", mock_fetch_weather)
    
    # 5. Fetch Risk Assessment
    res = client.get(
        f"{settings.API_V1_STR}/farms/{farm_id}/risk-assessment",
        headers={"Authorization": f"Bearer {token}"}
    )
    
    assert res.status_code == 200
    data = res.json()
    assert data["farm_id"] == farm_id
    # Since risk is 80 (10 baseline + 70 weather), overall score is 20
    assert data["overall_health_score"] == 20 
    assert len(data["threats"]) == 1
    threat = data["threats"][0]
    assert threat["disease_name"] == unique_disease_name
    assert threat["risk_percentage"] == 80
    assert "High humidity/rain matches severe trigger conditions" in threat["reason"]
