import os
import uuid
import shutil
from typing import List, Optional
from fastapi import UploadFile, HTTPException
from geoalchemy2.shape import to_shape
import cloudinary
import cloudinary.uploader
from app.core.config import settings
from sqlalchemy.orm import Session
from app.models.diagnosis import DiagnosisReport, DiagnosisType, DiagnosisStatus, SeverityLevel
from app.models.crop import Crop
from app.models.farm import Farm
from geoalchemy2.shape import to_shape
import shapely.geometry
from app.core.logging import logger


def _parse_class_name(class_name: str) -> dict:
    """Parse a PlantVillage class name like 'Tomato___Early_blight' into crop/label parts."""
    if not class_name or class_name == "Unknown___Error":
        return {"crop_name": "Unknown", "label": "Analysis Error"}
    parts = class_name.split("___", 1)
    crop_name = parts[0].replace("_", " ").replace("(", "").replace(")", "").strip()
    label = parts[1].replace("_", " ").strip() if len(parts) > 1 else "Unknown"
    if label.lower() == "healthy":
        label = "Healthy"
    return {"crop_name": crop_name, "label": label}

def _enrich_diagnosis(report: DiagnosisReport, db: Optional[Session] = None) -> DiagnosisReport:
    if not report:
        return report
    report.longitude = None
    report.latitude = None
    if report.location is not None:
        try:
            point = to_shape(report.location)
            report.longitude = float(point.x)
            report.latitude = float(point.y)
        except Exception:
            report.longitude = None
            report.latitude = None
    # Inject human-readable label from stored class_name (stored in model_version field)
    if report.model_version:
        parsed = _parse_class_name(report.model_version)
        report.label = parsed["label"]
        report.crop_name = parsed["crop_name"]

    report.expert_notes = None
    report.expert_name = None
    report.is_correct = None
    if db:
        from app.models.expert_validation import ExpertValidation
        from app.models.lab_referral import LabReferral, LabReferralStatus
        
        validation = db.query(ExpertValidation).filter(ExpertValidation.diagnosis_id == report.id).order_by(ExpertValidation.id.desc()).first()
        if validation:
            report.expert_notes = validation.expert_notes
            report.expert_name = validation.expert.name if validation.expert else "Agronomist"
            report.is_correct = validation.is_correct
            
        lab = db.query(LabReferral).filter(LabReferral.diagnosis_id == report.id).order_by(LabReferral.id.desc()).first()
        if lab:
            if lab.status == LabReferralStatus.COMPLETED:
                lab_note = f"[Lab Result: {lab.lab_name}] {lab.results_summary}"
            elif lab.status == LabReferralStatus.PENDING:
                lab_note = f"[Lab Instructions: {lab.lab_name}] {lab.results_summary}"
            else:
                # For ANALYZING, IN_TRANSIT, RECEIVED, etc.
                lab_note = f"[Lab Update: {lab.lab_name}] {lab.results_summary}"
                
            if report.expert_notes:
                report.expert_notes += f"\n\n{lab_note}"
            else:
                report.expert_notes = lab_note
                report.expert_name = "Laboratory Referral"
                
    return report

from fastapi import UploadFile, BackgroundTasks

