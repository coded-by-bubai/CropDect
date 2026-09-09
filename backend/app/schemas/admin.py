from typing import Optional, List
from datetime import datetime
from pydantic import BaseModel, ConfigDict

class AdminOverviewResponse(BaseModel):
    total_farmers: int
    total_experts: int
    total_admins: int
    total_farms: int
    total_scans: int
    pending_reviews: int
    completed_reviews: int
    lab_referrals: int
    active_outbreaks: int

class AdminFarmerItem(BaseModel):
    id: int
    name: Optional[str] = None
    phone: str
    email: Optional[str] = None
    created_at: datetime
    farm_count: int
    scan_count: int
    last_scan_date: Optional[datetime] = None
    last_disease: Optional[str] = None
    last_severity: Optional[str] = None

class AdminExpertItem(BaseModel):
    id: int
    name: Optional[str] = None
    phone: str
    email: Optional[str] = None
    created_at: datetime
    reviews_completed: int
    last_review_date: Optional[datetime] = None

class AdminActivityItem(BaseModel):
    id: int
    type: str # 'SCAN', 'REVIEW', 'LAB'
    title: str
    description: str
    user_name: Optional[str] = None
    user_role: str
    timestamp: datetime
    severity: Optional[str] = None
    status: Optional[str] = None
    image_url: Optional[str] = None

class AdminCropSummary(BaseModel):
    id: int
    crop_type: str
    variety: Optional[str] = None
    sowing_date: Optional[datetime] = None

class AdminFarmDetail(BaseModel):
    id: int
    name: str
    area: float
    soil_type: Optional[str] = None
    crops: List[AdminCropSummary] = []

class AdminFarmerScanDetail(BaseModel):
    id: int
    crop_name: Optional[str] = None
    label: Optional[str] = None
    diagnosis_type: str
    confidence: float
    severity: str
    status: str
    image_url: str
    created_at: datetime

class AdminFarmerDetailResponse(BaseModel):
    farmer: AdminFarmerItem
    farms: List[AdminFarmDetail] = []
    scans: List[AdminFarmerScanDetail] = []

class AdminExpertValidationDetail(BaseModel):
    id: int
    diagnosis_id: int
    crop_name: Optional[str] = None
    disease_name: Optional[str] = None
    is_correct: bool
    expert_notes: Optional[str] = None
    created_at: datetime

class AdminExpertDetailResponse(BaseModel):
    expert: AdminExpertItem
    validations: List[AdminExpertValidationDetail] = []
