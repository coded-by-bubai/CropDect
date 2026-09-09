from typing import Any, List
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from app.api import deps
from app.schemas.lab_referral import LabReferralCreate, LabReferralUpdate, LabReferralResponse
from app.services import lab_service
from app.models.user import User, UserRole

router = APIRouter()

def get_expert_user(current_user: User = Depends(deps.get_current_active_user)) -> User:
    if current_user.role not in [UserRole.EXPERT, UserRole.ADMIN, UserRole.EXTENSION_WORKER]:
        raise HTTPException(status_code=403, detail="The user doesn't have enough privileges")
    return current_user

@router.get("/referrals", response_model=List[LabReferralResponse])
def get_referrals(
    skip: int = 0,
    limit: int = 100,
    db: Session = Depends(deps.get_db),
    current_user: User = Depends(get_expert_user)
) -> Any:
    """
    Get all lab referrals.
    """
    return lab_service.get_referrals(db=db, skip=skip, limit=limit)

@router.post("/referrals", response_model=LabReferralResponse)
def create_referral(
    referral_in: LabReferralCreate,
    db: Session = Depends(deps.get_db),
    current_user: User = Depends(get_expert_user)
) -> Any:
    """
    Create a new lab referral for a diagnosis.
    """
    return lab_service.create_referral(db=db, expert_id=current_user.id, referral_in=referral_in)

@router.put("/referrals/{referral_id}", response_model=LabReferralResponse)
def update_referral(
    referral_id: int,
    referral_in: LabReferralUpdate,
    db: Session = Depends(deps.get_db),
    current_user: User = Depends(get_expert_user)
) -> Any:
    """
    Update a lab referral (e.g. tracking number, status).
    """
    return lab_service.update_referral(db=db, referral_id=referral_id, update_in=referral_in)
