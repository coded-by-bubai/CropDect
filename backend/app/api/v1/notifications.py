from typing import Any, List
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session
from app.api import deps
from app.schemas.notification import NotificationResponse
from app.services import notification_service
from app.models.user import User

router = APIRouter()

@router.get("/", response_model=List[NotificationResponse])
def get_notifications(
    unread_only: bool = False,
    skip: int = 0,
    limit: int = 100,
    db: Session = Depends(deps.get_db),
    current_user: User = Depends(deps.get_current_active_user)
) -> Any:
    """
    Get notifications for current user.
    """
    return notification_service.get_user_notifications(db=db, user_id=current_user.id, unread_only=unread_only, skip=skip, limit=limit)

@router.put("/{notification_id}/read", response_model=NotificationResponse)
def mark_notification_as_read(
    notification_id: int,
    db: Session = Depends(deps.get_db),
    current_user: User = Depends(deps.get_current_active_user)
) -> Any:
    """
    Mark a notification as read.
    """
    return notification_service.mark_as_read(db=db, notification_id=notification_id, user_id=current_user.id)

@router.delete("/")
def delete_all_notifications(
    db: Session = Depends(deps.get_db),
    current_user: User = Depends(deps.get_current_active_user)
) -> Any:
    """
    Delete all notifications for the current user.
    """
    count = notification_service.delete_all_notifications(db=db, user_id=current_user.id)
    return {"message": f"Deleted {count} notifications"}

@router.delete("/{notification_id}")
def delete_notification(
    notification_id: int,
    db: Session = Depends(deps.get_db),
    current_user: User = Depends(deps.get_current_active_user)
) -> Any:
    """
    Delete a specific notification.
    """
    notification_service.delete_notification(db=db, notification_id=notification_id, user_id=current_user.id)
    return {"message": "Notification deleted successfully"}
