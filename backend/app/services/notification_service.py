from sqlalchemy.orm import Session
from app.models.notification import Notification, NotificationType
from fastapi import HTTPException
from typing import List

def create_notification(db: Session, user_id: int, title: str, message: str, type: NotificationType, reference_id: int = None) -> Notification:
    notif = Notification(user_id=user_id, reference_id=reference_id, title=title, message=message, type=type)
    db.add(notif)
    db.commit()
    db.refresh(notif)
    return notif

def get_user_notifications(db: Session, user_id: int, unread_only: bool = False, skip: int = 0, limit: int = 100) -> List[Notification]:
    query = db.query(Notification).filter(Notification.user_id == user_id)
    if unread_only:
        query = query.filter(Notification.is_read == False)
    return query.order_by(Notification.created_at.desc()).offset(skip).limit(limit).all()

def mark_as_read(db: Session, notification_id: int, user_id: int) -> Notification:
    notif = db.query(Notification).filter(Notification.id == notification_id, Notification.user_id == user_id).first()
    if not notif:
        raise HTTPException(status_code=404, detail="Notification not found")
    notif.is_read = True
    db.commit()
    db.refresh(notif)
    return notif

def delete_notification(db: Session, notification_id: int, user_id: int) -> bool:
    notif = db.query(Notification).filter(Notification.id == notification_id, Notification.user_id == user_id).first()
    if not notif:
        raise HTTPException(status_code=404, detail="Notification not found")
    db.delete(notif)
    db.commit()
    return True

def delete_all_notifications(db: Session, user_id: int) -> int:
    deleted_count = db.query(Notification).filter(Notification.user_id == user_id).delete()
    db.commit()
    return deleted_count
