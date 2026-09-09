import logging
from fastapi import UploadFile, HTTPException
from sqlalchemy.orm import Session
from app.models.diagnosis import DiagnosisReport, DiagnosisStatus
from app.models.monitoring import MonitoringLog, HealthStatus
from app.models.crop import Crop
from app.models.farm import Farm
from app.schemas.monitoring import MonitoringLogCreate
from app.core.config import settings
from typing import List, Optional

import cloudinary
import cloudinary.uploader

logger = logging.getLogger(__name__)

from fastapi import BackgroundTasks

def _async_cloudinary_upload(log_id: int, file_data: bytes):
    """Background task to upload image to Cloudinary and update log."""
    cloudinary_configured = (
        settings.CLOUDINARY_CLOUD_NAME
        and settings.CLOUDINARY_API_KEY
        and settings.CLOUDINARY_API_SECRET
    )
    if not cloudinary_configured or len(file_data) < 64:
        return
        
    try:
        cloudinary.config(
            cloud_name=settings.CLOUDINARY_CLOUD_NAME,
            api_key=settings.CLOUDINARY_API_KEY,
            api_secret=settings.CLOUDINARY_API_SECRET,
        )
        result = cloudinary.uploader.upload(file_data, folder="cropdect/monitoring", timeout=20)
        secure_url = result.get("secure_url")
        if secure_url:
            from app.db.database import SessionLocal
            db_local = SessionLocal()
            try:
                log = db_local.query(MonitoringLog).filter(MonitoringLog.id == log_id).first()
                if log:
                    log.image_url = secure_url
                    db_local.commit()
            finally:
                db_local.close()
    except Exception as e:
        logger.error(f"Cloudinary async upload failed for monitoring: {e}")

def add_monitoring_log(
    db: Session, 
    diagnosis_id: int, 
    owner_id: int, 
    log_in: MonitoringLogCreate,
    file_bytes: Optional[bytes] = None,
    background_tasks: Optional[BackgroundTasks] = None
) -> MonitoringLog:
    # Verify ownership of diagnosis
    report = db.query(DiagnosisReport).join(Crop).join(Farm).filter(
        DiagnosisReport.id == diagnosis_id,
        Farm.owner_id == owner_id
    ).first()
    
    if not report:
        raise HTTPException(status_code=404, detail="Diagnosis not found or access denied")
        
    log = MonitoringLog(
        diagnosis_id=diagnosis_id,
        image_url=None, # Updated in background task
        notes=log_in.notes,
        health_status=log_in.health_status
    )
    db.add(log)
    
    if log_in.health_status == HealthStatus.RESOLVED:
        report.status = DiagnosisStatus.RESOLVED
        
    db.commit()
    db.refresh(log)
    
    if file_bytes and background_tasks:
        background_tasks.add_task(_async_cloudinary_upload, log.id, file_bytes)
        
    return log

def get_monitoring_logs(db: Session, diagnosis_id: int, owner_id: int) -> List[MonitoringLog]:
    # Verify ownership
    report = db.query(DiagnosisReport).join(Crop).join(Farm).filter(
        DiagnosisReport.id == diagnosis_id,
        Farm.owner_id == owner_id
    ).first()
    
    if not report:
        raise HTTPException(status_code=404, detail="Diagnosis not found or access denied")
        
    return db.query(MonitoringLog).filter(MonitoringLog.diagnosis_id == diagnosis_id).order_by(MonitoringLog.created_at.desc()).all()


def get_monitoring_logs_for_expert(db: Session, diagnosis_id: int) -> List[MonitoringLog]:
    """Experts can view monitoring logs without ownership check."""
    report = db.query(DiagnosisReport).filter(DiagnosisReport.id == diagnosis_id).first()
    if not report:
        raise HTTPException(status_code=404, detail="Diagnosis not found")
    return db.query(MonitoringLog).filter(MonitoringLog.diagnosis_id == diagnosis_id).order_by(MonitoringLog.created_at.desc()).all()


def expert_review_log(
    db: Session, 
    log_id: int, 
    expert_id: int, 
    expert_notes: str
) -> MonitoringLog:
    """Allow an expert to review and comment on a monitoring log."""
    log = db.query(MonitoringLog).filter(MonitoringLog.id == log_id).first()
    if not log:
        raise HTTPException(status_code=404, detail="Monitoring log not found")
    
    log.expert_reviewed = True
    log.expert_id = expert_id
    log.expert_notes = expert_notes
    
    db.commit()
    db.refresh(log)
    
    # Send notification to the farmer
    try:
        report = db.query(DiagnosisReport).filter(DiagnosisReport.id == log.diagnosis_id).first()
        if report:
            crop = db.query(Crop).filter(Crop.id == report.crop_id).first()
            if crop:
                farm = db.query(Farm).filter(Farm.id == crop.farm_id).first()
                if farm:
                    from app.services.notification_service import create_notification
                    from app.models.notification import NotificationType
                    create_notification(
                        db=db,
                        user_id=farm.owner_id,
                        title="Expert Review Added",
                        message="An expert has reviewed your crop follow-up log.",
                        type=NotificationType.DIAGNOSIS_UPDATE,
                        reference_id=log.diagnosis_id
                    )
    except Exception as e:
        logger.error(f"Failed to send expert review notification: {e}")
        
    return log
