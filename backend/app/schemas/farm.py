from typing import Optional
from datetime import datetime
from pydantic import BaseModel, ConfigDict

class FarmBase(BaseModel):
    name: str
    area: float
    soil_type: Optional[str] = None
    latitude: Optional[float] = 0.0
    longitude: Optional[float] = 0.0

class FarmCreate(FarmBase):
    pass

class FarmUpdate(BaseModel):
    name: Optional[str] = None
    area: Optional[float] = None
    soil_type: Optional[str] = None
    latitude: Optional[float] = None
    longitude: Optional[float] = None

class FarmInDBBase(FarmBase):
    id: int
    owner_id: int
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)

class FarmResponse(FarmInDBBase):
    pass
