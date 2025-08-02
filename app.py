from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from typing import Dict, Optional
import pandas as pd
import numpy as np
import joblib
import os
import threading
from datetime import datetime
from pydantic import BaseModel

app = FastAPI(title="Fraud Detection API")

# Add CORS middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Load the model and scaler
model = joblib.load('fraud_model.joblib')
scaler = joblib.load('scaler.joblib')

# API Key security - DISABLED FOR DEVELOPMENT
# API_KEY = secrets.token_urlsafe(32)  # Generate a random API key
# api_key_header = APIKeyHeader(name="X-API-Key")

# print(f"Generated API Key: {API_KEY}")  # This will print when you start the server

# async def get_api_key(api_key_header: str = Security(api_key_header)):
#     if api_key_header == API_KEY:
#         return api_key_header
#     raise HTTPException(
#         status_code=403,
#         detail="Invalid API Key"
#     )

class TransactionData(BaseModel):
    step: int
    type: str
    amount: float
    oldbalanceOrg: float
    newbalanceOrig: float
    oldbalanceDest: float
    newbalanceDest: float
    upi_id: str  # New field for UPI ID tracking

# Global fraud counter storage (In-memory for this implementation)
fraud_counters = {}  # {upi_id: {"count": int, "last_fraud": datetime, "total_transactions": int}}
counter_lock = threading.Lock()  # Thread safety

# Configuration
FRAUD_WARNING_THRESHOLD = 10
HIGH_RISK_THRESHOLD = 20

def update_fraud_counter(upi_id: str, is_fraud: bool) -> dict:
    """
    Update fraud counter for UPI ID and return warning status
    Thread-safe implementation
    """
    with counter_lock:
        if upi_id not in fraud_counters:
            fraud_counters[upi_id] = {
                "fraud_count": 0,
                "total_transactions": 0,
                "first_fraud": None,
                "last_fraud": None,
                "warning_triggered": False
            }
        
        # Update transaction count
        fraud_counters[upi_id]["total_transactions"] += 1
        
        # Update fraud count if fraud detected
        if is_fraud:
            fraud_counters[upi_id]["fraud_count"] += 1
            current_time = datetime.now()
            
            if fraud_counters[upi_id]["first_fraud"] is None:
                fraud_counters[upi_id]["first_fraud"] = current_time
            
            fraud_counters[upi_id]["last_fraud"] = current_time
        
        # Generate warning information
        fraud_count = fraud_counters[upi_id]["fraud_count"]
        warning_triggered = fraud_count > FRAUD_WARNING_THRESHOLD
        
        if warning_triggered:
            fraud_counters[upi_id]["warning_triggered"] = True
        
        # Determine risk level
        if fraud_count > HIGH_RISK_THRESHOLD:
            risk_level = "CRITICAL"
            warning_message = f"🚨 CRITICAL RISK: UPI ID {upi_id} has {fraud_count} fraudulent transactions! Consider blocking."
        elif fraud_count > FRAUD_WARNING_THRESHOLD:
            risk_level = "HIGH"
            warning_message = f"⚠️ HIGH RISK: UPI ID {upi_id} has {fraud_count} fraudulent transactions!"
        elif fraud_count > 5:
            risk_level = "MEDIUM"
            warning_message = f"⚡ MEDIUM RISK: UPI ID {upi_id} has {fraud_count} fraudulent transactions."
        else:
            risk_level = "LOW"
            warning_message = None
        
        return {
            "fraud_count": fraud_count,
            "total_transactions": fraud_counters[upi_id]["total_transactions"],
            "warning_triggered": warning_triggered,
            "warning_message": warning_message,
            "risk_level": risk_level,
            "fraud_rate": fraud_count / fraud_counters[upi_id]["total_transactions"] if fraud_counters[upi_id]["total_transactions"] > 0 else 0
        }

