from typing import Optional
from sqlalchemy.orm import Session
from app.models.user import User
from app.schemas.user import UserCreate, UserUpdate
from app.core.security import get_password_hash, verify_password

def get_user(db: Session, user_id: int) -> Optional[User]:
    return db.query(User).filter(User.id == user_id).first()

def get_user_by_phone(db: Session, phone: str) -> Optional[User]:
    return db.query(User).filter(User.phone == phone).first()

def get_user_by_email(db: Session, email: str) -> Optional[User]:
    return db.query(User).filter(User.email == email).first()

def create_user(db: Session, user_in: UserCreate) -> User:
    db_obj = User(
        phone=user_in.phone,
        email=user_in.email,
        name=user_in.name,
        role=user_in.role,
        password_hash=get_password_hash(user_in.password),
    )
    db.add(db_obj)
    db.commit()
    db.refresh(db_obj)
    return db_obj

def authenticate(db: Session, phone: str, password: str) -> Optional[User]:
    user = get_user_by_phone(db, phone=phone)
    if not user:
        return None
    if not verify_password(password, user.password_hash):
        return None
    return user

def update_user(db: Session, db_obj: User, obj_in: UserUpdate) -> User:
    update_data = obj_in.model_dump(exclude_unset=True)
    if update_data.get("password"):
        hashed_password = get_password_hash(update_data["password"])
        del update_data["password"]
        update_data["password_hash"] = hashed_password
        
    for field in update_data:
        setattr(db_obj, field, update_data[field])
        
    db.add(db_obj)
    db.commit()
    db.refresh(db_obj)
    return db_obj

def delete_user(db: Session, db_obj: User) -> User:
    db.delete(db_obj)
    db.commit()
    return db_obj
