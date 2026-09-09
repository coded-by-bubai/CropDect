from typing import Optional
from sqlalchemy.orm import Session
from app.models.diagnosis import DiagnosisReport, DiagnosisType, SeverityLevel
from app.models.knowledge_base import KnowledgeBase, IssueCategory
from app.schemas.ipm import IPMPlanResponse
from app.services.weather_service import fetch_weather_for_farm
from fastapi import HTTPException
from app.models.user import User

def generate_ipm_plan(db: Session, diagnosis_id: int, user: User) -> IPMPlanResponse:
    from app.models.crop import Crop
    from app.models.farm import Farm
    
    # Verify diagnosis ownership or expert access
    if user.role in ["EXPERT", "ADMIN"]:
        report = db.query(DiagnosisReport).filter(DiagnosisReport.id == diagnosis_id).first()
    else:
        report = db.query(DiagnosisReport).join(Crop).join(Farm).filter(
            DiagnosisReport.id == diagnosis_id,
            Farm.owner_id == user.id
        ).first()
    
    if not report:
        raise HTTPException(status_code=404, detail="Diagnosis report not found or access denied")
        
    if report.diagnosis_type == DiagnosisType.HEALTHY:
        return IPMPlanResponse(
            diagnosis_id=diagnosis_id,
            disease_name="Healthy",
            severity_warning="Your crop is healthy! Keep up the good work.",
            immediate_actions=["Continue current watering and fertilizing schedule."],
            cultural_practices=["Maintain optimal spacing for airflow.", "Regularly scout for pests."],
            biological_controls=["Encourage natural predators like ladybugs."],
            chemical_controls=[]
        )
        
    kb_item = None
    if report.disease_id:
        kb_item = db.query(KnowledgeBase).filter(KnowledgeBase.id == report.disease_id).first()
    elif report.pest_id:
        kb_item = db.query(KnowledgeBase).filter(KnowledgeBase.id == report.pest_id).first()
        
    disease_name = "Crop Disease"
    if kb_item:
        disease_name = kb_item.name
    elif report.model_version:
        parts = report.model_version.split("___", 1)
        disease_name = parts[1].replace("_", " ") if len(parts) > 1 else parts[0].replace("_", " ")

    # Generate Urgency / Severity Warning
    severity_warning = "Monitor the situation closely."
    immediate_actions = []
    
    if report.severity == SeverityLevel.CRITICAL:
        severity_warning = "CRITICAL ALERT: This disease spreads rapidly and can destroy the crop. Immediate action required!"
        immediate_actions.append("Immediately quarantine or remove heavily infected plants to prevent spread.")
    elif report.severity == SeverityLevel.HIGH:
        severity_warning = "HIGH WARNING: Significant threat to crop yield."
        immediate_actions.append("Remove infected leaves and avoid overhead watering.")
    elif report.severity == SeverityLevel.MODERATE:
        severity_warning = "MODERATE: Treatable if action is taken early."
        immediate_actions.append("Monitor progression and apply baseline treatments.")
    elif report.severity == SeverityLevel.LOW:
        severity_warning = "LOW: Early stages or minor infection."
        immediate_actions.append("Mark the plant and observe for 48 hours.")
    
    # Parse DB fields for controls with fallbacks
    cultural_practices = [kb_item.prevention_strategies] if (kb_item and kb_item.prevention_strategies) else [
        "Maintain adequate plant spacing for aeration and sunlight penetration.",
        "Practice regular field sanitation and crop rotation to interrupt spore spread."
    ]
    
    chemical_controls = []
    biological_controls = []
    
    treatment_str = kb_item.treatment_recommendations if (kb_item and kb_item.treatment_recommendations) else ""
    if treatment_str and any(w in treatment_str.lower() for w in ["fungicide", "pesticide", "spray", "copper", "chemical"]):
        chemical_controls.append(treatment_str)
    elif treatment_str:
        biological_controls.append(treatment_str)
            
    # Standard agricultural recommendations if controls list is empty
    if not chemical_controls and report.severity in [SeverityLevel.HIGH, SeverityLevel.CRITICAL]:
        chemical_controls.append("Apply a registered broad-spectrum fungicide or copper-based spray in early morning.")
    if not biological_controls:
        biological_controls.append("Apply organic bio-fungicides or diluted cold-pressed neem oil (0.5% concentration).")

    # Fetch weather for the farm to inject localized warnings safely
    try:
        if report.crop and report.crop.farm_id:
            weather = fetch_weather_for_farm(db=db, farm_id=report.crop.farm_id, owner_id=owner_id)
            if weather and weather.risk_level == "HIGH_FUNGAL_RISK":
                immediate_actions.insert(0, "WEATHER ALERT: High humidity/rain detected. Fungal pathogens spread rapidly in wet conditions. Apply treatment BEFORE rain and maximize drainage.")
            elif weather and weather.risk_level == "HIGH_PEST_RISK":
                immediate_actions.insert(0, "WEATHER ALERT: Hot and dry conditions detected. Pests reproduce exponentially in current conditions. Increase canopy scouting.")
    except Exception:
        pass  # Do not block IPM plan if weather is temporarily unavailable

    return IPMPlanResponse(
        diagnosis_id=diagnosis_id,
        disease_name=disease_name,
        severity_warning=severity_warning,
        immediate_actions=immediate_actions,
        cultural_practices=cultural_practices,
        biological_controls=biological_controls,
        chemical_controls=chemical_controls
    )
