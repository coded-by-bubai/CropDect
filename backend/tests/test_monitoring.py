import pytest
import io
import uuid
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
            "name": f"Monitor Test {role}",
            "role": role
        }
    )
    res = client.post(
        f"{settings.API_V1_STR}/auth/login",
        data={"username": phone, "password": "password"}
    )
    return res.json()["access_token"]

def test_monitoring_workflow(monkeypatch):
    farmer_token = get_auth_token("FARMER")
    other_farmer_token = get_auth_token("FARMER")
    
    # 1. Setup Farm and Crop
    farm_res = client.post(
        f"{settings.API_V1_STR}/farms/",
        headers={"Authorization": f"Bearer {farmer_token}"},
        json={"name": "Monitor Farm", "area": 5.0, "latitude": 34.0, "longitude": -118.0}
    )
    farm_id = farm_res.json()["id"]
    
    crop_res = client.post(
        f"{settings.API_V1_STR}/crops/",
        headers={"Authorization": f"Bearer {farmer_token}"},
        json={"farm_id": farm_id, "crop_type": "Tomato"}
    )
    crop_id = crop_res.json()["id"]

    # 2. Add disease to KB
    expert_token = get_auth_token("EXPERT")
    unique_disease_name = f"MonitorDisease {uuid.uuid4().hex[:6]}"
    client.post(
        f"{settings.API_V1_STR}/knowledge-base/",
        headers={"Authorization": f"Bearer {expert_token}"},
        json={
            "name": unique_disease_name,
            "category": "DISEASE",
            "symptoms": "Test"
        }
    )

    # 3. Mock inference to return high confidence
    import app.ml.inference
    monkeypatch.setattr(app.ml.inference, "predict_image", lambda x: {"class_name": f"Tomato___{unique_disease_name.replace(' ', '_')}", "confidence": 0.95, "is_healthy": False})

    # 4. Upload image as Farmer -> creates AI_PREDICTED diagnosis
    dummy = io.BytesIO(b"dummy")
    diag_res = client.post(
        f"{settings.API_V1_STR}/diagnostics/upload",
        headers={"Authorization": f"Bearer {farmer_token}"},
        data={"crop_id": crop_id},
        files={"file": ("dummy.jpg", dummy, "image/jpeg")}
    )
    diagnosis_id = diag_res.json()["id"]

    # 5. Other farmer tries to add log (should fail)
    other_log = client.post(
        f"{settings.API_V1_STR}/monitoring/{diagnosis_id}/logs",
        headers={"Authorization": f"Bearer {other_farmer_token}"},
        data={"health_status": "IMPROVING", "notes": "Hacked log"}
    )
    assert other_log.status_code == 404

    # 6. Correct farmer adds IMPROVING log with photo
    dummy_followup = io.BytesIO(b"dummy2")
    log_res = client.post(
        f"{settings.API_V1_STR}/monitoring/{diagnosis_id}/logs",
        headers={"Authorization": f"Bearer {farmer_token}"},
        data={"health_status": "IMPROVING", "notes": "Leaves look better"},
        files={"file": ("followup.jpg", dummy_followup, "image/jpeg")}
    )
    assert log_res.status_code == 200
    assert log_res.json()["health_status"] == "IMPROVING"
    
    # 7. Add RESOLVED log
    res_log = client.post(
        f"{settings.API_V1_STR}/monitoring/{diagnosis_id}/logs",
        headers={"Authorization": f"Bearer {farmer_token}"},
        data={"health_status": "RESOLVED", "notes": "Plant is fully healed!"}
    )
    assert res_log.status_code == 200

    # 8. Check diagnosis status is RESOLVED
    diag_check = client.get(
        f"{settings.API_V1_STR}/diagnostics/?crop_id={crop_id}",
        headers={"Authorization": f"Bearer {farmer_token}"}
    )
    diags = diag_check.json()
    diag = next(d for d in diags if d["id"] == diagnosis_id)
    assert diag["status"] == "RESOLVED"
