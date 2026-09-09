from sqlalchemy.orm import Session
from app.models.diagnosis import DiagnosisReport, DiagnosisStatus
from app.models.lab_referral import LabReferral, LabReferralStatus
from app.schemas.lab_referral import LabReferralCreate, LabReferralUpdate
from fastapi import HTTPException
from typing import List

def create_referral(db: Session, expert_id: int, referral_in: LabReferralCreate) -> LabReferral:
    report = db.query(DiagnosisReport).filter(DiagnosisReport.id == referral_in.diagnosis_id).first()
    if not report:
        raise HTTPException(status_code=404, detail="Diagnosis not found")
        
    if report.status in [DiagnosisStatus.RESOLVED, DiagnosisStatus.REJECTED]:
        raise HTTPException(status_code=400, detail="Cannot refer a resolved or rejected diagnosis")

    referral = LabReferral(
        diagnosis_id=referral_in.diagnosis_id,
        expert_id=expert_id,
        lab_name=referral_in.lab_name,
        tracking_number=referral_in.tracking_number,
        status=referral_in.status,
        results_summary=referral_in.results_summary
    )
    
    db.add(referral)
    report.status = DiagnosisStatus.LAB_REFERRED
    db.commit()
    db.refresh(referral)
    
    from app.services.notification_service import create_notification
    from app.models.notification import NotificationType
    farmer_id = report.crop.farm.owner_id
    create_notification(db, farmer_id, "Lab Referral Created", f"Your crop sample has been referred to {referral.lab_name} for expert lab analysis.", NotificationType.LAB_RESULT, reference_id=referral.diagnosis_id)
    
    return referral

def update_referral(db: Session, referral_id: int, update_in: LabReferralUpdate) -> LabReferral:
    referral = db.query(LabReferral).filter(LabReferral.id == referral_id).first()
    if not referral:
        raise HTTPException(status_code=404, detail="Lab referral not found")
        
    # Check if status is actually changing before applying updates
    status_changed = update_in.status is not None and update_in.status != referral.status

    update_data = update_in.model_dump(exclude_unset=True)
    for field, value in update_data.items():
        setattr(referral, field, value)
        
    db.commit()
    db.refresh(referral)
    
    if status_changed:
        from app.services.notification_service import create_notification
        from app.models.notification import NotificationType
        farmer_id = referral.diagnosis.crop.farm.owner_id
        
        if update_in.status == LabReferralStatus.COMPLETED:
            report = db.query(DiagnosisReport).filter(DiagnosisReport.id == referral.diagnosis_id).first()
            if report:
                report.status = DiagnosisStatus.CONFIRMED
                db.commit()
            create_notification(db, farmer_id, "Lab Results Ready", f"The lab results for {referral.lab_name} are ready.", NotificationType.LAB_RESULT, reference_id=referral.diagnosis_id)
            
        elif update_in.status == LabReferralStatus.CANCELLED:
            report = db.query(DiagnosisReport).filter(DiagnosisReport.id == referral.diagnosis_id).first()
            if report:
                report.status = DiagnosisStatus.EXPERT_REVIEW
                db.commit()
            create_notification(db, farmer_id, "Lab Referral Cancelled", f"The lab referral to {referral.lab_name} was cancelled.", NotificationType.EXPERT_UPDATE, reference_id=referral.diagnosis_id)
            
        elif update_in.status == LabReferralStatus.ANALYZING:
            create_notification(db, farmer_id, "Lab Analysis Started", f"The lab {referral.lab_name} is now actively analyzing your sample.", NotificationType.LAB_RESULT, reference_id=referral.diagnosis_id)
            
        elif update_in.status == LabReferralStatus.PENDING:
            create_notification(db, farmer_id, "Lab Referral Pending", f"Your lab referral to {referral.lab_name} is currently pending review.", NotificationType.LAB_RESULT, reference_id=referral.diagnosis_id)
    
    return referral

def get_referrals(db: Session, skip: int = 0, limit: int = 100) -> List[LabReferral]:
    return db.query(LabReferral).offset(skip).limit(limit).all()
