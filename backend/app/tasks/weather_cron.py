import sys
import os
import random
import datetime

sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..")))

from app.db.database import SessionLocal
from app.models.farm import Farm
from app.models.notification import Notification, NotificationType
from app.ml.risk_predictor import train_and_predict_risk

def run_daily_weather_forecast():
    """
    Cron Job: Simulates connecting to OpenWeatherMap, querying the 7-day forecast for 
    every farm, and running the XGBoost model to trigger push notifications.
    """
    db = SessionLocal()
    try:
        print("=== [CRON] Starting Daily OpenWeatherMap Forecast Simulation ===")
        farms = db.query(Farm).all()
        
        alerts_generated = 0
        for farm in farms:
            # 1. MOCK API CALL: Fetch 7-day forecast from OpenWeatherMap for farm.location
            # In a real app, this would be requests.get(f"https://api.openweathermap.org/data/2.5/forecast?lat={farm.lat}&lon={farm.lon}")
            forecast_temp = random.uniform(25.0, 31.0)
            forecast_humidity = random.uniform(70.0, 95.0)
            
            # 2. RUN XGBOOST AI MODEL
            probability = train_and_predict_risk(db, forecast_temp, forecast_humidity)
            
            # 3. TRIGGER AUTOMATED PREVENTIVE PUSH NOTIFICATION
            if probability > 0.80:
                print(f"[ALERT] Farm ID {farm.id} faces {(probability*100):.1f}% outbreak risk (Temp: {forecast_temp:.1f}C, Hum: {forecast_humidity:.1f}%)")
                
                # Check if we already alerted them recently
                existing = db.query(Notification).filter(
                    Notification.user_id == farm.owner_id,
                    Notification.type == "PREDICTIVE_ALERT"
                ).first()
                
                if not existing:
                    notif = Notification(
                        user_id=farm.owner_id,
                        title="URGENT: AI Disease Forecast",
                        message=f"OpenWeatherMap predicts 48hr conditions matching a {(probability*100):.1f}% risk for fungal outbreak. Consider preventive spraying.",
                        type="PREDICTIVE_ALERT", # Using string to avoid enum mismatches
                        is_read=False
                    )
                    db.add(notif)
                    alerts_generated += 1

        db.commit()
        print(f"=== [CRON] Completed. {alerts_generated} automated push notifications dispatched to farmers. ===")
        
    except Exception as e:
        print(f"Error in weather cron: {e}")
        db.rollback()
    finally:
        db.close()

if __name__ == "__main__":
    run_daily_weather_forecast()
