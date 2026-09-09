from sqlalchemy.orm import Session
from sqlalchemy import func
from app.models.farm import Farm
from app.models.diagnosis import DiagnosisReport, DiagnosisStatus, DiagnosisType
from app.models.knowledge_base import KnowledgeBase
from app.schemas.analytics import DashboardStats, DiseaseDistribution, DiseaseCount

def get_dashboard_stats(db: Session) -> DashboardStats:
    total_farms = db.query(func.count(Farm.id)).scalar() or 0
    total_diagnoses = db.query(func.count(DiagnosisReport.id)).scalar() or 0
    
    # Active issues are ones not resolved or rejected
    active_issues = db.query(func.count(DiagnosisReport.id)).filter(
        DiagnosisReport.status.notin_([DiagnosisStatus.RESOLVED, DiagnosisStatus.REJECTED])
    ).scalar() or 0
    
    return DashboardStats(
        total_farms_registered=total_farms,
        total_diagnoses_processed=total_diagnoses,
        active_unresolved_issues=active_issues
    )

def get_disease_distribution(db: Session) -> DiseaseDistribution:
    # We want to group by disease name and count
    # Let's count where diagnosis_type == DISEASE and disease_id is not null
    results = db.query(
        KnowledgeBase.name,
        func.count(DiagnosisReport.id).label('count')
    ).join(
        DiagnosisReport,
        DiagnosisReport.disease_id == KnowledgeBase.id
    ).filter(
        DiagnosisReport.diagnosis_type == DiagnosisType.DISEASE
    ).group_by(
        KnowledgeBase.name
    ).order_by(
        func.count(DiagnosisReport.id).desc()
    ).limit(10).all()
    
    distribution = [DiseaseCount(disease_name=row.name, count=row.count) for row in results]
    
    return DiseaseDistribution(distribution=distribution)
