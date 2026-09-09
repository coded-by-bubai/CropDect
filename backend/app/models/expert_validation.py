from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy import String, ForeignKey, Boolean, Text
from app.db.base_class import Base

class ExpertValidation(Base):
    __tablename__ = "expert_validations"
    
    diagnosis_id: Mapped[int] = mapped_column(ForeignKey("diagnosis_reports.id", ondelete="CASCADE"), index=True)
    expert_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    
    is_correct: Mapped[bool] = mapped_column(Boolean, default=True)
    corrected_disease_id: Mapped[int] = mapped_column(ForeignKey("knowledge_base.id"), nullable=True)
    corrected_pest_id: Mapped[int] = mapped_column(ForeignKey("knowledge_base.id"), nullable=True)
    
    expert_notes: Mapped[str] = mapped_column(Text, nullable=True)
    
    diagnosis = relationship("DiagnosisReport")
    expert = relationship("User")
