import sys
import os

# Add backend dir to python path
sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "backend")))

from app.db.database import SessionLocal
from app.ml.risk_predictor import train_and_predict_risk

def run_test():
    db = SessionLocal()
    try:
        print("=== XGBoost AI Risk Prediction Test ===")
        
        # Test Case 1: High Humidity and High Temp (Classic fungal disease weather)
        temp_1 = 28.5
        humidity_1 = 92.0
        risk_1 = train_and_predict_risk(db, temp_1, humidity_1)
        print(f"\n[Test 1] Weather: {temp_1}°C, {humidity_1}% Humidity")
        print(f"-> Predicted Outbreak Risk: {risk_1 * 100:.2f}%")
        
        # Test Case 2: Cool and Dry (Low risk weather)
        temp_2 = 20.0
        humidity_2 = 45.0
        risk_2 = train_and_predict_risk(db, temp_2, humidity_2)
        print(f"\n[Test 2] Weather: {temp_2}°C, {humidity_2}% Humidity")
        print(f"-> Predicted Outbreak Risk: {risk_2 * 100:.2f}%")
        
        print("\nTest completed successfully!")
    except Exception as e:
        print(f"Error testing XGBoost: {e}")
    finally:
        db.close()

if __name__ == "__main__":
    run_test()
