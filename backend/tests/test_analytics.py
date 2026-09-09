import pytest
import io
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
            "name": f"Analytics Test {role}",
            "role": role
        }
    )
    res = client.post(
        f"{settings.API_V1_STR}/auth/login",
        data={"username": phone, "password": "password"}
    )
    return res.json()["access_token"]

def test_analytics_endpoints(monkeypatch):
    farmer_token = get_auth_token("FARMER")
    officer_token = get_auth_token("ADMIN")
    expert_token = get_auth_token("EXPERT")
    
    # 1. Setup Farm and Crop
    farm_res = client.post(
        f"{settings.API_V1_STR}/farms/",
        headers={"Authorization": f"Bearer {farmer_token}"},
        json={"name": "Analytics Farm", "area": 10.0, "latitude": 35.0, "longitude": -120.0}
    )
    farm_id = farm_res.json()["id"]
    
    crop_res = client.post(
        f"{settings.API_V1_STR}/crops/",
        headers={"Authorization": f"Bearer {farmer_token}"},
        json={"farm_id": farm_id, "crop_type": "Potato"}
    )
    crop_id = crop_res.json()["id"]

    # 2. Add disease to KB
    unique_disease_name = f"AnalyticsBlight{uuid.uuid4().hex[:6]}"
    kb_res = client.post(
        f"{settings.API_V1_STR}/knowledge-base/",
        headers={"Authorization": f"Bearer {expert_token}"},
        json={
            "name": unique_disease_name,
            "category": "DISEASE",
            "symptoms": "Test symptoms"
        }
    )
    disease_id = kb_res.json()["id"]

    # 3. Mock inference to predict the specific disease
    import app.ml.inference
    monkeypatch.setattr(app.ml.inference, "predict_image", lambda x: {"class_name": f"Potato___{unique_disease_name}", "confidence": 0.95, "is_healthy": False})

    # 4. Upload image as Farmer (Creates a DiagnosisReport)
    dummy = io.BytesIO(b"dummy")
    diag_res = client.post(
        f"{settings.API_V1_STR}/diagnostics/upload",
        headers={"Authorization": f"Bearer {farmer_token}"},
        data={"crop_id": crop_id},
        files={"file": ("dummy.jpg", dummy, "image/jpeg")}
    )
    print("DIAG RES:", diag_res.json())

    # 5. Verify Farmer CANNOT access analytics (RBAC Check)
    farmer_stats = client.get(f"{settings.API_V1_STR}/analytics/stats", headers={"Authorization": f"Bearer {farmer_token}"})
    assert farmer_stats.status_code == 403

    # 6. Verify Agri Officer CAN access stats
    officer_stats = client.get(f"{settings.API_V1_STR}/analytics/stats", headers={"Authorization": f"Bearer {officer_token}"})
    assert officer_stats.status_code == 200
    stats_data = officer_stats.json()
    assert stats_data["total_farms_registered"] > 0
    assert stats_data["total_diagnoses_processed"] > 0
    assert stats_data["active_unresolved_issues"] > 0

    # 7. Verify Disease Distribution aggregates correctly
    officer_dist = client.get(f"{settings.API_V1_STR}/analytics/distribution", headers={"Authorization": f"Bearer {officer_token}"})
    assert officer_dist.status_code == 200
    dist_data = officer_dist.json()["distribution"]
    
    # Check that we have at least one disease in distribution
    assert len(dist_data) > 0
    assert dist_data[0]["count"] >= 1
