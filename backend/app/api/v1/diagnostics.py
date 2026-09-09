from typing import Any, List, Optional
from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, Form, Request, BackgroundTasks
from sqlalchemy.orm import Session
from app.core.limiter import limiter
from app.api import deps
from app.schemas.diagnosis import DiagnosisCreate, DiagnosisResponse
from app.schemas.ipm import IPMPlanResponse
from app.schemas.hotspot import HotspotResponse
from app.services import diagnosis_service, ipm_service, hotspot_service
from app.models.user import User

router = APIRouter()

@router.post("/upload", response_model=DiagnosisResponse)
@limiter.limit("10/minute")
def upload_crop_image(
    request: Request,
    background_tasks: BackgroundTasks,
    *,
    db: Session = Depends(deps.get_db),
    crop_id: int = Form(...),
    latitude: Optional[float] = Form(None),
    longitude: Optional[float] = Form(None),
    growth_stage: Optional[str] = Form(None),
    file: UploadFile = File(...),
    current_user: User = Depends(deps.get_current_active_user),
) -> Any:
    """
    Upload a crop image for diagnosis.
    Saves the image locally and creates a pending DiagnosisReport.
    """
    if not file.content_type.startswith("image/"):
        raise HTTPException(status_code=400, detail="File must be an image")
        
    return diagnosis_service.process_image_upload(
        db=db,
        owner_id=current_user.id,
        crop_id=crop_id,
        file=file,
        latitude=latitude,
        longitude=longitude,
        growth_stage=growth_stage,
        background_tasks=background_tasks
    )

@router.get("/", response_model=List[DiagnosisResponse])
def get_diagnoses(
    crop_id: int,
    db: Session = Depends(deps.get_db),
    skip: int = 0,
    limit: int = 100,
    current_user: User = Depends(deps.get_current_active_user),
) -> Any:
    """
    Get all diagnosis reports for a specific crop.
    """
    return diagnosis_service.get_diagnoses_by_crop(
        db=db, crop_id=crop_id, owner_id=current_user.id, skip=skip, limit=limit
    )

@router.get("/history", response_model=List[DiagnosisResponse])
def get_diagnosis_history(
    db: Session = Depends(deps.get_db),
    skip: int = 0,
    limit: int = 100,
    current_user: User = Depends(deps.get_current_active_user),
) -> Any:
    """
    Get all diagnosis reports for the user across all crops.
    """
    return diagnosis_service.get_all_diagnoses(
        db=db, owner_id=current_user.id, skip=skip, limit=limit
    )

@router.get("/hotspots", response_model=HotspotResponse)
def get_hotspots(
    disease_name: Optional[str] = None,
    radius_km: Optional[float] = None,
    lat: Optional[float] = None,
    lng: Optional[float] = None,
    db: Session = Depends(deps.get_db),
    current_user: User = Depends(deps.get_current_active_user)
) -> Any:
    """
    Get GIS hotspots for a specific disease.
    """
    return hotspot_service.get_disease_hotspots(
        db=db, 
        disease_name=disease_name, 
        radius_km=radius_km, 
        lat=lat, 
        lng=lng
    )

@router.get("/{diagnosis_id}/ipm-plan", response_model=IPMPlanResponse)
def get_ipm_plan(
    diagnosis_id: int,
    db: Session = Depends(deps.get_db),
    current_user: User = Depends(deps.get_current_active_user),
) -> Any:
    """
    Generate an Integrated Pest Management (IPM) plan for a specific diagnosis.
    """
    return ipm_service.generate_ipm_plan(db=db, diagnosis_id=diagnosis_id, user=current_user)

@router.post("/{diagnosis_id}/request-review", response_model=DiagnosisResponse)
def request_expert_review(
    diagnosis_id: int,
    db: Session = Depends(deps.get_db),
    current_user: User = Depends(deps.get_current_active_user),
) -> Any:
    """
    Farmer requests expert validation for their diagnosis.
    """
    from app.models.diagnosis import DiagnosisReport, DiagnosisStatus
    from app.models.crop import Crop
    from app.models.farm import Farm

    report = db.query(DiagnosisReport).join(Crop).join(Farm).filter(
        DiagnosisReport.id == diagnosis_id,
        Farm.owner_id == current_user.id
    ).first()

    if not report:
        raise HTTPException(status_code=404, detail="Diagnosis not found")

    report.status = DiagnosisStatus.EXPERT_REVIEW
    db.commit()
    db.refresh(report)
    return diagnosis_service._enrich_diagnosis(report)

@router.delete("/{diagnosis_id}", response_model=dict)
def delete_diagnosis(
    diagnosis_id: int,
    db: Session = Depends(deps.get_db),
    current_user: User = Depends(deps.get_current_active_user),
) -> Any:
    """
    Delete a specific diagnosis report.
    """
    from app.models.diagnosis import DiagnosisReport
    from app.models.crop import Crop
    from app.models.farm import Farm

    report = db.query(DiagnosisReport).join(Crop).join(Farm).filter(
        DiagnosisReport.id == diagnosis_id,
        Farm.owner_id == current_user.id
    ).first()

    if not report:
        raise HTTPException(status_code=404, detail="Diagnosis not found or you do not have permission to delete it")

    db.delete(report)
    db.commit()
    return {"message": "Diagnosis report deleted successfully"}
