from typing import Optional
from pydantic import BaseModel, ConfigDict
from app.models.knowledge_base import IssueCategory

class KBItemBase(BaseModel):
    name: str
    scientific_name: Optional[str] = None
    category: IssueCategory
    affected_crops: Optional[str] = None
    symptoms: str
    trigger_conditions: Optional[str] = None
    prevention_strategies: Optional[str] = None
    treatment_recommendations: Optional[str] = None
    image_url: Optional[str] = None

class KBItemCreate(KBItemBase):
    pass

class KBItemUpdate(BaseModel):
    name: Optional[str] = None
    scientific_name: Optional[str] = None
    category: Optional[IssueCategory] = None
    affected_crops: Optional[str] = None
    symptoms: Optional[str] = None
    trigger_conditions: Optional[str] = None
    prevention_strategies: Optional[str] = None
    treatment_recommendations: Optional[str] = None
    image_url: Optional[str] = None

class KBItemInDBBase(KBItemBase):
    id: int
    model_config = ConfigDict(from_attributes=True)

class KBItemResponse(KBItemInDBBase):
    pass
