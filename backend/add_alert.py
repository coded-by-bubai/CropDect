import sys
import os

sys.path.append(os.path.abspath(os.path.dirname(__file__)))

from app.db.database import SessionLocal
from app.models.notification import Notification, NotificationType
from app.models.farm import Farm

def add_alert():
    db = SessionLocal()
    try:
        # Get the first farm to attach the alert to its owner
        farm = db.query(Farm).first()
        if not farm:
            print("No farm found!")
            return
            
        print(f"Adding PREDICTIVE_ALERT for user {farm.owner_id} near Farm {farm.id}...")
        
        # Check if already exists
        existing = db.query(Notification).filter(
            Notification.user_id == farm.owner_id,
            Notification.type == NotificationType.PREDICTIVE_ALERT
        ).first()
        
        if not existing:
            alert = Notification(
                user_id=farm.owner_id,
                title="AI Forecast: High Disease Risk",
                message="XGBoost model predicts 94% chance of Powdery Mildew due to upcoming 92% humidity.",
                type=NotificationType.PREDICTIVE_ALERT,
                is_read=False
            )
            db.add(alert)
            db.commit()
            print("Successfully added predictive alert!")
        else:
            print("Predictive alert already exists for this user.")
            
    except Exception as e:
        print(f"Error adding alert: {e}")
        db.rollback()
    finally:
        db.close()

if __name__ == "__main__":
    add_alert()
