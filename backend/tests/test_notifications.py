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
            "name": f"Notify Test {role}",
            "role": role
        }
    )
    res = client.post(
        f"{settings.API_V1_STR}/auth/login",
        data={"username": phone, "password": "password"}
    )
    return res.json()["access_token"]

def test_notification_workflow(monkeypatch):
    farmer_token = get_auth_token("FARMER")
    expert_token = get_auth_token("EXPERT")
    
    # 1. Setup Farm and Crop
    farm_res = client.post(
        f"{settings.API_V1_STR}/farms/",
        headers={"Authorization": f"Bearer {farmer_token}"},
        json={"name": "Notify Farm", "area": 5.0, "latitude": 34.0, "longitude": -118.0}
    )
    farm_id = farm_res.json()["id"]
    
    crop_res = client.post(
        f"{settings.API_V1_STR}/crops/",
        headers={"Authorization": f"Bearer {farmer_token}"},
        json={"farm_id": farm_id, "crop_type": "Tomato"}
    )
    crop_id = crop_res.json()["id"]

    # 2. Add disease to KB
    unique_disease_name = f"NotifyDisease {uuid.uuid4().hex[:6]}"
    kb_res = client.post(
        f"{settings.API_V1_STR}/knowledge-base/",
        headers={"Authorization": f"Bearer {expert_token}"},
        json={
            "name": unique_disease_name,
            "category": "DISEASE",
            "symptoms": "Test"
        }
    )
    disease_id = kb_res.json()["id"]

    # 3. Mock inference to return low confidence (<0.85) to force expert review
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

    # 5. Check Farmer notifications (should be empty)
    notif_check_1 = client.get(f"{settings.API_V1_STR}/notifications/", headers={"Authorization": f"Bearer {farmer_token}"})
    assert len(notif_check_1.json()) == 0

    # 6. Expert confirms diagnosis
    client.post(
        f"{settings.API_V1_STR}/experts/validations",
        headers={"Authorization": f"Bearer {expert_token}"},
        json={
            "diagnosis_id": diagnosis_id,
            "is_correct": True
        }
    )

    # 7. Check Farmer notifications (should have 1)
    notif_check_2 = client.get(f"{settings.API_V1_STR}/notifications/", headers={"Authorization": f"Bearer {farmer_token}"})
    notifs = notif_check_2.json()
    assert len(notifs) == 1
    assert notifs[0]["type"] == "DIAGNOSIS_UPDATE"
    assert notifs[0]["is_read"] == False
    notif_id = notifs[0]["id"]

    # 8. Mark notification as read
    read_res = client.put(f"{settings.API_V1_STR}/notifications/{notif_id}/read", headers={"Authorization": f"Bearer {farmer_token}"})
    assert read_res.json()["is_read"] == True

    # 9. Fetch unread only (should be 0)
    notif_check_3 = client.get(f"{settings.API_V1_STR}/notifications/?unread_only=true", headers={"Authorization": f"Bearer {farmer_token}"})
    assert len(notif_check_3.json()) == 0
