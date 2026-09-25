from typing import Any
from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from sqlalchemy.orm import Session

from app.api import deps
from app.models.user import User
from app.schemas.user import UserResponse, UserUpdate
from app.services import user_service

router = APIRouter()

class FCMTokenRequest(BaseModel):
    token: str

@router.get("/me", response_model=UserResponse)
def read_user_me(
    current_user: User = Depends(deps.get_current_active_user),
) -> Any:
    """
    Get current user profile.
    """
    return current_user

@router.put("/me", response_model=UserResponse)
def update_user_me(
    *,
    db: Session = Depends(deps.get_db),
    user_in: UserUpdate,
    current_user: User = Depends(deps.get_current_active_user),
) -> Any:
    """
    Update own user profile.
    """
    return user_service.update_user(db=db, db_obj=current_user, obj_in=user_in)

@router.delete("/me", response_model=UserResponse)
def delete_user_me(
    *,
    db: Session = Depends(deps.get_db),
    current_user: User = Depends(deps.get_current_active_user),
) -> Any:
    """
    Delete own user profile and all associated data.
    """
    return user_service.delete_user(db=db, db_obj=current_user)

@router.post("/me/fcm-token", status_code=status.HTTP_204_NO_CONTENT)
def register_fcm_token(
    *,
    db: Session = Depends(deps.get_db),
    body: FCMTokenRequest,
    current_user: User = Depends(deps.get_current_active_user),
) -> None:
    """
    Register or update the FCM device token for the current user.
    Called by the Flutter app after login to enable push notifications.
    """
    current_user.fcm_token = body.token
    db.commit()
