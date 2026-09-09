from typing import Any, List
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session

from app.api import deps
from app.models.user import User
from app.schemas.admin import (
    AdminOverviewResponse,
    AdminFarmerItem,
    AdminFarmerDetailResponse,
    AdminExpertItem,
    AdminExpertDetailResponse,
    AdminActivityItem,
)
from app.services import admin_service, user_service

router = APIRouter()

@router.get("/overview", response_model=AdminOverviewResponse)
def get_admin_overview(
    db: Session = Depends(deps.get_db),
    current_admin: User = Depends(deps.get_current_admin),
) -> Any:
    """
    Get system-wide summary metrics for Admin oversight dashboard.
    """
    return admin_service.get_overview(db=db)

@router.get("/farmers", response_model=List[AdminFarmerItem])
def get_farmers_list(
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=500),
    db: Session = Depends(deps.get_db),
    current_admin: User = Depends(deps.get_current_admin),
) -> Any:
    """
    Get list of all registered farmers and their high-level activity metrics.
    """
    return admin_service.get_farmers(db=db, skip=skip, limit=limit)

@router.get("/farmers/{farmer_id}", response_model=AdminFarmerDetailResponse)
def get_farmer_detail(
    farmer_id: int,
    db: Session = Depends(deps.get_db),
    current_admin: User = Depends(deps.get_current_admin),
) -> Any:
    """
    Get specific farmer's profile, registered farms, and complete scan history.
    """
    detail = admin_service.get_farmer_detail(db=db, farmer_id=farmer_id)
    if not detail:
        raise HTTPException(status_code=404, detail="Farmer not found")
    return detail

@router.get("/experts", response_model=List[AdminExpertItem])
def get_experts_list(
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=500),
    db: Session = Depends(deps.get_db),
    current_admin: User = Depends(deps.get_current_admin),
) -> Any:
    """
    Get list of all agricultural experts and their review metrics.
    """
    return admin_service.get_experts(db=db, skip=skip, limit=limit)

@router.get("/experts/{expert_id}", response_model=AdminExpertDetailResponse)
def get_expert_detail(
    expert_id: int,
    db: Session = Depends(deps.get_db),
    current_admin: User = Depends(deps.get_current_admin),
) -> Any:
    """
    Get specific expert's profile and validation review history.
    """
    detail = admin_service.get_expert_detail(db=db, expert_id=expert_id)
    if not detail:
        raise HTTPException(status_code=404, detail="Expert not found")
    return detail

@router.get("/activity-log", response_model=List[AdminActivityItem])
def get_activity_log(
    limit: int = Query(50, ge=1, le=100),
    db: Session = Depends(deps.get_db),
    current_admin: User = Depends(deps.get_current_admin),
) -> Any:
    """
    Get live audit feed of all system activities (farmer scans, expert reviews).
    """
    return admin_service.get_activity_log(db=db, limit=limit)

@router.delete("/users/{user_id}", response_model=dict)
def delete_user(
    user_id: int,
    db: Session = Depends(deps.get_db),
    current_admin: User = Depends(deps.get_current_admin),
) -> Any:
    """
    Delete any user (farmer or expert) by ID. This cascades and deletes all associated assets.
    """
    user = user_service.get_user(db=db, user_id=user_id)
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    
    # Optional: Prevent admins from deleting themselves via this endpoint
    if user.id == current_admin.id:
        raise HTTPException(status_code=400, detail="Cannot delete your own admin account through this endpoint")

    user_service.delete_user(db=db, db_obj=user)
    return {"message": "User and all associated assets deleted successfully"}
