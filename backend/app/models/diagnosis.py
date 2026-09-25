import enum
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy import String, Float, ForeignKey, Enum as SQLEnum
from geoalchemy2 import Geography
from app.db.base_class import Base

class DiagnosisType(str, enum.Enum):
    DISEASE = "DISEASE"
    PEST = "PEST"
    HEALTHY = "HEALTHY"
    UNKNOWN = "UNKNOWN"

class DiagnosisStatus(str, enum.Enum):
    AI_PREDICTED = "AI_PREDICTED"
    EXPERT_REVIEW = "EXPERT_REVIEW"
    CONFIRMED = "CONFIRMED"
    CORRECTED = "CORRECTED"
    REJECTED = "REJECTED"
    LAB_REFERRED = "LAB_REFERRED"
    RESOLVED = "RESOLVED"

class SeverityLevel(str, enum.Enum):
    LOW = "LOW"
    MODERATE = "MODERATE"
    HIGH = "HIGH"
    CRITICAL = "CRITICAL"

class DiagnosisReport(Base):
    __tablename__ = "diagnosis_reports"
    
    crop_id: Mapped[int] = mapped_column(ForeignKey("crops.id"), index=True)
    image_url: Mapped[str] = mapped_column(String(1024))
    diagnosis_type: Mapped[DiagnosisType] = mapped_column(SQLEnum(DiagnosisType))
    
    disease_id: Mapped[int] = mapped_column(nullable=True)
    pest_id: Mapped[int] = mapped_column(nullable=True)
    
    confidence: Mapped[float] = mapped_column(Float)
    severity: Mapped[SeverityLevel] = mapped_column(SQLEnum(SeverityLevel))
    location = mapped_column(Geography(geometry_type='POINT', srid=4326, spatial_index=False), nullable=True)
    status: Mapped[DiagnosisStatus] = mapped_column(SQLEnum(DiagnosisStatus), default=DiagnosisStatus.AI_PREDICTED)
    model_version: Mapped[str] = mapped_column(String(50), nullable=True)
    infection_temp_c: Mapped[float] = mapped_column(Float, nullable=True)
    infection_humidity_percent: Mapped[float] = mapped_column(Float, nullable=True)

    crop = relationship("Crop", back_populates="diagnosis_reports")
