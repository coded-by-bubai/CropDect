from fastapi.testclient import TestClient
from app.main import app
from app.core.config import settings
from sqlalchemy.orm import Session
from app.db.database import SessionLocal
import pytest
import io
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
            "name": f"Diag Test {role}",
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

def test_image_upload():
    token = get_auth_token()
    
    # 1. Create a Farm
    farm_res = client.post(
        f"{settings.API_V1_STR}/farms/",
        headers={"Authorization": f"Bearer {token}"},
        json={
            "name": "Diag Farm",
            "area": 10.5,
            "latitude": 37.7749,
            "longitude": -122.4194
        }
    )
    farm_id = farm_res.json()["id"]

    # 2. Create a Crop
    crop_res = client.post(
        f"{settings.API_V1_STR}/crops/",
        headers={"Authorization": f"Bearer {token}"},
        json={
            "farm_id": farm_id,
            "crop_type": "Wheat"
        }
    )
    crop_id = crop_res.json()["id"]

    # 3. Upload an Image
    # Create a dummy image file in memory
    dummy_image = io.BytesIO(b"dummy image data")
    
    response = client.post(
        f"{settings.API_V1_STR}/diagnostics/upload",
        headers={"Authorization": f"Bearer {token}"},
        data={
            "crop_id": crop_id,
            "latitude": 37.7749,
            "longitude": -122.4194
        },
        files={
            "file": ("test.jpg", dummy_image, "image/jpeg")
        }
    )
    assert response.status_code == 200
    data = response.json()
    assert data["crop_id"] == crop_id
    assert data["status"] == "EXPERT_REVIEW" # Dummy image causes prediction failure, 0.0 confidence
    assert data["severity"] == "MODERATE"    # Unknown disease defaults to MODERATE
    assert "/static/" in data["image_url"]

def test_upload_non_image():
    token = get_auth_token()
    
    dummy_text = io.BytesIO(b"hello world")
    response = client.post(
        f"{settings.API_V1_STR}/diagnostics/upload",
        headers={"Authorization": f"Bearer {token}"},
        data={"crop_id": 9999}, # Crop ID doesn't matter because it will fail on file type first
        files={
            "file": ("test.txt", dummy_text, "text/plain")
        }
    )
    assert response.status_code == 400
    assert "image" in response.json()["detail"]

def test_ipm_plan_generation(monkeypatch):
    import app.ml.inference
    def mock_predict_success(image_path):
        return {
            "class_name": "Tomato___Early_blight",
            "confidence": 0.95,
            "is_healthy": False
        }
    monkeypatch.setattr(app.ml.inference, "predict_image", mock_predict_success)

    token = get_auth_token()
    
    # 1. Create a Farm
    farm_res = client.post(
        f"{settings.API_V1_STR}/farms/",
        headers={"Authorization": f"Bearer {token}"},
        json={"name": "IPM Farm", "area": 5.0, "latitude": 37.77, "longitude": -122.41}
    )
    farm_id = farm_res.json()["id"]

    # 2. Create a Crop
    crop_res = client.post(
        f"{settings.API_V1_STR}/crops/",
        headers={"Authorization": f"Bearer {token}"},
        json={"farm_id": farm_id, "crop_type": "Wheat"}
    )
    crop_id = crop_res.json()["id"]

    # 3. We must mock the inference and inject a KB item to get a real IPM plan.
    # We will log in as expert to create the KB item
    expert_token = get_auth_token("EXPERT")
    kb_res = client.post(
        f"{settings.API_V1_STR}/knowledge-base/",
        headers={"Authorization": f"Bearer {expert_token}"},
        json={
            "name": "Early blight", # Matches what test mock prediction outputs
            "category": "DISEASE",
            "symptoms": "Brown spots with concentric rings.",
            "treatment_recommendations": "Apply copper-based fungicide.",
            "prevention_strategies": "Rotate crops and space plants."
        }
    )
    assert kb_res.status_code == 200 
    
    # 4. Upload an Image (will be mock predicted as Early Blight, mapped to DB)
    dummy_image = io.BytesIO(b"dummy image data")
    upload_res = client.post(
        f"{settings.API_V1_STR}/diagnostics/upload",
        headers={"Authorization": f"Bearer {token}"},
        data={"crop_id": crop_id},
        files={"file": ("ipm.jpg", dummy_image, "image/jpeg")}
    )
    
    assert upload_res.status_code == 200
    diagnosis_id = upload_res.json()["id"]
    
    # 5. Fetch IPM Plan
    ipm_res = client.get(
        f"{settings.API_V1_STR}/diagnostics/{diagnosis_id}/ipm-plan",
        headers={"Authorization": f"Bearer {token}"}
    )
    assert ipm_res.status_code == 200
    ipm_data = ipm_res.json()
    assert ipm_data["disease_name"] == "Early blight"
    assert "copper-based fungicide" in ipm_data["chemical_controls"][0]
    assert "Rotate crops" in ipm_data["cultural_practices"][0]
