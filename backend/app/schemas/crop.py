from typing import Optional
from datetime import date, datetime
from pydantic import BaseModel, ConfigDict
from app.models.crop import CropStatus

class CropBase(BaseModel):
    crop_type: str
    variety: Optional[str] = None
    sowing_date: Optional[date] = None
    expected_harvest_date: Optional[date] = None
    growth_stage: Optional[str] = None
    season: Optional[str] = None

class CropCreate(CropBase):
    farm_id: int

class CropUpdate(BaseModel):
    crop_type: Optional[str] = None
    variety: Optional[str] = None
    sowing_date: Optional[date] = None
    expected_harvest_date: Optional[date] = None
    growth_stage: Optional[str] = None
    season: Optional[str] = None
    status: Optional[CropStatus] = None

class CropInDBBase(CropBase):
    id: int
    farm_id: int
    status: CropStatus
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)

class CropResponse(CropInDBBase):
    pass
