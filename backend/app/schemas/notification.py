from pydantic import BaseModel, ConfigDict
from datetime import datetime
from app.models.notification import NotificationType
from typing import Optional

class NotificationResponse(BaseModel):
    id: int
    user_id: int
    reference_id: Optional[int] = None
    title: str
    message: str
    type: NotificationType
    is_read: bool
    created_at: datetime
    
    model_config = ConfigDict(from_attributes=True)
