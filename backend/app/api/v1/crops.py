from typing import Any, List
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from app.api import deps
from app.schemas.crop import CropCreate, CropUpdate, CropResponse
from app.services import crop_service, farm_service
from app.models.user import User

router = APIRouter()

@router.get("/", response_model=List[CropResponse])
def read_crops(
    farm_id: int,
    db: Session = Depends(deps.get_db),
    skip: int = 0,
    limit: int = 100,
    current_user: User = Depends(deps.get_current_active_user),
) -> Any:
    return crop_service.get_crops_by_farm(
        db=db, farm_id=farm_id, owner_id=current_user.id, skip=skip, limit=limit
    )

@router.post("/", response_model=CropResponse)
def create_crop(
    *,
    db: Session = Depends(deps.get_db),
    crop_in: CropCreate,
    current_user: User = Depends(deps.get_current_active_user),
) -> Any:
    farm = farm_service.get_farm(db=db, farm_id=crop_in.farm_id, owner_id=current_user.id)
    if not farm:
        raise HTTPException(status_code=404, detail="Farm not found or not owned by user")
    return crop_service.create_crop(db=db, crop_in=crop_in)

@router.get("/{crop_id}", response_model=CropResponse)
def read_crop(
    *,
    db: Session = Depends(deps.get_db),
    crop_id: int,
    current_user: User = Depends(deps.get_current_active_user),
) -> Any:
    crop = crop_service.get_crop(db=db, crop_id=crop_id, owner_id=current_user.id)
    if not crop:
        raise HTTPException(status_code=404, detail="Crop not found")
    return crop

@router.put("/{crop_id}", response_model=CropResponse)
def update_crop(
    *,
    db: Session = Depends(deps.get_db),
    crop_id: int,
    crop_in: CropUpdate,
    current_user: User = Depends(deps.get_current_active_user),
) -> Any:
    crop = crop_service.get_crop(db=db, crop_id=crop_id, owner_id=current_user.id)
    if not crop:
        raise HTTPException(status_code=404, detail="Crop not found")
    return crop_service.update_crop(db=db, db_crop=crop, crop_in=crop_in)

@router.delete("/{crop_id}", response_model=CropResponse)
def delete_crop(
    *,
    db: Session = Depends(deps.get_db),
    crop_id: int,
    current_user: User = Depends(deps.get_current_active_user),
) -> Any:
    crop = crop_service.get_crop(db=db, crop_id=crop_id, owner_id=current_user.id)
    if not crop:
        raise HTTPException(status_code=404, detail="Crop not found")
    return crop_service.delete_crop(db=db, db_crop=crop)
