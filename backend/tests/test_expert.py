import pytest
import io
from fastapi.testclient import TestClient
from app.main import app
from app.core.config import settings
import random
import uuid

client = TestClient(app)

def get_auth_token(role: str = "FARMER"):
    phone = str(random.randint(1000000000, 9999999999))
    client.post(
        f"{settings.API_V1_STR}/auth/register",
        json={
            "phone": phone,
            "password": "password",
            "name": f"Expert Test {role}",
            "role": role
        }
    )
    res = client.post(
        f"{settings.API_V1_STR}/auth/login",
        data={"username": phone, "password": "password"}
    )
    return res.json()["access_token"]

def test_expert_validation_workflow(monkeypatch):
    farmer_token = get_auth_token("FARMER")
    expert_token = get_auth_token("EXPERT")
    
    # 1. Setup Farm and Crop
    farm_res = client.post(
        f"{settings.API_V1_STR}/farms/",
        headers={"Authorization": f"Bearer {farmer_token}"},
        json={"name": "Expert Farm", "area": 5.0, "latitude": 34.0, "longitude": -118.0}
    )
    farm_id = farm_res.json()["id"]
    
    crop_res = client.post(
        f"{settings.API_V1_STR}/crops/",
        headers={"Authorization": f"Bearer {farmer_token}"},
        json={"farm_id": farm_id, "crop_type": "Tomato"}
    )
    crop_id = crop_res.json()["id"]

    # 2. Add disease to KB
    unique_disease_name = f"LowConfDisease {uuid.uuid4().hex[:6]}"
    kb_res = client.post(
        f"{settings.API_V1_STR}/knowledge-base/",
        headers={"Authorization": f"Bearer {expert_token}"},
        json={
            "name": unique_disease_name,
            "category": "DISEASE",
            "symptoms": "Low confidence test symptoms"
        }
    )
    disease_id = kb_res.json()["id"]

    # 3. Mock inference to return low confidence (<0.85)
    import app.ml.inference
    monkeypatch.setattr(app.ml.inference, "predict_image", lambda x: {"class_name": f"Tomato___{unique_disease_name.replace(' ', '_')}", "confidence": 0.60, "is_healthy": False})

    # 4. Upload image as Farmer (should be flagged for EXPERT_REVIEW)
    dummy = io.BytesIO(b"dummy")
    diag_res = client.post(
        f"{settings.API_V1_STR}/diagnostics/upload",
        headers={"Authorization": f"Bearer {farmer_token}"},
        data={"crop_id": crop_id},
        files={"file": ("dummy.jpg", dummy, "image/jpeg")}
    )
    diagnosis_id = diag_res.json()["id"]
    assert diag_res.json()["status"] == "EXPERT_REVIEW"

    # 5. Expert gets pending reviews
    pending_res = client.get(
        f"{settings.API_V1_STR}/experts/pending-reviews",
        headers={"Authorization": f"Bearer {expert_token}"}
    )
    assert pending_res.status_code == 200
    pending_ids = [d["id"] for d in pending_res.json()]
    assert diagnosis_id in pending_ids

    # 6. Farmer tries to get pending reviews (should fail)
    farmer_pending = client.get(
        f"{settings.API_V1_STR}/experts/pending-reviews",
        headers={"Authorization": f"Bearer {farmer_token}"}
    )
    assert farmer_pending.status_code == 403

    # 7. Expert submits validation (Correction)
    # Let's say the expert thinks it's actually another disease
    val_res = client.post(
        f"{settings.API_V1_STR}/experts/validations",
        headers={"Authorization": f"Bearer {expert_token}"},
        json={
            "diagnosis_id": diagnosis_id,
            "is_correct": False,
            "corrected_disease_id": disease_id, # Re-assign to a specific disease
            "expert_notes": "Actually, it's just stress, but we'll map it to this disease."
        }
    )
    assert val_res.status_code == 200
    
    # 8. Check diagnosis status is CORRECTED
    diag_check = client.get(
        f"{settings.API_V1_STR}/diagnostics/?crop_id={crop_id}",
        headers={"Authorization": f"Bearer {farmer_token}"}
    )
    diags = diag_check.json()
    diag = next(d for d in diags if d["id"] == diagnosis_id)
    assert diag["status"] == "CORRECTED"
