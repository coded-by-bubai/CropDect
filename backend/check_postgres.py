import sys
import os
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from app.db.session import SessionLocal
from app.models.user import User
from app.models.expert_validation import ExpertValidation
from app.models.diagnosis import DiagnosisReport

db = SessionLocal()

print("--- USERS ---")
for u in db.query(User).all():
    print(f"ID: {u.id}, Name: {u.name}, Phone: {u.phone}, Role: {u.role}")

print("\n--- VALIDATIONS ---")
for v in db.query(ExpertValidation).all():
    print(f"ID: {v.id}, Diagnosis ID: {v.diagnosis_id}, Expert ID: {v.expert_id}")

print("\n--- DIAGNOSES ---")
for d in db.query(DiagnosisReport).all():
    print(f"ID: {d.id}, Owner ID: {d.owner_id}")

db.close()
