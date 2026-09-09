import enum
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy import String, ForeignKey, Text, Enum as SQLEnum
from app.db.base_class import Base

class LabReferralStatus(str, enum.Enum):
    PENDING = "PENDING"
    IN_TRANSIT = "IN_TRANSIT"
    RECEIVED = "RECEIVED"
    ANALYZING = "ANALYZING"
    COMPLETED = "COMPLETED"
    CANCELLED = "CANCELLED"

class LabReferral(Base):
    __tablename__ = "lab_referrals"
    
    diagnosis_id: Mapped[int] = mapped_column(ForeignKey("diagnosis_reports.id", ondelete="CASCADE"), index=True)
    expert_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    
    lab_name: Mapped[str] = mapped_column(String(255))
    tracking_number: Mapped[str] = mapped_column(String(100), nullable=True)
    
    status: Mapped[LabReferralStatus] = mapped_column(SQLEnum(LabReferralStatus), default=LabReferralStatus.PENDING)
    
    results_summary: Mapped[str] = mapped_column(Text, nullable=True)
    
    diagnosis = relationship("DiagnosisReport")
    expert = relationship("User")
