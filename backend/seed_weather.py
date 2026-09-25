import sys
import os
import random
import datetime

sys.path.append(os.path.abspath(os.path.dirname(__file__)))

from app.db.database import SessionLocal
from app.models.diagnosis import DiagnosisReport, DiagnosisType, SeverityLevel, DiagnosisStatus
from app.models.crop import Crop

def seed_data():
    db = SessionLocal()
    try:
        # Find any crop to attach these reports to
        crop = db.query(Crop).first()
        if not crop:
            print("No crop found in database to attach data to!")
            return
            
        print(f"Seeding dummy weather data for Crop ID {crop.id}...")
        
        added_count = 0
        
        # Add 20 HIGH RISK cases (High humidity > 85, Temp 24-32)
        for _ in range(20):
            report = DiagnosisReport(
                crop_id=crop.id,
                disease_id=None,
                diagnosis_type=DiagnosisType.DISEASE,
                confidence=0.9,
                severity=random.choice([SeverityLevel.HIGH, SeverityLevel.CRITICAL]),
                status=DiagnosisStatus.AI_PREDICTED,
                image_url="dummy",
                location="POINT(88.0 22.0)",
                model_version="Powdery Mildew v1",
                infection_temp_c=random.uniform(24.0, 32.0),
                infection_humidity_percent=random.uniform(85.0, 98.0),
                created_at=datetime.datetime.now()
            )
            db.add(report)
            added_count += 1
            
        # Add 20 LOW RISK cases (Low humidity < 60, varied Temp)
        for _ in range(20):
            report = DiagnosisReport(
                crop_id=crop.id,
                disease_id=None,
                diagnosis_type=DiagnosisType.HEALTHY,
                confidence=0.9,
                severity=random.choice([SeverityLevel.LOW, SeverityLevel.MODERATE]),
                status=DiagnosisStatus.AI_PREDICTED,
                image_url="dummy",
                location="POINT(88.0 22.0)",
                model_version="Healthy Crop v1",
                infection_temp_c=random.uniform(15.0, 35.0),
                infection_humidity_percent=random.uniform(30.0, 60.0),
                created_at=datetime.datetime.now()
            )
            db.add(report)
            added_count += 1
            
        db.commit()
        print(f"Successfully seeded {added_count} diagnosis reports!")
        
    except Exception as e:
        print(f"Error seeding data: {e}")
        db.rollback()
    finally:
        db.close()

if __name__ == "__main__":
    seed_data()
