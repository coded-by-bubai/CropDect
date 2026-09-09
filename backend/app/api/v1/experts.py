from typing import Any, List
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from app.api import deps
from app.schemas.expert import ExpertValidationCreate, ExpertValidationResponse
from app.schemas.diagnosis import DiagnosisResponse
from app.services import expert_service
from app.models.user import User, UserRole

router = APIRouter()

def get_expert_user(current_user: User = Depends(deps.get_current_active_user)) -> User:
    if current_user.role not in [UserRole.EXPERT, UserRole.ADMIN, UserRole.EXTENSION_WORKER]:
        raise HTTPException(status_code=403, detail="The user doesn't have enough privileges")
    return current_user

@router.get("/pending-reviews", response_model=List[DiagnosisResponse])
def get_pending_reviews(
    skip: int = 0,
    limit: int = 100,
    db: Session = Depends(deps.get_db),
    current_user: User = Depends(get_expert_user)
) -> Any:
    """
    Get all diagnoses requiring expert review.
    """
    return expert_service.get_pending_reviews(db=db, skip=skip, limit=limit)

@router.get("/follow-ups", response_model=List[DiagnosisResponse])
def get_follow_ups(
    skip: int = 0,
    limit: int = 100,
    db: Session = Depends(deps.get_db),
    current_user: User = Depends(get_expert_user)
) -> Any:
    """
    Get all active diagnoses that have follow-up monitoring logs.
    """
    return expert_service.get_follow_ups(db=db, skip=skip, limit=limit)

@router.get("/completed-cases", response_model=List[DiagnosisResponse])
def get_completed_cases(
    skip: int = 0,
    limit: int = 100,
    db: Session = Depends(deps.get_db),
    current_user: User = Depends(get_expert_user)
) -> Any:
    """
    Get all diagnoses that this expert has reviewed (CONFIRMED or CORRECTED).
    """
    return expert_service.get_completed_cases(db=db, expert_id=current_user.id, skip=skip, limit=limit)

@router.post("/validations", response_model=ExpertValidationResponse)
def submit_validation(
    validation_in: ExpertValidationCreate,
    db: Session = Depends(deps.get_db),
    current_user: User = Depends(get_expert_user)
) -> Any:
    """
    Submit an expert validation for a diagnosis.
    """
    return expert_service.submit_validation(db=db, expert_id=current_user.id, validation_in=validation_in)