def create_advanced_features(transaction_data: Dict):
    """Creates the same features as the training model"""
    df = pd.DataFrame([transaction_data])
    
    # Balance change features
    df['balance_change_orig'] = (df['newbalanceOrig'] - df['oldbalanceOrg']).astype(np.float32)
    df['balance_change_dest'] = (df['newbalanceDest'] - df['oldbalanceDest']).astype(np.float32)
    
    # Critical error features
    df['error_balance_orig'] = (df['balance_change_orig'] + df['amount']).astype(np.float32)
    df['error_balance_dest'] = (df['balance_change_dest'] - df['amount']).astype(np.float32)
    
    # Zero balance flags
    df['orig_zero_after'] = (df['newbalanceOrig'] == 0).astype(np.int8)
    df['dest_zero_before'] = (df['oldbalanceDest'] == 0).astype(np.int8)
    df['orig_zero_before'] = (df['oldbalanceOrg'] == 0).astype(np.int8)
    df['dest_zero_after'] = (df['newbalanceDest'] == 0).astype(np.int8)
    
    # Ratio features
    df['amount_to_orig_ratio'] = (df['amount'] / (df['oldbalanceOrg'] + 1)).astype(np.float32)
    df['amount_to_dest_ratio'] = (df['amount'] / (df['oldbalanceDest'] + 1)).astype(np.float32)
    
    # Transaction type flags
    df['is_cash_out'] = (df['type'] == 'CASH_OUT').astype(np.int8)
    df['is_transfer'] = (df['type'] == 'TRANSFER').astype(np.int8)
    df['is_payment'] = (df['type'] == 'PAYMENT').astype(np.int8)
    df['is_cash_in'] = (df['type'] == 'CASH_IN').astype(np.int8)
    df['is_debit'] = (df['type'] == 'DEBIT').astype(np.int8)
    
    # High amount flag (using a fixed threshold - you might want to adjust this)
    df['high_amount'] = (df['amount'] > 100000).astype(np.int8)
    
    # Suspicious pattern flags
    df['round_amount'] = (df['amount'] % 1 == 0).astype(np.int8)
    df['exact_balance_transfer'] = (df['amount'] == df['oldbalanceOrg']).astype(np.int8)
    
    return df

@app.get("/")
async def root():
    return {
        "message": "Nidhi-Rakshak Fraud Detection API with UPI Tracking",
        "version": "2.0.0",
        "status": "active",
        "features": {
            "fraud_detection": "Advanced ML-based transaction fraud detection",
            "upi_tracking": "Per-UPI ID fraud counter and risk assessment",
            "real_time_warnings": "Automatic warnings for high-risk UPI IDs"
        },
        "endpoints": {
            "health": "/health",
            "predict": "/predict (POST)",
            "fraud_stats": "/fraud-stats/{upi_id} (GET)",
            "all_stats": "/fraud-stats (GET)",
            "reset_counter": "/reset-counter/{upi_id} (POST)",
            "docs": "/docs"
        },
        "thresholds": {
            "warning_threshold": FRAUD_WARNING_THRESHOLD,
            "high_risk_threshold": HIGH_RISK_THRESHOLD
        }
    }

