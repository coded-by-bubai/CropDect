from typing import Any, List, Optional
from fastapi import APIRouter, Depends, UploadFile, File, Form
from sqlalchemy.orm import Session
from app.api import deps
from app.schemas.monitoring import MonitoringLogResponse, MonitoringLogCreate
from app.models.monitoring import HealthStatus
from app.services import monitoring_service
from app.models.user import User

router = APIRouter()

@router.get("/{diagnosis_id}/logs", response_model=List[MonitoringLogResponse])
def get_monitoring_logs(
    diagnosis_id: int,
    db: Session = Depends(deps.get_db),
    current_user: User = Depends(deps.get_current_active_user)
) -> Any:
    """
    Get all monitoring logs for a specific diagnosis.
    Experts can view any diagnosis logs; farmers only their own.
    """
    if current_user.role.value in ("EXPERT", "ADMIN"):
        return monitoring_service.get_monitoring_logs_for_expert(db=db, diagnosis_id=diagnosis_id)
    return monitoring_service.get_monitoring_logs(db=db, diagnosis_id=diagnosis_id, owner_id=current_user.id)

from fastapi import APIRouter, Depends, UploadFile, File, Form, BackgroundTasks

@router.post("/{diagnosis_id}/logs", response_model=MonitoringLogResponse)
def add_monitoring_log(
    diagnosis_id: int,
    background_tasks: BackgroundTasks,
    health_status: HealthStatus = Form(...),
    notes: Optional[str] = Form(None),
    file: Optional[UploadFile] = File(None),
    db: Session = Depends(deps.get_db),
    current_user: User = Depends(deps.get_current_active_user)
) -> Any:
    """
    Add a new monitoring log for a diagnosis.
    Allows optional image upload (uploaded asynchronously to Cloudinary) and notes.
    """
    log_in = MonitoringLogCreate(notes=notes, health_status=health_status)
    
    file_bytes = None
    if file:
        file_bytes = file.file.read()

    return monitoring_service.add_monitoring_log(
        db=db, 
        diagnosis_id=diagnosis_id, 
        owner_id=current_user.id, 
        log_in=log_in, 
        file_bytes=file_bytes,
        background_tasks=background_tasks
    )

@router.post("/logs/{log_id}/expert-review", response_model=MonitoringLogResponse)
def expert_review_monitoring_log(
    log_id: int,
    expert_notes: str = Form(...),
    db: Session = Depends(deps.get_db),
    current_user: User = Depends(deps.get_current_active_user)
) -> Any:
    """
    Expert reviews a monitoring log and adds notes/recommendations.
    """
    if current_user.role.value not in ("EXPERT", "ADMIN"):
        from fastapi import HTTPException
        raise HTTPException(status_code=403, detail="Only experts can review monitoring logs")
    
    return monitoring_service.expert_review_log(
        db=db,
        log_id=log_id,
        expert_id=current_user.id,
        expert_notes=expert_notes
    )
