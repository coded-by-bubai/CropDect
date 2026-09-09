from typing import Optional
from datetime import datetime
from pydantic import BaseModel, ConfigDict
from app.models.diagnosis import DiagnosisType, DiagnosisStatus, SeverityLevel

class DiagnosisBase(BaseModel):
    crop_id: int
    image_url: str
    diagnosis_type: DiagnosisType
    confidence: float
    severity: SeverityLevel
    status: DiagnosisStatus
    model_version: Optional[str] = None
    
    # We omit location here since it's Geography and requires special handling
    disease_id: Optional[int] = None
    pest_id: Optional[int] = None

class DiagnosisCreate(DiagnosisBase):
    pass

class DiagnosisInDBBase(DiagnosisBase):
    id: int
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    created_at: datetime
    updated_at: datetime
    # Human-readable fields added by the service layer
    label: Optional[str] = None      # e.g. "Early Blight"
    crop_name: Optional[str] = None  # e.g. "Tomato"
    expert_notes: Optional[str] = None
    expert_name: Optional[str] = None
    is_correct: Optional[bool] = None

    model_config = ConfigDict(from_attributes=True)

class DiagnosisResponse(DiagnosisInDBBase):
    pass

