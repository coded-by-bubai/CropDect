from typing import List, Optional
from sqlalchemy.orm import Session
from sqlalchemy import or_
from app.models.knowledge_base import KnowledgeBase
from app.schemas.knowledge_base import KBItemCreate, KBItemUpdate

def get_kb_item(db: Session, kb_id: int) -> Optional[KnowledgeBase]:
    return db.query(KnowledgeBase).filter(KnowledgeBase.id == kb_id).first()

def get_kb_items(
    db: Session, 
    skip: int = 0, 
    limit: int = 100, 
    category: Optional[str] = None,
    crop: Optional[str] = None
) -> List[KnowledgeBase]:
    query = db.query(KnowledgeBase)
    if category:
        query = query.filter(KnowledgeBase.category == category)
    if crop:
        query = query.filter(KnowledgeBase.affected_crops.ilike(f"%{crop}%"))
    return query.offset(skip).limit(limit).all()

def create_kb_item(db: Session, item_in: KBItemCreate) -> KnowledgeBase:
    db_item = KnowledgeBase(**item_in.model_dump())
    db.add(db_item)
    db.commit()
    db.refresh(db_item)
    return db_item

def update_kb_item(db: Session, db_item: KnowledgeBase, item_in: KBItemUpdate) -> KnowledgeBase:
    update_data = item_in.model_dump(exclude_unset=True)
    for field, value in update_data.items():
        setattr(db_item, field, value)
    db.commit()
    db.refresh(db_item)
    return db_item

def delete_kb_item(db: Session, db_item: KnowledgeBase) -> KnowledgeBase:
    db.delete(db_item)
    db.commit()
    return db_item
