from typing import Optional
from datetime import datetime
from pydantic import BaseModel, EmailStr, ConfigDict
from app.models.user import UserRole, UserStatus

# Shared properties
class UserBase(BaseModel):
    phone: str
    email: Optional[EmailStr] = None
    name: Optional[str] = None
    role: UserRole = UserRole.FARMER

# Properties to receive via API on creation
class UserCreate(UserBase):
    password: str

# Properties to receive via API on update
class UserUpdate(BaseModel):
    email: Optional[EmailStr] = None
    name: Optional[str] = None
    password: Optional[str] = None

class UserInDBBase(UserBase):
    id: int
    status: UserStatus
    created_at: datetime
    updated_at: datetime

    model_config = ConfigDict(from_attributes=True)

# Additional properties to return via API
class UserResponse(UserInDBBase):
    pass
