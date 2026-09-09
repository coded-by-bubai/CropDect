import pytest
import io
from fastapi.testclient import TestClient
from app.main import app
from app.core.config import settings
import random
import time
import uuid

client = TestClient(app)

def get_auth_token(role: str = "FARMER"):
    phone = str(random.randint(1000000000, 9999999999))
    client.post(
        f"{settings.API_V1_STR}/auth/register",
        json={
            "phone": phone,
            "password": "password",
            "name": f"Hotspot Test {role}",
            "role": role
        }
    )
    res = client.post(
        f"{settings.API_V1_STR}/auth/login",
        data={"username": phone, "password": "password"}
    )
    return res.json()["access_token"]

def test_hotspot_generation(monkeypatch):
    token = get_auth_token()
    
    # 1. Create Farm A (Los Angeles)
    res = client.post(
        f"{settings.API_V1_STR}/farms/",
        headers={"Authorization": f"Bearer {token}"},
        json={"name": "Farm LA", "area": 5.0, "latitude": 34.05, "longitude": -118.24}
    )
    farm_a_id = res.json()["id"]
    
    res = client.post(
        f"{settings.API_V1_STR}/crops/",
        headers={"Authorization": f"Bearer {token}"},
        json={"farm_id": farm_a_id, "crop_type": "Tomato"}
    )
    crop_a_id = res.json()["id"]

    # 2. Create Farm B (San Francisco)
    res = client.post(
        f"{settings.API_V1_STR}/farms/",
        headers={"Authorization": f"Bearer {token}"},
        json={"name": "Farm SF", "area": 5.0, "latitude": 37.77, "longitude": -122.41}
    )
    farm_b_id = res.json()["id"]
    
    res = client.post(
        f"{settings.API_V1_STR}/crops/",
        headers={"Authorization": f"Bearer {token}"},
        json={"farm_id": farm_b_id, "crop_type": "Tomato"}
    )
    crop_b_id = res.json()["id"]

    # 3. Create a UNIQUE disease in KB to avoid cross-test contamination
    expert_token = get_auth_token("EXPERT")
    unique_disease_name = f"HotspotDisease {uuid.uuid4().hex[:6]}"
    client.post(
        f"{settings.API_V1_STR}/knowledge-base/",
        headers={"Authorization": f"Bearer {expert_token}"},
        json={
            "name": unique_disease_name,
            "category": "DISEASE",
            "affected_crops": "Tomato",
            "symptoms": "Test",
            "trigger_conditions": "Test",
            "treatment_recommendations": "Test"
        }
    )

    # 4. Mock inference to return our unique disease
    import app.ml.inference
    monkeypatch.setattr(app.ml.inference, "predict_image", lambda x: {"class_name": f"Tomato___{unique_disease_name.replace(' ', '_')}", "confidence": 0.95, "is_healthy": False})

    # Upload image for Crop A
    dummy = io.BytesIO(b"dummy")
    client.post(
        f"{settings.API_V1_STR}/diagnostics/upload",
        headers={"Authorization": f"Bearer {token}"},
        data={"crop_id": crop_a_id},
        files={"file": ("dummy.jpg", dummy, "image/jpeg")}
    )

    # Upload image for Crop B
    dummy2 = io.BytesIO(b"dummy2")
    client.post(
        f"{settings.API_V1_STR}/diagnostics/upload",
        headers={"Authorization": f"Bearer {token}"},
        data={"crop_id": crop_b_id},
        files={"file": ("dummy.jpg", dummy2, "image/jpeg")}
    )

    # Query hotspots globally for our unique disease
    res = client.get(
        f"{settings.API_V1_STR}/diagnostics/hotspots?disease_name={unique_disease_name}",
        headers={"Authorization": f"Bearer {token}"}
    )
    assert res.status_code == 200
    data = res.json()
    assert data["disease_name"] == unique_disease_name
    assert len(data["hotspots"]) == 2 # LA and SF

    # Query hotspots near LA (50km radius)
    res = client.get(
        f"{settings.API_V1_STR}/diagnostics/hotspots?disease_name={unique_disease_name}&radius_km=50&lat=34.0&lng=-118.2",
        headers={"Authorization": f"Bearer {token}"}
    )
    assert res.status_code == 200
    data = res.json()
    assert len(data["hotspots"]) == 1 # Only LA
    assert abs(data["hotspots"][0]["latitude"] - 34.05) < 0.01
