import enum
from datetime import date
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy import String, Date, ForeignKey, Enum as SQLEnum
from app.db.base_class import Base

class CropStatus(str, enum.Enum):
    ACTIVE = "ACTIVE"
    HARVESTED = "HARVESTED"
    FAILED = "FAILED"

class Crop(Base):
    __tablename__ = "crops"
    
    farm_id: Mapped[int] = mapped_column(ForeignKey("farms.id"), index=True)
    crop_type: Mapped[str] = mapped_column(String(100))
    variety: Mapped[str] = mapped_column(String(100), nullable=True)
    sowing_date: Mapped[date] = mapped_column(Date, nullable=True)
    expected_harvest_date: Mapped[date] = mapped_column(Date, nullable=True)
    growth_stage: Mapped[str] = mapped_column(String(100), nullable=True)
    season: Mapped[str] = mapped_column(String(50), nullable=True)
    status: Mapped[CropStatus] = mapped_column(SQLEnum(CropStatus), default=CropStatus.ACTIVE)
    
    farm = relationship("Farm", back_populates="crops")
    diagnosis_reports = relationship("DiagnosisReport", back_populates="crop", cascade="all, delete-orphan")
