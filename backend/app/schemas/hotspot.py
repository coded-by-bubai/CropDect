from pydantic import BaseModel
from typing import List, Optional
from datetime import datetime

class OutbreakCluster(BaseModel):
    latitude: float
    longitude: float
    disease_name: str
    case_count: int
    radius_km: float

class HotspotLocation(BaseModel):
    latitude: float
    longitude: float
    severity: str
    timestamp: datetime
    disease_name: Optional[str] = None
    crop_name: Optional[str] = None
    diagnosis_id: Optional[int] = None

class HotspotResponse(BaseModel):
    disease_name: Optional[str] = None
    hotspots: List[HotspotLocation]
    clusters: List[OutbreakCluster] = []
