from sqlalchemy.orm import Session
from sqlalchemy import func
from app.models.diagnosis import DiagnosisReport, DiagnosisStatus, SeverityLevel
from app.models.crop import Crop
from app.models.farm import Farm
from app.models.notification import Notification, NotificationType
from app.services.weather_service import fetch_weather_for_farm

def run_predictive_weather_scan(db: Session):
    """
    Scans recent outbreaks for weather signatures and matches them 
    against the current weather of healthy farms to send predictive alerts.
    """
    # 1. Calculate Average Weather Signatures for Active Outbreaks
    outbreaks = db.query(
        DiagnosisReport.disease_id,
        func.avg(DiagnosisReport.infection_temp_c).label('avg_temp'),
        func.avg(DiagnosisReport.infection_humidity_percent).label('avg_humidity')
    ).filter(
        DiagnosisReport.status == DiagnosisStatus.CONFIRMED,
        DiagnosisReport.severity.in_([SeverityLevel.HIGH, SeverityLevel.CRITICAL]),
        DiagnosisReport.infection_temp_c.isnot(None),
        DiagnosisReport.infection_humidity_percent.isnot(None),
        DiagnosisReport.disease_id.isnot(None)
    ).group_by(DiagnosisReport.disease_id).all()
    
    if not outbreaks:
        return {"status": "No outbreaks with weather signatures found."}

    alerts_sent = 0

    # 2. Match against healthy farms
    for disease_id, avg_temp, avg_humidity in outbreaks:
        all_farms = db.query(Farm).all()
        for farm in all_farms:
            # Check if this farm already has this disease
            has_disease = db.query(DiagnosisReport).join(Crop).filter(
                Crop.farm_id == farm.id,
                DiagnosisReport.disease_id == disease_id,
                DiagnosisReport.status.in_([DiagnosisStatus.AI_PREDICTED, DiagnosisStatus.CONFIRMED])
            ).first()
            
            if has_disease:
                continue 
                
            try:
                weather = fetch_weather_for_farm(db, farm.id, farm.owner_id)
            except Exception:
                continue
                
            # Signature Match: +/- 3°C and +/- 10% Humidity
            temp_match = abs(weather.current_temp_c - avg_temp) <= 3.0
            humidity_match = abs(weather.current_humidity_percent - avg_humidity) <= 10.0
            
            if temp_match and humidity_match:
                # Prevent spam: check if alert recently sent for this disease
                existing_alert = db.query(Notification).filter(
                    Notification.user_id == farm.owner_id,
                    Notification.type == NotificationType.PREDICTIVE_ALERT,
                    Notification.message.like(f"%Disease ID {disease_id}%")
                ).first()
                
                if not existing_alert:
                    notification = Notification(
                        user_id=farm.owner_id,
                        title="🚨 Predictive Outbreak Alert!",
                        message=f"Farms in other regions are experiencing severe outbreaks (Disease ID {disease_id}) under your exact current weather conditions ({weather.current_temp_c}°C, {weather.current_humidity_percent}% Humidity). Please take preventative measures immediately.",
                        type=NotificationType.PREDICTIVE_ALERT
                    )
                    db.add(notification)
                    alerts_sent += 1
                    
    db.commit()
    return {"status": "Scan complete", "alerts_sent": alerts_sent}

def run_predictive_weather_scan_background():
    from app.db.database import SessionLocal
    db = SessionLocal()
    try:
        run_predictive_weather_scan(db)
    finally:
        db.close()
