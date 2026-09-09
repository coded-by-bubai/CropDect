from pydantic import BaseModel
from typing import Optional
from datetime import datetime

class ExpertValidationCreate(BaseModel):
    diagnosis_id: int
    is_correct: bool
    corrected_disease_id: Optional[int] = None
    corrected_pest_id: Optional[int] = None
    expert_notes: Optional[str] = None

class ExpertValidationResponse(BaseModel):
    id: int
    diagnosis_id: int
    expert_id: int
    is_correct: bool
    corrected_disease_id: Optional[int] = None
    corrected_pest_id: Optional[int] = None
    expert_notes: Optional[str] = None
    created_at: datetime
    
    class Config:
        from_attributes = True
