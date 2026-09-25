"""
Production FCM Push Notification Service.
Uses Firebase Admin SDK to send targeted push notifications
to individual users by their stored FCM token.
"""
import logging
from typing import Optional
import firebase_admin
from firebase_admin import credentials, messaging
from sqlalchemy.orm import Session

from app.models.user import User

logger = logging.getLogger(__name__)

# Initialize Firebase Admin SDK once (uses same google-services credentials)
# Place your Firebase service account JSON at backend/firebase_service_account.json
_firebase_initialized = False

def _ensure_initialized():
    global _firebase_initialized
    if not _firebase_initialized:
        try:
            # Try to use service account file for full admin access
            import os
            sa_path = os.path.join(os.path.dirname(__file__), "..", "..", "firebase_service_account.json")
            if os.path.exists(sa_path):
                cred = credentials.Certificate(sa_path)
                firebase_admin.initialize_app(cred)
            else:
                # Fall back to application default credentials (works on GCP/Cloud Run)
                firebase_admin.initialize_app()
            _firebase_initialized = True
            logger.info("Firebase Admin SDK initialized successfully")
        except ValueError:
            # Already initialized
            _firebase_initialized = True
        except Exception as e:
            logger.error(f"Failed to initialize Firebase Admin SDK: {e}")


def send_push_notification(
    fcm_token: str,
    title: str,
    body: str,
    data: Optional[dict] = None,
) -> bool:
    """
    Send a push notification to a single device via FCM token.
    Returns True on success, False on failure.
    """
    _ensure_initialized()
    try:
        message = messaging.Message(
            notification=messaging.Notification(title=title, body=body),
            android=messaging.AndroidConfig(
                priority="high",
                notification=messaging.AndroidNotification(
                    icon="ic_notification",
                    color="#046938",
                    channel_id="weather_alerts_channel",
                    sound="default",
                ),
            ),
            data={k: str(v) for k, v in (data or {}).items()},
            token=fcm_token,
        )
        response = messaging.send(message)
        logger.info(f"FCM notification sent successfully: {response}")
        return True
    except messaging.UnregisteredError:
        logger.warning(f"FCM token is no longer valid: {fcm_token[:20]}...")
        return False
    except Exception as e:
        logger.error(f"Failed to send FCM notification: {e}")
        return False


def send_to_user(
    db: Session,
    user_id: int,
    title: str,
    body: str,
    data: Optional[dict] = None,
) -> bool:
    """
    Look up a user's FCM token and send them a push notification.
    """
    user = db.query(User).filter(User.id == user_id).first()
    if not user or not user.fcm_token:
        logger.info(f"User {user_id} has no FCM token — skipping push notification")
        return False
    return send_push_notification(user.fcm_token, title, body, data)


def send_to_all_farmers(
    db: Session,
    title: str,
    body: str,
    data: Optional[dict] = None,
) -> dict:
    """
    Broadcast a push notification to all active farmers with FCM tokens.
    Returns stats: {sent: int, failed: int, skipped: int}
    """
    from app.models.user import UserRole, UserStatus
    farmers = (
        db.query(User)
        .filter(
            User.role == UserRole.FARMER,
            User.status == UserStatus.ACTIVE,
            User.fcm_token.isnot(None),
        )
        .all()
    )

    stats = {"sent": 0, "failed": 0, "skipped": len(farmers)}

    if not farmers:
        logger.info("No farmers with FCM tokens found for broadcast")
        return stats

    stats["skipped"] = 0
    for farmer in farmers:
        success = send_push_notification(farmer.fcm_token, title, body, data)
        if success:
            stats["sent"] += 1
        else:
            stats["failed"] += 1

    logger.info(f"Broadcast complete: {stats}")
    return stats
