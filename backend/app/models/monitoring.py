import enum
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy import String, ForeignKey, Text, Enum as SQLEnum, Boolean
from app.db.base_class import Base

class HealthStatus(str, enum.Enum):
    IMPROVING = "IMPROVING"
    NO_CHANGE = "NO_CHANGE"
    WORSENING = "WORSENING"
    RESOLVED = "RESOLVED"

class MonitoringLog(Base):
    __tablename__ = "monitoring_logs"
    
    diagnosis_id: Mapped[int] = mapped_column(ForeignKey("diagnosis_reports.id", ondelete="CASCADE"), index=True)
    
    image_url: Mapped[str] = mapped_column(String(1024), nullable=True)
    notes: Mapped[str] = mapped_column(Text, nullable=True)
    health_status: Mapped[HealthStatus] = mapped_column(SQLEnum(HealthStatus))
    
    # Expert review fields
    expert_reviewed: Mapped[bool] = mapped_column(Boolean, default=False, server_default="false")
    expert_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="SET NULL"), nullable=True)
    expert_notes: Mapped[str] = mapped_column(Text, nullable=True)
    
    diagnosis = relationship("DiagnosisReport")
    expert = relationship("User", foreign_keys=[expert_id])
