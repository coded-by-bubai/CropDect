import pandas as pd
import xgboost as xgb
import numpy as np
from sqlalchemy.orm import Session
from sqlalchemy import func
from app.models.diagnosis import DiagnosisReport
from typing import List, Tuple, Dict

def train_and_predict_risk(db: Session, current_temp: float, current_humidity: float, crop_id: int = None) -> float:
    """
    Trains an XGBoost classifier on historical diagnosis data and predicts 
    the probability of an outbreak given current weather conditions.
    """
    # Fetch historical data
    # In a real app we'd fetch healthy vs diseased reports.
    # Here we treat SEVERE/CRITICAL as positive class (1) and LOW/MODERATE as negative class (0) for the model.
    query = db.query(
        DiagnosisReport.infection_temp_c, 
        DiagnosisReport.infection_humidity_percent, 
        DiagnosisReport.severity
    ).filter(
        DiagnosisReport.infection_temp_c.isnot(None),
        DiagnosisReport.infection_humidity_percent.isnot(None)
    )
    
    if crop_id:
        query = query.filter(DiagnosisReport.crop_id == crop_id)
        
    results = query.all()
    
    if not results or len(results) < 5:
        # Not enough data to train XGBoost, return a baseline heuristic
        return 0.5 if current_humidity > 85.0 else 0.1
        
    data = []
    for r in results:
        # 1 for outbreak/high risk, 0 for healthy/low risk
        is_outbreak = 1 if r.severity in ["HIGH", "CRITICAL"] else 0
        data.append({
            "temp": float(r.infection_temp_c),
            "humidity": float(r.infection_humidity_percent),
            "label": is_outbreak
        })
        
    df = pd.DataFrame(data)
    
    # Ensure we have both classes
    if len(df['label'].unique()) < 2:
        return 0.9 if df['label'].iloc[0] == 1 else 0.1
        
    X = df[['temp', 'humidity']]
    y = df['label']
    
    # Train XGBoost model
    model = xgb.XGBClassifier(
        n_estimators=50, 
        max_depth=3, 
        learning_rate=0.1, 
        random_state=42,
        use_label_encoder=False,
        eval_metric='logloss'
    )
    
    model.fit(X, y)
    
    # Predict probability for current weather
    X_pred = pd.DataFrame([{"temp": current_temp, "humidity": current_humidity}])
    prob = model.predict_proba(X_pred)[0][1] # Probability of class 1 (outbreak)
    
    return float(prob)
