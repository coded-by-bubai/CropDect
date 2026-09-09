from sqlalchemy import text
from app.db.database import SessionLocal

def test_db_connection():
    db = SessionLocal()
    try:
        # Check if we can execute a simple query
        result = db.execute(text("SELECT 1"))
        assert result.scalar() == 1
        
        # Check if the tables exist
        result = db.execute(text("SELECT table_name FROM information_schema.tables WHERE table_schema='public'"))
        tables = [row[0] for row in result.fetchall()]
        assert "users" in tables
        assert "farms" in tables
        assert "crops" in tables
        assert "diagnosis_reports" in tables
    finally:
        db.close()
