import random
from datetime import datetime, timezone
from sqlalchemy.orm import Session
from app.db.database import SessionLocal
from app.models.user import User, UserRole
from app.models.farm import Farm
from app.models.crop import Crop
from app.models.knowledge_base import KnowledgeBase, IssueCategory
from app.core.security import get_password_hash
from app.models.diagnosis import DiagnosisReport, DiagnosisStatus, SeverityLevel, DiagnosisType

def seed_data():
    db = SessionLocal()
    try:
        # Create a test expert
        expert = db.query(User).filter(User.phone == "1111111111").first()
        if not expert:
            expert = User(phone="1111111111", name="Dr. Expert", role=UserRole.EXPERT, password_hash=get_password_hash("password"))
            db.add(expert)
        
        # Create a test farmer
        farmer = db.query(User).filter(User.phone == "2222222222").first()
        if not farmer:
            farmer = User(phone="2222222222", name="Farmer Test", role=UserRole.FARMER, password_hash=get_password_hash("password"))
            db.add(farmer)
            db.commit()
            db.refresh(farmer)

        # Create KnowledgeBase entries (Diseases)
        diseases = ["Leaf Rust", "Blight", "Powdery Mildew", "Root Rot"]
        kb_entries = []
        for d in diseases:
            kb = db.query(KnowledgeBase).filter(KnowledgeBase.name == d).first()
            if not kb:
                kb = KnowledgeBase(name=d, scientific_name=d, category=IssueCategory.DISEASE, symptoms="Test", treatment_recommendations="Test")
                db.add(kb)
                db.commit()
                db.refresh(kb)
            kb_entries.append(kb)

        # Create a Farm in central India (approx 21.0, 79.0)
        farm = db.query(Farm).filter(Farm.name == "Test Farm Hub").first()
        if not farm:
            farm = Farm(owner_id=farmer.id, name="Test Farm Hub", area=10.0, location="POINT(79.0 21.0)")
            db.add(farm)
            db.commit()
            db.refresh(farm)

        # Create a Crop
        crop = db.query(Crop).filter(Crop.crop_type == "Wheat", Crop.farm_id == farm.id).first()
        if not crop:
            crop = Crop(farm_id=farm.id, crop_type="Wheat")
            db.add(crop)
            db.commit()
            db.refresh(crop)

        # Generate 15 random hotspot reports around the central location
        # lat: 21.0 +/- 0.5, lng: 79.0 +/- 0.5
        existing_reports = db.query(DiagnosisReport).count()
        if existing_reports < 15:
            for i in range(15):
                lat = 21.0 + random.uniform(-0.5, 0.5)
                lng = 79.0 + random.uniform(-0.5, 0.5)
                disease = random.choice(kb_entries)
                severity = random.choice([SeverityLevel.LOW, SeverityLevel.MODERATE, SeverityLevel.HIGH, SeverityLevel.CRITICAL])
                
                report = DiagnosisReport(
                    crop_id=crop.id,
                    disease_id=disease.id,
                    diagnosis_type=DiagnosisType.DISEASE,
                    image_url="https://res.cloudinary.com/n48tmea2/image/upload/v1/dummy",
                    model_version=disease.name,
                    confidence=random.uniform(0.7, 0.99),
                    severity=severity,
                    status=DiagnosisStatus.AI_PREDICTED,
                    location=f"POINT({lng} {lat})"
                )
                db.add(report)
            db.commit()
            print("Successfully seeded hotspot test data.")
        else:
            print("Test data already exists.")
    finally:
        db.close()

if __name__ == "__main__":
    seed_data()
