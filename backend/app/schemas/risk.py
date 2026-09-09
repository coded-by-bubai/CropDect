from pydantic import BaseModel
from typing import List

class ThreatProfile(BaseModel):
    disease_name: str
    risk_percentage: int
    reason: str

class RiskAssessmentResponse(BaseModel):
    farm_id: int
    overall_health_score: int
    threats: List[ThreatProfile]
