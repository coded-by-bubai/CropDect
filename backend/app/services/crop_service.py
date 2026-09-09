from typing import List, Optional
from sqlalchemy.orm import Session
from app.models.crop import Crop
from app.models.farm import Farm
from app.schemas.crop import CropCreate, CropUpdate

def get_crop(db: Session, crop_id: int, owner_id: int) -> Optional[Crop]:
    # Ensure crop belongs to a farm owned by owner_id
    return db.query(Crop).join(Farm).filter(
        Crop.id == crop_id, 
        Farm.owner_id == owner_id
    ).first()

def get_crops_by_farm(db: Session, farm_id: int, owner_id: int, skip: int = 0, limit: int = 100) -> List[Crop]:
    # Check if user owns farm
    farm = db.query(Farm).filter(Farm.id == farm_id, Farm.owner_id == owner_id).first()
    if not farm:
        return []
    return db.query(Crop).filter(Crop.farm_id == farm_id).offset(skip).limit(limit).all()

def create_crop(db: Session, crop_in: CropCreate) -> Crop:
    db_crop = Crop(**crop_in.model_dump())
    db.add(db_crop)
    db.commit()
    db.refresh(db_crop)
    return db_crop

def update_crop(db: Session, db_crop: Crop, crop_in: CropUpdate) -> Crop:
    update_data = crop_in.model_dump(exclude_unset=True)
    for field, value in update_data.items():
        setattr(db_crop, field, value)
    db.commit()
    db.refresh(db_crop)
    return db_crop

def delete_crop(db: Session, db_crop: Crop) -> Crop:
    db.delete(db_crop)
    db.commit()
    return db_crop
