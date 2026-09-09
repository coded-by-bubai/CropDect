from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy import String, Float, ForeignKey
from geoalchemy2 import Geography
from app.db.base_class import Base

class Farm(Base):
    __tablename__ = "farms"
    
    owner_id: Mapped[int] = mapped_column(ForeignKey("users.id"), index=True)
    name: Mapped[str] = mapped_column(String(255))
    area: Mapped[float] = mapped_column(Float)
    soil_type: Mapped[str] = mapped_column(String(100), nullable=True)
    location = mapped_column(Geography(geometry_type='POINT', srid=4326, spatial_index=False))
    
    owner = relationship("User", back_populates="farms")
    crops = relationship("Crop", back_populates="farm", cascade="all, delete-orphan")
