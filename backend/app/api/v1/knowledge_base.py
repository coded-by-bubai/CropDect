from typing import Any, List, Optional
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from app.api import deps
from app.schemas.knowledge_base import KBItemCreate, KBItemUpdate, KBItemResponse
from app.services import kb_service
from app.models.user import User

router = APIRouter()

@router.get("/", response_model=List[KBItemResponse])
def read_kb_items(
    db: Session = Depends(deps.get_db),
    skip: int = 0,
    limit: int = 100,
    category: Optional[str] = None,
    crop: Optional[str] = None,
    current_user: User = Depends(deps.get_current_active_user),
) -> Any:
    """
    Search the Knowledge Base for diseases and pests.
    Accessible to all active users.
    """
    return kb_service.get_kb_items(db=db, skip=skip, limit=limit, category=category, crop=crop)

@router.post("/", response_model=KBItemResponse)
def create_kb_item(
    *,
    db: Session = Depends(deps.get_db),
    item_in: KBItemCreate,
    current_user: User = Depends(deps.get_current_expert_or_admin),
) -> Any:
    """
    Add a new Disease or Pest to the Knowledge Base.
    Restricted to EXPERT and ADMIN roles.
    """
    return kb_service.create_kb_item(db=db, item_in=item_in)

@router.get("/{item_id}", response_model=KBItemResponse)
def read_kb_item(
    *,
    db: Session = Depends(deps.get_db),
    item_id: int,
    current_user: User = Depends(deps.get_current_active_user),
) -> Any:
    """
    Get detailed information about a specific disease or pest.
    """
    item = kb_service.get_kb_item(db=db, kb_id=item_id)
    if not item:
        raise HTTPException(status_code=404, detail="Item not found")
    return item

@router.put("/{item_id}", response_model=KBItemResponse)
def update_kb_item(
    *,
    db: Session = Depends(deps.get_db),
    item_id: int,
    item_in: KBItemUpdate,
    current_user: User = Depends(deps.get_current_expert_or_admin),
) -> Any:
    """
    Update an existing Knowledge Base entry.
    Restricted to EXPERT and ADMIN roles.
    """
    item = kb_service.get_kb_item(db=db, kb_id=item_id)
    if not item:
        raise HTTPException(status_code=404, detail="Item not found")
    return kb_service.update_kb_item(db=db, db_item=item, item_in=item_in)

@router.delete("/{item_id}", response_model=KBItemResponse)
def delete_kb_item(
    *,
    db: Session = Depends(deps.get_db),
    item_id: int,
    current_user: User = Depends(deps.get_current_expert_or_admin),
) -> Any:
    """
    Delete an existing Knowledge Base entry.
    Restricted to EXPERT and ADMIN roles.
    """
    item = kb_service.get_kb_item(db=db, kb_id=item_id)
    if not item:
        raise HTTPException(status_code=404, detail="Item not found")
    return kb_service.delete_kb_item(db=db, db_item=item)
