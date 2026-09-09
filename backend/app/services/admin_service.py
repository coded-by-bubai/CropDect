from typing import List, Optional
from datetime import datetime
from sqlalchemy.orm import Session
from sqlalchemy import desc, func, cast
from geoalchemy2.types import Geometry
from geoalchemy2.functions import ST_X, ST_Y
from collections import defaultdict
import numpy as np
from sklearn.cluster import DBSCAN
from math import radians

from app.models.user import User, UserRole
from app.models.farm import Farm
from app.models.crop import Crop
from app.models.diagnosis import DiagnosisReport, DiagnosisStatus, SeverityLevel
from app.models.expert_validation import ExpertValidation
from app.models.lab_referral import LabReferral
from app.services.diagnosis_service import _parse_class_name
from app.schemas.admin import (
    AdminOverviewResponse,
    AdminFarmerItem,
    AdminFarmerDetailResponse,
    AdminFarmDetail,
    AdminCropSummary,
    AdminFarmerScanDetail,
    AdminExpertItem,
    AdminExpertDetailResponse,
    AdminExpertValidationDetail,
    AdminActivityItem,
)

def get_overview(db: Session) -> AdminOverviewResponse:
    total_farmers = db.query(User).filter(User.role == UserRole.FARMER).count()
    # Count experts + legacy extension workers
    total_experts = db.query(User).filter(
        (User.role == UserRole.EXPERT) | (User.role == UserRole.EXTENSION_WORKER)
    ).count()
    total_admins = db.query(User).filter(User.role == UserRole.ADMIN).count()
    total_farms = db.query(Farm).count()
    total_scans = db.query(DiagnosisReport).count()
    pending_reviews = db.query(DiagnosisReport).filter(
        DiagnosisReport.status == DiagnosisStatus.EXPERT_REVIEW
    ).count()
    completed_reviews = db.query(ExpertValidation).count()
    lab_referrals = db.query(LabReferral).count()
    # Retrieve valid spatial reports for high/critical severity
    outbreak_reports = db.query(
        DiagnosisReport.model_version,
        ST_Y(cast(DiagnosisReport.location, Geometry)).label("lat"),
        ST_X(cast(DiagnosisReport.location, Geometry)).label("lng")
    ).filter(
        DiagnosisReport.severity.in_([SeverityLevel.HIGH, SeverityLevel.CRITICAL]),
        DiagnosisReport.location != None
    ).all()

    disease_groups = defaultdict(list)
    for report in outbreak_reports:
        disease = report.model_version or 'UNKNOWN'
        if report.lat is not None and report.lng is not None:
            disease_groups[disease].append([radians(report.lat), radians(report.lng)])

    active_outbreaks = 0
    kms_per_radian = 6371.0088
    eps = 15.0 / kms_per_radian  # 15km radius

    for disease, coords in disease_groups.items():
        if len(coords) < 3:
            continue
        
        X = np.array(coords)
        dbscan = DBSCAN(eps=eps, min_samples=3, algorithm='ball_tree', metric='haversine')
        labels = dbscan.fit_predict(X)
        
        num_clusters = len(set(labels)) - (1 if -1 in labels else 0)
        active_outbreaks += num_clusters

    return AdminOverviewResponse(
        total_farmers=total_farmers,
        total_experts=total_experts,
        total_admins=total_admins,
        total_farms=total_farms,
        total_scans=total_scans,
        pending_reviews=pending_reviews,
        completed_reviews=completed_reviews,
        lab_referrals=lab_referrals,
        active_outbreaks=active_outbreaks,
    )

