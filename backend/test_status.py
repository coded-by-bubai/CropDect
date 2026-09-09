from app.db.database import SessionLocal
from app.models.monitoring import MonitoringLog, HealthStatus
from app.models.diagnosis import DiagnosisReport
db = SessionLocal()
log = db.query(MonitoringLog).filter(MonitoringLog.health_status == HealthStatus.RESOLVED).first()
report = db.query(DiagnosisReport).filter(DiagnosisReport.id == log.diagnosis_id).first()
print(f'Log ID: {log.id}, Diagnosis ID: {log.diagnosis_id}, Report Status: {report.status}')
