from sqlalchemy.orm import Session
from app.models.diagnosis import DiagnosisReport, DiagnosisStatus, DiagnosisType
from app.models.expert_validation import ExpertValidation
from app.schemas.expert import ExpertValidationCreate
from fastapi import HTTPException
from typing import List

def get_pending_reviews(db: Session, skip: int = 0, limit: int = 100) -> List[DiagnosisReport]:
    from app.services.diagnosis_service import _enrich_diagnosis
    reports = db.query(DiagnosisReport).filter(DiagnosisReport.status == DiagnosisStatus.EXPERT_REVIEW).offset(skip).limit(limit).all()
    return [_enrich_diagnosis(r) for r in reports]

def get_follow_ups(db: Session, skip: int = 0, limit: int = 100) -> List[DiagnosisReport]:
    from app.services.diagnosis_service import _enrich_diagnosis
    from app.models.monitoring import MonitoringLog
    reports = (
        db.query(DiagnosisReport)
        .join(MonitoringLog, MonitoringLog.diagnosis_id == DiagnosisReport.id)
        .filter(
            DiagnosisReport.status != DiagnosisStatus.RESOLVED,
            MonitoringLog.expert_reviewed == False
        )
        .distinct()
        .order_by(DiagnosisReport.updated_at.desc())
        .offset(skip)
        .limit(limit)
        .all()
    )
    return [_enrich_diagnosis(r) for r in reports]

def get_completed_cases(db: Session, expert_id: int, skip: int = 0, limit: int = 100) -> List[DiagnosisReport]:
    """Get all diagnoses reviewed by this expert (CONFIRMED or CORRECTED), most recent first."""
    from app.services.diagnosis_service import _enrich_diagnosis
    # Find all diagnosis IDs this expert has validated
    validated_ids = (
        db.query(ExpertValidation.diagnosis_id)
        .filter(ExpertValidation.expert_id == expert_id)
        .subquery()
    )
    reports = (
        db.query(DiagnosisReport)
        .filter(
            DiagnosisReport.id.in_(validated_ids),
            DiagnosisReport.status.in_([DiagnosisStatus.CONFIRMED, DiagnosisStatus.CORRECTED])
        )
        .order_by(DiagnosisReport.updated_at.desc())
        .offset(skip)
        .limit(limit)
        .all()
    )
    return [_enrich_diagnosis(r, db) for r in reports]

def submit_validation(db: Session, expert_id: int, validation_in: ExpertValidationCreate) -> ExpertValidation:
    report = db.query(DiagnosisReport).filter(DiagnosisReport.id == validation_in.diagnosis_id).first()
    if not report:
        raise HTTPException(status_code=404, detail="Diagnosis not found")
        
    validation = ExpertValidation(
        diagnosis_id=validation_in.diagnosis_id,
        expert_id=expert_id,
        is_correct=validation_in.is_correct,
        corrected_disease_id=validation_in.corrected_disease_id,
        corrected_pest_id=validation_in.corrected_pest_id,
        expert_notes=validation_in.expert_notes
    )
    
    db.add(validation)
    
    if validation_in.is_correct:
        report.status = DiagnosisStatus.CONFIRMED
    else:
        report.status = DiagnosisStatus.CORRECTED
        if validation_in.corrected_disease_id:
            report.diagnosis_type = DiagnosisType.DISEASE
            report.disease_id = validation_in.corrected_disease_id
            report.pest_id = None
        elif validation_in.corrected_pest_id:
            report.diagnosis_type = DiagnosisType.PEST
            report.pest_id = validation_in.corrected_pest_id
            report.disease_id = None
        else:
            # Custom condition: Clear out AI IDs
            report.diagnosis_type = DiagnosisType.UNKNOWN
            report.disease_id = None
            report.pest_id = None
            
    farmer_id = None
    if report.crop and report.crop.farm:
        farmer_id = report.crop.farm.owner_id
        
    db.commit()
    db.refresh(validation)
    
    # Notify farmer
    if farmer_id:
        from app.services.notification_service import create_notification
        from app.models.notification import NotificationType
        if validation_in.is_correct:
            create_notification(db, farmer_id, "Diagnosis Confirmed", "An expert has confirmed your AI diagnosis.", NotificationType.DIAGNOSIS_UPDATE, reference_id=validation_in.diagnosis_id)
        else:
            create_notification(db, farmer_id, "Diagnosis Corrected", "An expert has corrected your AI diagnosis. Please check the new IPM plan.", NotificationType.DIAGNOSIS_UPDATE, reference_id=validation_in.diagnosis_id)
        
    return validation
