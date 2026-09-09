from typing import List
from pydantic import BaseModel

class IPMPlanResponse(BaseModel):
    diagnosis_id: int
    disease_name: str
    severity_warning: str
    immediate_actions: List[str]
    cultural_practices: List[str]
    biological_controls: List[str]
    chemical_controls: List[str]