def process_image_upload(
    db: Session, 
    owner_id: int, 
    crop_id: int, 
    file: UploadFile,
    latitude: Optional[float] = None,
    longitude: Optional[float] = None,
    growth_stage: Optional[str] = None,
    background_tasks: Optional[BackgroundTasks] = None
) -> DiagnosisReport:
    # Verify ownership of crop
    crop = db.query(Crop).join(Farm).filter(
        Crop.id == crop_id, 
        Farm.owner_id == owner_id
    ).first()
    
    if not crop:
        # Auto-create a default farm and crop for the user if none exist
        farm = db.query(Farm).filter(Farm.owner_id == owner_id).first()
        if not farm:
            # Use device location if available, otherwise null island fallback
            if latitude is not None and longitude is not None and not (latitude == 0.0 and longitude == 0.0):
                farm_location = f"POINT({longitude} {latitude})"
            else:
                farm_location = "POINT(0 0)"
            farm = Farm(owner_id=owner_id, name="My Default Farm", area=10.0, location=farm_location)
            db.add(farm)
            db.flush()
        elif latitude is not None and longitude is not None and not (latitude == 0.0 and longitude == 0.0):
            # Update existing default farm location if it has no real location (POINT(0 0))
            try:
                point = to_shape(farm.location)
                if float(point.x) == 0.0 and float(point.y) == 0.0:
                    farm.location = f"POINT({longitude} {latitude})"
                    db.flush()
            except Exception:
                pass
        
        crop = db.query(Crop).filter(Crop.farm_id == farm.id).first()
        if not crop:
            crop = Crop(farm_id=farm.id, crop_type="Mixed")
            db.add(crop)
            db.flush()
        
        crop_id = crop.id
        db.commit()


    # Temporarily read into memory for ML inference
    file_bytes = file.file.read()
    file.file.seek(0)

    # Configure Cloudinary
    cloudinary_configured = (
        settings.CLOUDINARY_CLOUD_NAME
        and settings.CLOUDINARY_API_KEY
        and settings.CLOUDINARY_API_SECRET
    )
    if cloudinary_configured:
        cloudinary.config(
            cloud_name=settings.CLOUDINARY_CLOUD_NAME,
            api_key=settings.CLOUDINARY_API_KEY,
            api_secret=settings.CLOUDINARY_API_SECRET,
            secure=True,
        )

    wkt_point = None
    if latitude is not None and longitude is not None:
        try:
            lat_f = float(latitude)
            lng_f = float(longitude)
            if -90.0 <= lat_f <= 90.0 and -180.0 <= lng_f <= 180.0:
                wkt_point = f"POINT({lng_f} {lat_f})"
        except Exception:
            wkt_point = None

    # ── Run AI inference instantly ──────────────────
    from app.ml.inference import predict_image_bytes
    from app.models.knowledge_base import KnowledgeBase, IssueCategory

    try:
        prediction = predict_image_bytes(file_bytes)
    except Exception as e:
        logger.error(f"Inference error: {e}")
        prediction = {"class_name": "Unknown___Error", "confidence": 0.0, "is_healthy": False}
        
    image_url = "https://via.placeholder.com/400"
    # ───────────────────────────────────────────────────────────────────────

    # Attempt to map class name (e.g., "Tomato___Early_blight" -> "Early blight")
    kb_name = prediction["class_name"].split("___")[-1].replace("_", " ")
    kb_item = db.query(KnowledgeBase).filter(KnowledgeBase.name.ilike(f"%{kb_name}%")).first()
    
    diag_type = DiagnosisType.HEALTHY if prediction["is_healthy"] else DiagnosisType.UNKNOWN
    disease_id = None
    pest_id = None
    
    if kb_item:
        if kb_item.category == IssueCategory.DISEASE:
            diag_type = DiagnosisType.DISEASE
            disease_id = kb_item.id
        elif kb_item.category == IssueCategory.PEST:
            diag_type = DiagnosisType.PEST
            pest_id = kb_item.id

    # 1. Smart Severity Assignment
    calc_severity = SeverityLevel.LOW if prediction["is_healthy"] else SeverityLevel.MODERATE
    
    critical_diseases = ["late blight", "citrus greening", "esca", "black rot", "mosaic virus"]
    high_diseases = ["early blight", "bacterial spot", "virus", "rust"]
    
    kb_name_lower = kb_name.lower()
    if not prediction["is_healthy"]:
        if any(d in kb_name_lower for d in critical_diseases):
            calc_severity = SeverityLevel.CRITICAL
        elif any(d in kb_name_lower for d in high_diseases):
            calc_severity = SeverityLevel.HIGH

    # 2. Confidence Thresholding
    confidence_score = prediction["confidence"]
    calc_status = DiagnosisStatus.AI_PREDICTED
    if confidence_score < 0.85:
        calc_status = DiagnosisStatus.EXPERT_REVIEW

    db_report = DiagnosisReport(
        crop_id=crop_id,
        image_url=image_url,
        diagnosis_type=diag_type,
        disease_id=disease_id,
        pest_id=pest_id,
        confidence=confidence_score,
        severity=calc_severity,
        status=calc_status,
        location=wkt_point,
        model_version=prediction["class_name"]  # Store raw class for label parsing
    )
    
    db.add(db_report)
    db.commit()
    db.refresh(db_report)

    # ── Background Task for Cloudinary Upload ──
    def _async_cloudinary_upload(report_id: int, file_data: bytes):
        if not cloudinary_configured or len(file_data) < 64:
            return
        try:
            from app.db.database import SessionLocal
            result = cloudinary.uploader.upload(file_data, timeout=20)
            secure_url = result.get("secure_url")
            if secure_url:
                db_local = SessionLocal()
                try:
                    rep = db_local.query(DiagnosisReport).filter(DiagnosisReport.id == report_id).first()
                    if rep:
                        rep.image_url = secure_url
                        db_local.commit()
                finally:
                    db_local.close()
        except Exception as e:
            logger.error(f"Cloudinary async upload failed: {e}")

    if background_tasks is not None:
        background_tasks.add_task(_async_cloudinary_upload, db_report.id, file_bytes)
    # ───────────────────────────────────────────

    # ── Outbreak Clustering & Notification ──
    if db_report.severity in [SeverityLevel.HIGH, SeverityLevel.CRITICAL] and db_report.location is not None:
        try:
            from sqlalchemy import func, cast
            from geoalchemy2.types import Geography
            from datetime import datetime, timedelta
            from app.services.notification_service import create_notification
            from app.models.notification import NotificationType

            recent_limit = datetime.utcnow() - timedelta(days=30)
            nearby_cases = db.query(DiagnosisReport).filter(
                DiagnosisReport.id != db_report.id,
                DiagnosisReport.model_version == db_report.model_version,
                DiagnosisReport.severity.in_([SeverityLevel.HIGH, SeverityLevel.CRITICAL]),
                DiagnosisReport.created_at >= recent_limit,
                DiagnosisReport.location != None,
                func.ST_DWithin(DiagnosisReport.location, cast(db_report.location, Geography), 15000)
            ).all()

            if len(nearby_cases) >= 2:
                
                nearby_farms = db.query(Farm).filter(
                    Farm.location != None,
                    func.ST_DWithin(Farm.location, cast(db_report.location, Geography), 15000)
                ).all()

                farmer_ids = {farm.owner_id for farm in nearby_farms}
                
                # Ensure the original reporters are also included just in case their farm location is null
                if db_report.crop and db_report.crop.farm:
                    farmer_ids.add(db_report.crop.farm.owner_id)
                for case in nearby_cases:
                    if case.crop and case.crop.farm:
                        farmer_ids.add(case.crop.farm.owner_id)
                
                disease_name = kb_name if kb_name else db_report.model_version
                for f_id in farmer_ids:
                    create_notification(
                        db=db,
                        user_id=f_id,
                        title=f"🚨 Outbreak Alert: {disease_name}",
                        message=f"Multiple high-severity cases of {disease_name} detected within 15km of your farm. Please inspect your crops.",
                        type=NotificationType.SYSTEM_ALERT
                    )
        except Exception as e:
            logger.error(f"Failed to process outbreak notification: {e}")

    return _enrich_diagnosis(db_report, db)

def get_diagnoses_by_crop(db: Session, crop_id: int, owner_id: int, skip: int = 0, limit: int = 100) -> List[DiagnosisReport]:
    crop = db.query(Crop).join(Farm).filter(Crop.id == crop_id, Farm.owner_id == owner_id).first()
    if not crop:
        return []
    reports = db.query(DiagnosisReport).filter(DiagnosisReport.crop_id == crop_id).offset(skip).limit(limit).all()
    return [_enrich_diagnosis(r, db) for r in reports]

def get_all_diagnoses(db: Session, owner_id: int, skip: int = 0, limit: int = 100) -> List[DiagnosisReport]:
    reports = db.query(DiagnosisReport).join(Crop).join(Farm).filter(Farm.owner_id == owner_id).order_by(DiagnosisReport.id.desc()).offset(skip).limit(limit).all()
    return [_enrich_diagnosis(r, db) for r in reports]
