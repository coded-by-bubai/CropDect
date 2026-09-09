from typing import Any
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.api import deps
from app.models.user import User
from app.schemas.user import UserResponse, UserUpdate
from app.services import user_service

router = APIRouter()

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
