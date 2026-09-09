import enum
from sqlalchemy.orm import Mapped, mapped_column
from sqlalchemy import String, Text, Enum as SQLEnum
from app.db.base_class import Base

class IssueCategory(str, enum.Enum):
    DISEASE = "DISEASE"
    PEST = "PEST"

class KnowledgeBase(Base):
    __tablename__ = "knowledge_base"
    
    name: Mapped[str] = mapped_column(String(255), index=True)
    scientific_name: Mapped[str] = mapped_column(String(255), nullable=True)
    category: Mapped[IssueCategory] = mapped_column(SQLEnum(IssueCategory))
    
    # Comma separated list of crops, or general keywords
    affected_crops: Mapped[str] = mapped_column(String(500), nullable=True) 
    
    symptoms: Mapped[str] = mapped_column(Text)
    trigger_conditions: Mapped[str] = mapped_column(Text, nullable=True)
    
    prevention_strategies: Mapped[str] = mapped_column(Text, nullable=True)
    treatment_recommendations: Mapped[str] = mapped_column(Text, nullable=True)
    
    image_url: Mapped[str] = mapped_column(String(1024), nullable=True)
