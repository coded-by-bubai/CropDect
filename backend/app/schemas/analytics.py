from pydantic import BaseModel
from typing import List

class DashboardStats(BaseModel):
    total_farms_registered: int
    total_diagnoses_processed: int
    active_unresolved_issues: int

class DiseaseCount(BaseModel):
    disease_name: str
    count: int

class DiseaseDistribution(BaseModel):
    distribution: List[DiseaseCount]
