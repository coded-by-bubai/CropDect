from pydantic import BaseModel, ConfigDict
from typing import Optional
from datetime import datetime
from app.models.lab_referral import LabReferralStatus

class LabReferralBase(BaseModel):
    lab_name: str
    tracking_number: Optional[str] = None
    status: LabReferralStatus = LabReferralStatus.PENDING
    results_summary: Optional[str] = None

class LabReferralCreate(LabReferralBase):
    diagnosis_id: int

class LabReferralUpdate(BaseModel):
    tracking_number: Optional[str] = None
    status: Optional[LabReferralStatus] = None
    results_summary: Optional[str] = None

class LabReferralResponse(LabReferralBase):
    id: int
    diagnosis_id: int
    expert_id: int
    created_at: datetime
    
    model_config = ConfigDict(from_attributes=True)
