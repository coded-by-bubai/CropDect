from typing import Any
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from app.api import deps
from app.schemas.analytics import DashboardStats, DiseaseDistribution
from app.services import analytics_service
from app.models.user import User, UserRole

router = APIRouter()

def get_agri_officer(current_user: User = Depends(deps.get_current_active_user)) -> User:
    if current_user.role not in [UserRole.ADMIN, UserRole.EXPERT, UserRole.EXTENSION_WORKER]:
        raise HTTPException(status_code=403, detail="The user doesn't have enough privileges")
    return current_user

@router.get("/stats", response_model=DashboardStats)
def get_dashboard_stats(
    db: Session = Depends(deps.get_db),
    current_user: User = Depends(get_agri_officer)
) -> Any:
    """
    Get macro-level dashboard stats. Only for Agri Officers.
    """
    return analytics_service.get_dashboard_stats(db=db)

@router.get("/distribution", response_model=DiseaseDistribution)
def get_disease_distribution(
    db: Session = Depends(deps.get_db),
    current_user: User = Depends(get_agri_officer)
) -> Any:
    """
    Get top 10 most frequent diseases for the region. Only for Agri Officers.
    """
    return analytics_service.get_disease_distribution(db=db)
