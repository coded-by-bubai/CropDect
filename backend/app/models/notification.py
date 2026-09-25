import enum
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy import String, ForeignKey, Text, Boolean, Enum as SQLEnum
from app.db.base_class import Base

class NotificationType(str, enum.Enum):
    DIAGNOSIS_UPDATE = "DIAGNOSIS_UPDATE"
    LAB_RESULT = "LAB_RESULT"
    WEATHER_ALERT = "WEATHER_ALERT"
    PREDICTIVE_ALERT = "PREDICTIVE_ALERT"
    SYSTEM = "SYSTEM"

class Notification(Base):
    __tablename__ = "notifications"
    
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    reference_id: Mapped[int] = mapped_column(nullable=True, index=True)
    title: Mapped[str] = mapped_column(String(255))
    message: Mapped[str] = mapped_column(Text)
    type: Mapped[NotificationType] = mapped_column(SQLEnum(NotificationType))
    is_read: Mapped[bool] = mapped_column(Boolean, default=False)
    
    user = relationship("User")
