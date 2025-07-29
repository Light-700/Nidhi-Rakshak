from fastapi import FastAPI, HTTPException
from typing import Dict
import pandas as pd
import numpy as np
import joblib
from pydantic import BaseModel

app = FastAPI(title="Fraud Detection API")

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
        "message": "Nidhi-Rakshak Fraud Detection API",
        "version": "1.0.0",
        "status": "active",
        "endpoints": {
            "health": "/health",
            "predict": "/predict",
            "docs": "/docs"
        }
    }

@app.post("/predict")
async def predict(data: TransactionData):
    try:
        # Convert input data to dictionary
        transaction_dict = data.dict()
        
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
        
        return {
            "is_fraud": bool(prediction),
            "fraud_probability": float(probability),
            "confidence": float(probability if prediction else 1 - probability)
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/health")
async def health_check():
    return {"status": "healthy"}