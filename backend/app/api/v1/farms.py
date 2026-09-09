from typing import Any, List
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from app.api import deps
from app.schemas.farm import FarmCreate, FarmUpdate, FarmResponse
from app.schemas.weather import WeatherResponse
from app.schemas.risk import RiskAssessmentResponse
from app.services import farm_service
from app.services.weather_service import fetch_weather_for_farm
from app.services.risk_service import generate_risk_assessment
from app.models.user import User

router = APIRouter()

@router.get("/", response_model=List[FarmResponse])
def read_farms(
    db: Session = Depends(deps.get_db),
    skip: int = 0,
    limit: int = 100,
    current_user: User = Depends(deps.get_current_active_user),
) -> Any:
    return farm_service.get_farms(db=db, owner_id=current_user.id, skip=skip, limit=limit)

@router.post("/", response_model=FarmResponse)
def create_farm(
    *,
    db: Session = Depends(deps.get_db),
    farm_in: FarmCreate,
    current_user: User = Depends(deps.get_current_active_user),
) -> Any:
    return farm_service.create_farm(db=db, farm_in=farm_in, owner_id=current_user.id)

@router.get("/{farm_id}/weather", response_model=WeatherResponse)
def get_farm_weather(
    farm_id: int,
    db: Session = Depends(deps.get_db),
    current_user: User = Depends(deps.get_current_active_user)
) -> Any:
    """
    Get the weather forecast for a specific farm based on its GPS coordinates.
    """
    return fetch_weather_for_farm(db=db, farm_id=farm_id, owner_id=current_user.id)

@router.get("/{farm_id}/risk-assessment", response_model=RiskAssessmentResponse)
def get_farm_risk_assessment(
    farm_id: int,
    db: Session = Depends(deps.get_db),
    current_user: User = Depends(deps.get_current_active_user)
) -> Any:
    """
    Generate a proactive risk assessment for a specific farm based on crops and weather.
    """
    return generate_risk_assessment(db=db, farm_id=farm_id, owner_id=current_user.id)

@router.get("/{farm_id}", response_model=FarmResponse)
def read_farm(
    *,
    db: Session = Depends(deps.get_db),
    farm_id: int,
    current_user: User = Depends(deps.get_current_active_user),
) -> Any:
    farm = farm_service.get_farm(db=db, farm_id=farm_id, owner_id=current_user.id)
    if not farm:
        raise HTTPException(status_code=404, detail="Farm not found")
    return farm

@router.put("/{farm_id}", response_model=FarmResponse)
def update_farm(
    *,
    db: Session = Depends(deps.get_db),
    farm_id: int,
    farm_in: FarmUpdate,
    current_user: User = Depends(deps.get_current_active_user),
) -> Any:
    farm = farm_service.get_farm(db=db, farm_id=farm_id, owner_id=current_user.id)
    if not farm:
        raise HTTPException(status_code=404, detail="Farm not found")
    return farm_service.update_farm(db=db, db_farm=farm, farm_in=farm_in)

@router.delete("/{farm_id}", response_model=FarmResponse)
def delete_farm(
    *,
    db: Session = Depends(deps.get_db),
    farm_id: int,
    current_user: User = Depends(deps.get_current_active_user),
) -> Any:
    farm = farm_service.get_farm(db=db, farm_id=farm_id, owner_id=current_user.id)
    if not farm:
        raise HTTPException(status_code=404, detail="Farm not found")
    return farm_service.delete_farm(db=db, db_farm=farm)
