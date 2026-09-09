from sqlalchemy.orm import Session
from app.models.farm import Farm
from app.models.crop import Crop
from app.models.knowledge_base import KnowledgeBase
from app.schemas.risk import RiskAssessmentResponse, ThreatProfile
from app.services.weather_service import fetch_weather_for_farm
from fastapi import HTTPException

def generate_risk_assessment(db: Session, farm_id: int, owner_id: int) -> RiskAssessmentResponse:
    farm = db.query(Farm).filter(Farm.id == farm_id, Farm.owner_id == owner_id).first()
    if not farm:
        raise HTTPException(status_code=404, detail="Farm not found or access denied")
        
    crops = db.query(Crop).filter(Crop.farm_id == farm_id).all()
    if not crops:
        return RiskAssessmentResponse(farm_id=farm_id, overall_health_score=100, threats=[])
        
    weather = fetch_weather_for_farm(db=db, farm_id=farm_id, owner_id=owner_id)
    
    threats = []
    kb_items = db.query(KnowledgeBase).all()
    
    for crop in crops:
        crop_name = crop.crop_type.lower()
        
        for kb in kb_items:
            if kb.affected_crops and crop_name in kb.affected_crops.lower():
                risk = 10
                reason = f"Baseline risk for growing {crop.crop_type}."
                
                trigger = (kb.trigger_conditions or "").lower()
                
                # Check weather triggers
                if "humid" in trigger or "rain" in trigger or "wet" in trigger:
                    if weather.current_humidity_percent > 75 or weather.current_precipitation_mm > 5:
                        risk += 70
                        reason = f"High humidity/rain matches severe trigger conditions for {kb.name} on {crop.crop_type}."
                    elif weather.current_humidity_percent > 60:
                        risk += 30
                        reason = f"Moderate humidity elevates risk for {kb.name}."
                
                if "hot" in trigger or "dry" in trigger or "heat" in trigger:
                    if weather.current_temp_c > 30 and weather.current_humidity_percent < 40:
                        risk += 70
                        reason = f"Hot and dry weather matches severe trigger conditions for {kb.name} on {crop.crop_type}."
                
                if risk > 20:
                    threats.append(ThreatProfile(
                        disease_name=kb.name,
                        risk_percentage=min(100, risk),
                        reason=reason
                    ))
                    
    threats.sort(key=lambda x: x.risk_percentage, reverse=True)
    
    overall = 100
    if threats:
        overall = max(0, 100 - threats[0].risk_percentage)
        
    return RiskAssessmentResponse(
        farm_id=farm_id,
        overall_health_score=overall,
        threats=threats
    )
