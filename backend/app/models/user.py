import enum
from typing import Optional
from sqlalchemy.orm import Mapped, mapped_column, relationship
from sqlalchemy import String, Enum as SQLEnum
from app.db.base_class import Base

class UserRole(str, enum.Enum):
    FARMER = "FARMER"
    EXTENSION_WORKER = "EXTENSION_WORKER"
    EXPERT = "EXPERT"
    ADMIN = "ADMIN"

class UserStatus(str, enum.Enum):
    ACTIVE = "ACTIVE"
    INACTIVE = "INACTIVE"
    SUSPENDED = "SUSPENDED"

class User(Base):
    __tablename__ = "users"
    
    name: Mapped[Optional[str]] = mapped_column(String(255), index=True, nullable=True)
    phone: Mapped[str] = mapped_column(String(20), unique=True, index=True)
    email: Mapped[str] = mapped_column(String(255), unique=True, index=True, nullable=True)
    password_hash: Mapped[str] = mapped_column(String(255))
    role: Mapped[UserRole] = mapped_column(SQLEnum(UserRole), default=UserRole.FARMER)
    preferred_language: Mapped[str] = mapped_column(String(10), default="en")
    status: Mapped[UserStatus] = mapped_column(SQLEnum(UserStatus), default=UserStatus.ACTIVE)

    farms = relationship("Farm", back_populates="owner", cascade="all, delete-orphan")
