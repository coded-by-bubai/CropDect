from pydantic import BaseModel, ConfigDict
from typing import Optional
from datetime import datetime
from app.models.monitoring import HealthStatus

class MonitoringLogCreate(BaseModel):
    notes: Optional[str] = None
    health_status: HealthStatus

class MonitoringLogResponse(BaseModel):
    id: int
    diagnosis_id: int
    image_url: Optional[str] = None
    notes: Optional[str] = None
    health_status: HealthStatus
    expert_reviewed: bool = False
    expert_id: Optional[int] = None
    expert_notes: Optional[str] = None
    created_at: datetime
    
    model_config = ConfigDict(from_attributes=True)
