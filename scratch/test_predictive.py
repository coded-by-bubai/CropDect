import os
import sys

# Add backend dir to path
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..', 'backend')))

from app.db.database import SessionLocal
from app.models.user import User, UserRole
from app.models.farm import Farm
from app.models.crop import Crop
from app.models.diagnosis import DiagnosisReport, DiagnosisType, SeverityLevel, DiagnosisStatus
from app.models.notification import Notification, NotificationType
from app.services.predictive_alert_service import run_predictive_weather_scan

db = SessionLocal()

try:
    print("--- Setting up test data ---")
    # 1. Create a mock Expert
    expert = db.query(User).filter(User.email == "test_expert@cropdect.com").first()
    if not expert:
        expert = User(email="test_expert@cropdect.com", hashed_password="xyz", full_name="Expert", role=UserRole.EXPERT)
        db.add(expert)
        
    # 2. Create Farmer A (The Infected Farm)
    farmer_a = db.query(User).filter(User.email == "farmer_a@cropdect.com").first()
    if not farmer_a:
        farmer_a = User(email="farmer_a@cropdect.com", hashed_password="xyz", full_name="Farmer A", role=UserRole.FARMER)
        db.add(farmer_a)
    db.commit()

    farm_a = db.query(Farm).filter(Farm.owner_id == farmer_a.id).first()
    if not farm_a:
        farm_a = Farm(owner_id=farmer_a.id, name="Infected Farm A", area=10.0, location="POINT(78.96 20.59)")
        db.add(farm_a)
    db.commit()

    crop_a = db.query(Crop).filter(Crop.farm_id == farm_a.id).first()
    if not crop_a:
        crop_a = Crop(farm_id=farm_a.id, crop_type="Apple")
        db.add(crop_a)
    db.commit()

    # 3. Create Farmer B (The Healthy Farm nearby with same weather)
    farmer_b = db.query(User).filter(User.email == "farmer_b@cropdect.com").first()
    if not farmer_b:
        farmer_b = User(email="farmer_b@cropdect.com", hashed_password="xyz", full_name="Farmer B", role=UserRole.FARMER)
        db.add(farmer_b)
    db.commit()

    farm_b = db.query(Farm).filter(Farm.owner_id == farmer_b.id).first()
    if not farm_b:
        farm_b = Farm(owner_id=farmer_b.id, name="Healthy Farm B", area=5.0, location="POINT(78.96 20.59)")
        db.add(farm_b)
    db.commit()

    # 4. Inject a Confirmed Severe Diagnosis for Farm A with a specific Weather Signature
    report = db.query(DiagnosisReport).filter(DiagnosisReport.crop_id == crop_a.id, DiagnosisReport.disease_id == 999).first()
    if not report:
        report = DiagnosisReport(
            crop_id=crop_a.id,
            image_url="http://example.com/test.jpg",
            diagnosis_type=DiagnosisType.DISEASE,
            disease_id=999, # Mock Apple Scab
            confidence=0.95,
            severity=SeverityLevel.CRITICAL,
            status=DiagnosisStatus.CONFIRMED,
            location="POINT(78.96 20.59)",
            infection_temp_c=25.0, # The signature temp
            infection_humidity_percent=80.0 # The signature humidity
        )
        db.add(report)
        db.commit()
    
    print("Test data injected! Farm A has a confirmed CRITICAL outbreak at 25C and 80% humidity.")
    
    print("--- Running Predictive Weather Scan ---")
    result = run_predictive_weather_scan(db)
    print(f"Scan Result: {result}")
    
    print("--- Checking Farmer B's Notifications ---")
    notifs = db.query(Notification).filter(Notification.user_id == farmer_b.id).all()
    if notifs:
        for n in notifs:
            print(f"[PREDICTIVE ALERT SENT!] Title: {n.title} | Message: {n.message}")
    else:
        print("No alerts sent to Farmer B.")

finally:
    db.close()
