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
            "name": f"Lab Test {role}",
            "role": role
        }
    )
    res = client.post(
        f"{settings.API_V1_STR}/auth/login",
        data={"username": phone, "password": "password"}
    )
    return res.json()["access_token"]

def test_lab_referral_workflow(monkeypatch):
    farmer_token = get_auth_token("FARMER")
    expert_token = get_auth_token("EXPERT")
    
    # 1. Setup Farm and Crop
    farm_res = client.post(
        f"{settings.API_V1_STR}/farms/",
        headers={"Authorization": f"Bearer {farmer_token}"},
        json={"name": "Lab Farm", "area": 5.0, "latitude": 34.0, "longitude": -118.0}
    )
    farm_id = farm_res.json()["id"]
    
    crop_res = client.post(
        f"{settings.API_V1_STR}/crops/",
        headers={"Authorization": f"Bearer {farmer_token}"},
        json={"farm_id": farm_id, "crop_type": "Tomato"}
    )
    crop_id = crop_res.json()["id"]

    # 2. Add disease to KB
    unique_disease_name = f"LabDisease {uuid.uuid4().hex[:6]}"
    kb_res = client.post(
        f"{settings.API_V1_STR}/knowledge-base/",
        headers={"Authorization": f"Bearer {expert_token}"},
        json={
            "name": unique_disease_name,
            "category": "DISEASE",
            "symptoms": "Requires lab testing"
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

    # 5. Farmer tries to refer to lab (should fail)
    farmer_lab = client.post(
        f"{settings.API_V1_STR}/labs/referrals",
        headers={"Authorization": f"Bearer {farmer_token}"},
        json={
            "diagnosis_id": diagnosis_id,
            "lab_name": "AgriLab USA"
        }
    )
    assert farmer_lab.status_code == 403

    # 6. Expert refers diagnosis to Lab
    expert_lab = client.post(
        f"{settings.API_V1_STR}/labs/referrals",
        headers={"Authorization": f"Bearer {expert_token}"},
        json={
            "diagnosis_id": diagnosis_id,
            "lab_name": "AgriLab USA",
            "tracking_number": "TRK12345"
        }
    )
    assert expert_lab.status_code == 200
    referral_id = expert_lab.json()["id"]
    assert expert_lab.json()["status"] == "PENDING"
    
    # 7. Check diagnosis status is LAB_REFERRED
    diag_check = client.get(
        f"{settings.API_V1_STR}/diagnostics/?crop_id={crop_id}",
        headers={"Authorization": f"Bearer {farmer_token}"}
    )
    diags = diag_check.json()
    diag = next(d for d in diags if d["id"] == diagnosis_id)
    assert diag["status"] == "LAB_REFERRED"

    # 8. Expert updates tracking status to COMPLETED
    expert_update = client.put(
        f"{settings.API_V1_STR}/labs/referrals/{referral_id}",
        headers={"Authorization": f"Bearer {expert_token}"},
        json={
            "status": "COMPLETED",
            "results_summary": "Confirmed presence of specific viral strain."
        }
    )
    assert expert_update.status_code == 200
    assert expert_update.json()["status"] == "COMPLETED"
    assert "Confirmed" in expert_update.json()["results_summary"]