def get_farmers(db: Session, skip: int = 0, limit: int = 100) -> List[AdminFarmerItem]:
    farmers = (
        db.query(User)
        .filter(User.role == UserRole.FARMER)
        .order_by(desc(User.created_at))
        .offset(skip)
        .limit(limit)
        .all()
    )

    result: List[AdminFarmerItem] = []
    for f in farmers:
        farms = db.query(Farm).filter(Farm.owner_id == f.id).all()
        farm_ids = [farm.id for farm in farms]
        
        scan_count = 0
        last_scan_date = None
        last_disease = None
        last_severity = None

        if farm_ids:
            # Query diagnoses across crops of these farms
            crops = db.query(Crop).filter(Crop.farm_id.in_(farm_ids)).all()
            crop_ids = [c.id for c in crops]
            if crop_ids:
                scan_count = db.query(DiagnosisReport).filter(DiagnosisReport.crop_id.in_(crop_ids)).count()
                last_report = (
                    db.query(DiagnosisReport)
                    .filter(DiagnosisReport.crop_id.in_(crop_ids))
                    .order_by(desc(DiagnosisReport.created_at))
                    .first()
                )
                if last_report:
                    last_scan_date = last_report.created_at
                    last_severity = last_report.severity.value if last_report.severity else None
                    if last_report.model_version:
                        parsed = _parse_class_name(last_report.model_version)
                        last_disease = parsed["label"]
                    else:
                        last_disease = last_report.diagnosis_type.value

        result.append(
            AdminFarmerItem(
                id=f.id,
                name=f.name or "Farmer #" + str(f.id),
                phone=f.phone,
                email=f.email,
                created_at=f.created_at,
                farm_count=len(farms),
                scan_count=scan_count,
                last_scan_date=last_scan_date,
                last_disease=last_disease,
                last_severity=last_severity,
            )
        )
    return result

def get_farmer_detail(db: Session, farmer_id: int) -> AdminFarmerDetailResponse:
    farmer = db.query(User).filter(User.id == farmer_id).first()
    if not farmer:
        return None

    farms_orm = db.query(Farm).filter(Farm.owner_id == farmer_id).all()
    farms_list: List[AdminFarmDetail] = []
    all_crop_ids = []

    for farm in farms_orm:
        crops_orm = db.query(Crop).filter(Crop.farm_id == farm.id).all()
        crops_summary = [
            AdminCropSummary(
                id=c.id,
                crop_type=c.crop_type,
                variety=c.variety,
                sowing_date=c.sowing_date,
            )
            for c in crops_orm
        ]
        all_crop_ids.extend([c.id for c in crops_orm])
        farms_list.append(
            AdminFarmDetail(
                id=farm.id,
                name=farm.name,
                area=farm.area,
                soil_type=farm.soil_type,
                crops=crops_summary,
            )
        )

    scans_list: List[AdminFarmerScanDetail] = []
    if all_crop_ids:
        reports = (
            db.query(DiagnosisReport)
            .filter(DiagnosisReport.crop_id.in_(all_crop_ids))
            .order_by(desc(DiagnosisReport.created_at))
            .all()
        )
        for r in reports:
            crop_name = "Crop"
            label = "Unknown"
            if r.model_version:
                parsed = _parse_class_name(r.model_version)
                crop_name = parsed["crop_name"]
                label = parsed["label"]
            elif r.crop:
                crop_name = r.crop.crop_type

            scans_list.append(
                AdminFarmerScanDetail(
                    id=r.id,
                    crop_name=crop_name,
                    label=label,
                    diagnosis_type=r.diagnosis_type.value,
                    confidence=r.confidence,
                    severity=r.severity.value if r.severity else "MODERATE",
                    status=r.status.value,
                    image_url=r.image_url,
                    created_at=r.created_at,
                )
            )

    farmer_item = AdminFarmerItem(
        id=farmer.id,
        name=farmer.name or f"Farmer #{farmer.id}",
        phone=farmer.phone,
        email=farmer.email,
        created_at=farmer.created_at,
        farm_count=len(farms_list),
        scan_count=len(scans_list),
        last_scan_date=scans_list[0].created_at if scans_list else None,
        last_disease=scans_list[0].label if scans_list else None,
        last_severity=scans_list[0].severity if scans_list else None,
    )

    return AdminFarmerDetailResponse(
        farmer=farmer_item,
        farms=farms_list,
        scans=scans_list,
    )

def get_experts(db: Session, skip: int = 0, limit: int = 100) -> List[AdminExpertItem]:
    experts = (
        db.query(User)
        .filter((User.role == UserRole.EXPERT) | (User.role == UserRole.EXTENSION_WORKER))
        .order_by(desc(User.created_at))
        .offset(skip)
        .limit(limit)
        .all()
    )

    result: List[AdminExpertItem] = []
    for exp in experts:
        validations = (
            db.query(ExpertValidation)
            .filter(ExpertValidation.expert_id == exp.id)
            .order_by(desc(ExpertValidation.created_at))
            .all()
        )
        reviews_completed = len(validations)
        last_review_date = validations[0].created_at if validations else None

        result.append(
            AdminExpertItem(
                id=exp.id,
                name=exp.name or f"Agronomist #{exp.id}",
                phone=exp.phone,
                email=exp.email,
                created_at=exp.created_at,
                reviews_completed=reviews_completed,
                last_review_date=last_review_date,
            )
        )
    return result