@app.post("/predict")
async def predict(data: TransactionData):
    try:
        # Extract UPI ID
        upi_id = data.upi_id
        
        # Convert input data to dictionary (excluding upi_id for prediction)
        transaction_dict = data.dict()
        transaction_dict.pop('upi_id')  # Remove UPI ID as it's not needed for ML prediction
        
        # Create features
        df = create_advanced_features(transaction_dict)
        
        # Select and order features as per training
        feature_columns = [
            'step', 'amount', 'oldbalanceOrg', 'newbalanceOrig',
            'oldbalanceDest', 'newbalanceDest', 'balance_change_orig',
            'balance_change_dest', 'error_balance_orig', 'error_balance_dest',
            'orig_zero_after', 'dest_zero_before', 'orig_zero_before', 'dest_zero_after',
            'amount_to_orig_ratio', 'amount_to_dest_ratio', 'high_amount',
            'is_cash_out', 'is_transfer', 'is_payment', 'is_cash_in', 'is_debit',
            'round_amount', 'exact_balance_transfer'
        ]
        
        X = df[feature_columns]
        
        # Scale features
        X_scaled = scaler.transform(X)
        
        # Make prediction
        prediction = model.predict(X_scaled)[0]
        probability = model.predict_proba(X_scaled)[0][1]
        is_fraud = bool(prediction)
        
        # Update fraud counter and get tracking info
        tracking_info = update_fraud_counter(upi_id, is_fraud)
        
        # Calculate confidence
        confidence = float(probability if prediction else 1 - probability)
        
        return {
            "transaction": {
                "is_fraud": is_fraud,
                "fraud_probability": float(probability),
                "confidence": confidence
            },
            "upi_tracking": {
                "upi_id": upi_id,
                "fraud_count": tracking_info["fraud_count"],
                "total_transactions": tracking_info["total_transactions"],
                "fraud_rate": f"{tracking_info['fraud_rate']:.2%}",
                "risk_level": tracking_info["risk_level"],
                "warning_triggered": tracking_info["warning_triggered"],
                "warning_message": tracking_info["warning_message"]
            },
            "timestamp": datetime.now().isoformat()
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/health")
async def health_check():
    return {
        "status": "healthy",
        "service": "Nidhi-Rakshak Fraud Detection API with UPI Tracking",
        "version": "2.0.0",
        "active_upi_ids": len(fraud_counters),
        "total_fraud_cases": sum(data["fraud_count"] for data in fraud_counters.values()),
        "high_risk_upi_ids": len([upi for upi, data in fraud_counters.items() if data["fraud_count"] > FRAUD_WARNING_THRESHOLD])
    }

@app.get("/fraud-stats/{upi_id}")
async def get_fraud_stats(upi_id: str):
    """Get fraud statistics for a specific UPI ID"""
    if upi_id not in fraud_counters:
        return {
            "upi_id": upi_id,
            "status": "No transactions found",
            "fraud_count": 0,
            "total_transactions": 0,
            "fraud_rate": "0.00%",
            "risk_level": "UNKNOWN"
        }
    
    data = fraud_counters[upi_id]
    fraud_rate = data["fraud_count"] / data["total_transactions"] if data["total_transactions"] > 0 else 0
    
    # Determine risk level
    if data["fraud_count"] > HIGH_RISK_THRESHOLD:
        risk_level = "CRITICAL"
    elif data["fraud_count"] > FRAUD_WARNING_THRESHOLD:
        risk_level = "HIGH"
    elif data["fraud_count"] > 5:
        risk_level = "MEDIUM"
    else:
        risk_level = "LOW"
    
    return {
        "upi_id": upi_id,
        "fraud_count": data["fraud_count"],
        "total_transactions": data["total_transactions"],
        "fraud_rate": f"{fraud_rate:.2%}",
        "risk_level": risk_level,
        "first_fraud": data["first_fraud"].isoformat() if data["first_fraud"] else None,
        "last_fraud": data["last_fraud"].isoformat() if data["last_fraud"] else None,
        "warning_triggered": data["warning_triggered"]
    }

@app.get("/fraud-stats")
async def get_all_fraud_stats():
    """Get fraud statistics for all UPI IDs"""
    if not fraud_counters:
        return {
            "total_upi_ids": 0,
            "summary": "No transactions recorded yet",
            "statistics": []
        }
    
    stats = []
    total_fraud = 0
    total_transactions = 0
    high_risk_count = 0
    
    for upi_id, data in fraud_counters.items():
        fraud_rate = data["fraud_count"] / data["total_transactions"] if data["total_transactions"] > 0 else 0
        
        # Determine risk level
        if data["fraud_count"] > HIGH_RISK_THRESHOLD:
            risk_level = "CRITICAL"
            high_risk_count += 1
        elif data["fraud_count"] > FRAUD_WARNING_THRESHOLD:
            risk_level = "HIGH"
            high_risk_count += 1
        elif data["fraud_count"] > 5:
            risk_level = "MEDIUM"
        else:
            risk_level = "LOW"
        
        stats.append({
            "upi_id": upi_id,
            "fraud_count": data["fraud_count"],
            "total_transactions": data["total_transactions"],
            "fraud_rate": f"{fraud_rate:.2%}",
            "risk_level": risk_level
        })
        
        total_fraud += data["fraud_count"]
        total_transactions += data["total_transactions"]
    
    # Sort by fraud count (highest first)
    stats.sort(key=lambda x: x["fraud_count"], reverse=True)
    
    overall_fraud_rate = total_fraud / total_transactions if total_transactions > 0 else 0
    
    return {
        "total_upi_ids": len(fraud_counters),
        "total_fraud_cases": total_fraud,
        "total_transactions": total_transactions,
        "overall_fraud_rate": f"{overall_fraud_rate:.2%}",
        "high_risk_upi_ids": high_risk_count,
        "statistics": stats
    }

@app.post("/reset-counter/{upi_id}")
async def reset_fraud_counter(upi_id: str):
    """Reset fraud counter for a specific UPI ID"""
    with counter_lock:
        if upi_id in fraud_counters:
            old_data = fraud_counters[upi_id].copy()
            fraud_counters[upi_id] = {
                "fraud_count": 0,
                "total_transactions": 0,
                "first_fraud": None,
                "last_fraud": None,
                "warning_triggered": False
            }
            return {
                "message": f"Fraud counter reset for UPI ID: {upi_id}",
                "previous_data": {
                    "fraud_count": old_data["fraud_count"],
                    "total_transactions": old_data["total_transactions"]
                },
                "reset_timestamp": datetime.now().isoformat()
            }
        else:
            return {
                "message": f"No data found for UPI ID: {upi_id}",
                "reset_timestamp": datetime.now().isoformat()
            }


if __name__ == "__main__":
    import uvicorn
    port = int(os.getenv("PORT", 8000))
    uvicorn.run("app:app", host="0.0.0.0", port=port)