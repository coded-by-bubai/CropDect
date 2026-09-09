from app.db.database import SessionLocal
from app.services.expert_service import get_follow_ups
db = SessionLocal()
follow_ups = get_follow_ups(db)
print([(f['id'], f['status']) for f in follow_ups])