def get_expert_detail(db: Session, expert_id: int) -> AdminExpertDetailResponse:
    expert = db.query(User).filter(User.id == expert_id).first()
    if not expert:
        return None

    validations_orm = (
        db.query(ExpertValidation)
        .filter(ExpertValidation.expert_id == expert_id)
        .order_by(desc(ExpertValidation.created_at))
        .all()
    )

    validations_list: List[AdminExpertValidationDetail] = []
    for v in validations_orm:
        crop_name = "Crop"
        disease_name = "Diagnosis Review"
        if v.diagnosis:
            if v.diagnosis.model_version:
                parsed = _parse_class_name(v.diagnosis.model_version)
                crop_name = parsed["crop_name"]
                disease_name = parsed["label"]
            elif v.diagnosis.crop:
                crop_name = v.diagnosis.crop.crop_type

        validations_list.append(
            AdminExpertValidationDetail(
                id=v.id,
                diagnosis_id=v.diagnosis_id,
                crop_name=crop_name,
                disease_name=disease_name,
                is_correct=v.is_correct,
                expert_notes=v.expert_notes,
                created_at=v.created_at,
            )
        )

    expert_item = AdminExpertItem(
        id=expert.id,
        name=expert.name or f"Expert #{expert.id}",
        phone=expert.phone,
        email=expert.email,
        created_at=expert.created_at,
        reviews_completed=len(validations_list),
        last_review_date=validations_list[0].created_at if validations_list else None,
    )

    return AdminExpertDetailResponse(
        expert=expert_item,
        validations=validations_list,
    )

def get_activity_log(db: Session, limit: int = 50) -> List[AdminActivityItem]:
    """
    Combined feed of recent scans, expert validations, and lab referrals.
    """
    activities: List[AdminActivityItem] = []

    # 1. Recent scans
    scans = (
        db.query(DiagnosisReport)
        .order_by(desc(DiagnosisReport.updated_at))
        .limit(limit)
        .all()
    )
    for s in scans:
        crop_name = "Crop"
        label = "Scan Analyzed"
        if s.model_version:
            parsed = _parse_class_name(s.model_version)
            crop_name = parsed["crop_name"]
            label = parsed["label"]
        
        farmer_name = None
        if s.crop and s.crop.farm and s.crop.farm.owner:
            farmer_name = s.crop.farm.owner.name

        is_review_requested = s.status.value == "EXPERT_REVIEW"
        title = f"Review Requested: {label}" if is_review_requested else f"AI Scan: {label}"

        activities.append(
            AdminActivityItem(
                id=s.id,
                type="SCAN",
                title=title,
                description=f"Field crop ({crop_name}) scanned with {int(s.confidence * 100)}% confidence.",
                user_name=farmer_name or "Farmer",
                user_role="FARMER",
                timestamp=s.updated_at or s.created_at,
                severity=s.severity.value if s.severity else "MODERATE",
                status=s.status.value,
                image_url=s.image_url,
            )
        )

    # 2. Recent validations
    validations = (
        db.query(ExpertValidation)
        .order_by(desc(ExpertValidation.updated_at))
        .limit(limit)
        .all()
    )
    for v in validations:
        expert_name = v.expert.name if v.expert else "Expert"
        outcome = "Confirmed Diagnosis" if v.is_correct else "Corrected Diagnosis"
        note = v.expert_notes or "Review approved."
        activities.append(
            AdminActivityItem(
                id=v.id,
                type="REVIEW",
                title=f"Expert Review: {outcome}",
                description=f"Notes: {note}",
                user_name=expert_name,
                user_role="EXPERT",
                timestamp=v.updated_at or v.created_at,
                status="CONFIRMED" if v.is_correct else "CORRECTED",
            )
        )

    # 3. Lab Referrals
    from app.models.lab_referral import LabReferral
    labs = (
        db.query(LabReferral)
        .order_by(desc(LabReferral.updated_at))
        .limit(limit)
        .all()
    )
    for l in labs:
        activities.append(
            AdminActivityItem(
                id=l.id,
                type="LAB",
                title=f"Lab Update: {l.lab_name}",
                description=f"Status: {l.status.value}. Tracking: {l.tracking_number or 'None'}",
                user_name="System / Lab",
                user_role="LAB",
                timestamp=l.updated_at,
                status=l.status.value,
            )
        )

    # Sort all by timestamp descending
    activities.sort(key=lambda x: x.timestamp, reverse=True)
    return activities[:limit]
