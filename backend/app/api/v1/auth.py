from datetime import timedelta
from typing import Any
from fastapi import APIRouter, Depends, HTTPException, Request, status
from fastapi.security import OAuth2PasswordRequestForm
from sqlalchemy.orm import Session
from app.core.limiter import limiter

from app.api import deps
from app.core.config import settings
from app.core.security import create_access_token
from app.schemas.token import Token
from app.schemas.user import UserCreate, UserResponse
from app.services import user_service
from app.models.user import UserRole
from pydantic import BaseModel

router = APIRouter()


@router.post("/login", response_model=Token)
@limiter.limit("5/minute")
def login_access_token(
    request: Request,
    db: Session = Depends(deps.get_db),
    form_data: OAuth2PasswordRequestForm = Depends()
) -> Any:
    """
    OAuth2 compatible token login, get an access token for future requests.
    Using phone as username.
    """
    user = user_service.authenticate(
        db, phone=form_data.username, password=form_data.password
    )
    if not user:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Incorrect phone or password"
        )
    if user.status != "ACTIVE":
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Inactive user"
        )

    access_token_expires = timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)
    return {
        "access_token": create_access_token(
            user.id, expires_delta=access_token_expires
        ),
        "token_type": "bearer",
    }


@router.post("/register", response_model=UserResponse)
def register_user(
    *,
    db: Session = Depends(deps.get_db),
    user_in: UserCreate,
) -> Any:
    """
    Register new user (FARMER or EXPERT only).
    Admin accounts must use /auth/register-admin with the admin secret key.
    """
    # Block public self-registration as ADMIN
    if user_in.role == UserRole.ADMIN:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Admin accounts cannot be created via public registration.",
        )
    user = user_service.get_user_by_phone(db, phone=user_in.phone)
    if user:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="The user with this phone number already exists in the system.",
        )
    if user_in.email:
        user_by_email = user_service.get_user_by_email(db, email=user_in.email)
        if user_by_email:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="The user with this email already exists in the system.",
            )
    user = user_service.create_user(db, user_in=user_in)
    return user


# ── Admin-only registration ─────────────────────────────────────────────────

class AdminRegisterRequest(BaseModel):
    phone: str
    password: str
    name: str | None = None
    email: str | None = None
    admin_secret: str


@router.post("/register-admin", response_model=UserResponse)
@limiter.limit("3/minute")
def register_admin(
    request: Request,
    *,
    db: Session = Depends(deps.get_db),
    body: AdminRegisterRequest,
) -> Any:
    """
    Register a new ADMIN account.
    Requires the ADMIN_SECRET_KEY configured in backend settings (set via .env).
    Rate-limited to 3 attempts/minute to prevent secret brute-forcing.
    """
    if body.admin_secret != settings.ADMIN_SECRET_KEY:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Invalid admin secret key.",
        )

    existing = user_service.get_user_by_phone(db, phone=body.phone)
    if existing:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="A user with this phone number already exists.",
        )

    user_in = UserCreate(
        phone=body.phone,
        password=body.password,
        name=body.name,
        email=body.email,
        role=UserRole.ADMIN,
    )
    user = user_service.create_user(db, user_in=user_in)
    return user
