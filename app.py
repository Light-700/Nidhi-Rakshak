from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from typing import Dict, Optional, List
import pandas as pd
import numpy as np
import joblib
import os
import threading
import json
from datetime import datetime, timedelta
from pydantic import BaseModel
import sqlite3
from contextlib import contextmanager
from dotenv import load_dotenv

load_dotenv()

RENDER_API_KEY = os.getenv("Render")
ENVIRONMENT = os.getenv("ENVIRONMENT", "production")

app = FastAPI(title="Fraud Detection API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

model = joblib.load('fraud_model.joblib')
scaler = joblib.load('scaler.joblib')

class TransactionData(BaseModel):
    step: int
    type: str
    amount: float
    oldbalanceOrg: float
    newbalanceOrig: float
    oldbalanceDest: float
    newbalanceDest: float
    upi_id: str  

class UserLookupRequest(BaseModel):
    upi_id: str
    partner_app_id: str
    transaction_amount: Optional[float] = None

class PartnerAppRegistration(BaseModel):
    app_name: str
    app_id: str
    contact_email: str
    webhook_url: Optional[str] = None
    api_key: Optional[str] = None

class TransactionValidationRequest(BaseModel):
    upi_id: str
    partner_app_id: str
    transaction_amount: float
    transaction_type: str
    recipient_upi_id: Optional[str] = None

class FraudProfile(BaseModel):
    upi_id: str
    current_risk_level: str
    total_fraud_count: int
    total_transactions: int
    fraud_rate: float
    last_fraud_date: Optional[str]
    risk_score: float
    warning_flags: List[str]
    is_blacklisted: bool

fraud_counters = {}  
counter_lock = threading.Lock()  

FRAUD_WARNING_THRESHOLD = 10
HIGH_RISK_THRESHOLD = 20
CRITICAL_RISK_THRESHOLD = 50
BLACKLIST_THRESHOLD = 100

DATABASE_FILE = "fraud_database.db"

@contextmanager
def get_db_connection():
    conn = sqlite3.connect(DATABASE_FILE)
    conn.row_factory = sqlite3.Row
    try:
        yield conn
    finally:
        conn.close()

def initialize_database():
    with get_db_connection() as conn:
        conn.execute('''
            CREATE TABLE IF NOT EXISTS fraud_profiles (
                upi_id TEXT PRIMARY KEY,
                total_fraud_count INTEGER DEFAULT 0,
                total_transactions INTEGER DEFAULT 0,
                fraud_rate REAL DEFAULT 0.0,
                current_risk_level TEXT DEFAULT 'LOW',
                risk_score REAL DEFAULT 0.0,
                first_fraud_date TEXT,
                last_fraud_date TEXT,
                last_updated TEXT,
                is_blacklisted BOOLEAN DEFAULT FALSE,
                warning_flags TEXT DEFAULT '[]',
                created_at TEXT DEFAULT CURRENT_TIMESTAMP
            )
        ''')
        
        conn.execute('''
            CREATE TABLE IF NOT EXISTS transaction_history (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                upi_id TEXT,
                transaction_amount REAL,
                transaction_type TEXT,
                is_fraud BOOLEAN,
                fraud_probability REAL,
                risk_level TEXT,
                partner_app_id TEXT,
                timestamp TEXT DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY (upi_id) REFERENCES fraud_profiles (upi_id)
            )
        ''')
        
        conn.execute('''
            CREATE TABLE IF NOT EXISTS partner_access_logs (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                partner_app_id TEXT,
                upi_id TEXT,
                action TEXT,
                response_data TEXT,
                timestamp TEXT DEFAULT CURRENT_TIMESTAMP
            )
        ''')
        
        conn.execute('''
            CREATE TABLE IF NOT EXISTS partner_apps (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                app_id TEXT UNIQUE,
                app_name TEXT,
                contact_email TEXT,
                webhook_url TEXT,
                api_key TEXT,
                is_active BOOLEAN DEFAULT TRUE,
                total_requests INTEGER DEFAULT 0,
                created_at TEXT DEFAULT CURRENT_TIMESTAMP,
                last_access TEXT
            )
        ''')
        
        conn.commit()

initialize_database()

@app.on_event("startup")
async def startup_event():
    try:
        with get_db_connection() as conn:
            existing = conn.execute(
                "SELECT app_id FROM partner_apps WHERE app_id = ?", ("mock_payment_app",)
            ).fetchone()
            
            if not existing:
                conn.execute('''
                    INSERT INTO partner_apps 
                    (app_id, app_name, contact_email, webhook_url, api_key, is_active)
                    VALUES (?, ?, ?, ?, ?, ?)
                ''', ("mock_payment_app", "Mock Payment App", "test@example.com", 
                      None, "default_key", True))
                conn.commit()
            else:
                pass
                
    except Exception as e:
        pass

def calculate_risk_score(fraud_count: int, total_transactions: int, recent_frauds: int = 0) -> float:
    if total_transactions == 0:
        return 0.0
    
    fraud_rate = fraud_count / total_transactions
    base_score = fraud_rate * 100
    
    if fraud_count > 50:
        base_score += 30
    elif fraud_count > 20:
        base_score += 15
    elif fraud_count > 10:
        base_score += 5
    
    base_score += recent_frauds * 2
    
    return min(base_score, 100.0)

def get_risk_level_from_score(risk_score: float, fraud_count: int) -> str:
    if fraud_count >= BLACKLIST_THRESHOLD or risk_score >= 90:
        return "BLACKLISTED"
    elif fraud_count >= CRITICAL_RISK_THRESHOLD or risk_score >= 75:
        return "CRITICAL"
    elif fraud_count >= HIGH_RISK_THRESHOLD or risk_score >= 50:
        return "HIGH"
    elif fraud_count >= FRAUD_WARNING_THRESHOLD or risk_score >= 25:
        return "MEDIUM"
    else:
        return "LOW"

def update_user_fraud_profile(upi_id: str, is_fraud: bool, transaction_amount: float = 0, 
                            transaction_type: str = "", partner_app_id: str = "") -> dict:
    
    with get_db_connection() as conn:
        profile = conn.execute(
            "SELECT * FROM fraud_profiles WHERE upi_id = ?", (upi_id,)
        ).fetchone()
        
        current_time = datetime.now().isoformat()
        
        if profile is None:
            fraud_count = 1 if is_fraud else 0
            total_transactions = 1
            fraud_rate = fraud_count / total_transactions
            risk_score = calculate_risk_score(fraud_count, total_transactions)
            risk_level = get_risk_level_from_score(risk_score, fraud_count)
            
            warning_flags = []
            if is_fraud:
                warning_flags.append("FIRST_FRAUD_DETECTED")
            
            conn.execute('''
                INSERT INTO fraud_profiles 
                (upi_id, total_fraud_count, total_transactions, fraud_rate, 
                 current_risk_level, risk_score, first_fraud_date, last_fraud_date, 
                 last_updated, warning_flags)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ''', (upi_id, fraud_count, total_transactions, fraud_rate, risk_level, 
                  risk_score, current_time if is_fraud else None, 
                  current_time if is_fraud else None, current_time, json.dumps(warning_flags)))
        else:
            fraud_count = profile['total_fraud_count'] + (1 if is_fraud else 0)
            total_transactions = profile['total_transactions'] + 1
            fraud_rate = fraud_count / total_transactions if total_transactions > 0 else 0
            risk_score = calculate_risk_score(fraud_count, total_transactions)
            risk_level = get_risk_level_from_score(risk_score, fraud_count)
            
            warning_flags = json.loads(profile['warning_flags']) if profile['warning_flags'] else []
            
            if fraud_count == FRAUD_WARNING_THRESHOLD:
                warning_flags.append("MEDIUM_RISK_THRESHOLD_REACHED")
            elif fraud_count == HIGH_RISK_THRESHOLD:
                warning_flags.append("HIGH_RISK_THRESHOLD_REACHED")
            elif fraud_count == CRITICAL_RISK_THRESHOLD:
                warning_flags.append("CRITICAL_RISK_THRESHOLD_REACHED")
            elif fraud_count >= BLACKLIST_THRESHOLD:
                warning_flags.append("BLACKLIST_THRESHOLD_REACHED")
            
            if is_fraud and profile['last_fraud_date']:
                last_fraud = datetime.fromisoformat(profile['last_fraud_date'])
                if datetime.now() - last_fraud < timedelta(hours=24):
                    warning_flags.append("RECENT_FRAUD_ACTIVITY")
            
            is_blacklisted = fraud_count >= BLACKLIST_THRESHOLD or risk_score >= 90
            
            conn.execute('''
                UPDATE fraud_profiles 
                SET total_fraud_count = ?, total_transactions = ?, fraud_rate = ?,
                    current_risk_level = ?, risk_score = ?, last_fraud_date = ?,
                    last_updated = ?, is_blacklisted = ?, warning_flags = ?
                WHERE upi_id = ?
            ''', (fraud_count, total_transactions, fraud_rate, risk_level, risk_score,
                  current_time if is_fraud else profile['last_fraud_date'],
                  current_time, is_blacklisted, json.dumps(warning_flags), upi_id))
        
        conn.execute('''
            INSERT INTO transaction_history 
            (upi_id, transaction_amount, transaction_type, is_fraud, 
             fraud_probability, risk_level, partner_app_id)
            VALUES (?, ?, ?, ?, ?, ?, ?)
        ''', (upi_id, transaction_amount, transaction_type, is_fraud, 
              risk_score/100, risk_level, partner_app_id))
        
        conn.commit()
        
        updated_profile = conn.execute(
            "SELECT * FROM fraud_profiles WHERE upi_id = ?", (upi_id,)
        ).fetchone()
        
        return {
            "upi_id": upi_id,
            "fraud_count": updated_profile['total_fraud_count'],
            "total_transactions": updated_profile['total_transactions'],
            "fraud_rate": updated_profile['fraud_rate'],
            "risk_level": updated_profile['current_risk_level'],
            "risk_score": updated_profile['risk_score'],
            "warning_flags": json.loads(updated_profile['warning_flags']),
            "is_blacklisted": bool(updated_profile['is_blacklisted']),
            "last_updated": updated_profile['last_updated']
        }

def get_user_fraud_profile(upi_id: str, partner_app_id: str = "") -> dict:
    
    with get_db_connection() as conn:
        profile = conn.execute(
            "SELECT * FROM fraud_profiles WHERE upi_id = ?", (upi_id,)
        ).fetchone()
        
        if partner_app_id:
            conn.execute('''
                INSERT INTO partner_access_logs (partner_app_id, upi_id, action, response_data)
                VALUES (?, ?, ?, ?)
            ''', (partner_app_id, upi_id, "PROFILE_LOOKUP", ""))
            conn.commit()
        
        if profile is None:
            return {
                "upi_id": upi_id,
                "status": "USER_NOT_FOUND",
                "risk_level": "UNKNOWN",
                "fraud_count": 0,
                "total_transactions": 0,
                "fraud_rate": 0.0,
                "risk_score": 0.0,
                "warning_flags": [],
                "is_blacklisted": False,
                "recommendation": "NEW_USER_CAUTION"
            }
        
        warning_flags = json.loads(profile['warning_flags']) if profile['warning_flags'] else []
        
        recommendation = "PROCEED"
        if profile['is_blacklisted']:
            recommendation = "BLOCK_TRANSACTION"
        elif profile['current_risk_level'] == "CRITICAL":
            recommendation = "MANUAL_REVIEW_REQUIRED"
        elif profile['current_risk_level'] == "HIGH":
            recommendation = "ENHANCED_VERIFICATION"
        elif profile['current_risk_level'] == "MEDIUM":
            recommendation = "PROCEED_WITH_CAUTION"
        
        return {
            "upi_id": upi_id,
            "status": "USER_FOUND",
            "risk_level": profile['current_risk_level'],
            "fraud_count": profile['total_fraud_count'],
            "total_transactions": profile['total_transactions'],
            "fraud_rate": profile['fraud_rate'],
            "risk_score": profile['risk_score'],
            "warning_flags": warning_flags,
            "is_blacklisted": bool(profile['is_blacklisted']),
            "last_fraud_date": profile['last_fraud_date'],
            "recommendation": recommendation,
            "profile_age_days": (datetime.now() - datetime.fromisoformat(profile['created_at'])).days if profile['created_at'] else 0
        }
def update_fraud_counter(upi_id: str, is_fraud: bool) -> dict:
    profile_update = update_user_fraud_profile(upi_id, is_fraud)
    
    warning_message = None
    if profile_update["risk_level"] == "CRITICAL":
        warning_message = f"🚨 CRITICAL RISK: UPI ID {upi_id} has {profile_update['fraud_count']} fraudulent transactions! Consider blocking."
    elif profile_update["risk_level"] == "HIGH":
        warning_message = f"⚠️ HIGH RISK: UPI ID {upi_id} has {profile_update['fraud_count']} fraudulent transactions!"
    elif profile_update["risk_level"] == "MEDIUM":
        warning_message = f"⚡ MEDIUM RISK: UPI ID {upi_id} has {profile_update['fraud_count']} fraudulent transactions."
    
    return {
        "fraud_count": profile_update["fraud_count"],
        "total_transactions": profile_update["total_transactions"],
        "warning_triggered": profile_update["fraud_count"] > FRAUD_WARNING_THRESHOLD,
        "warning_message": warning_message,
        "risk_level": profile_update["risk_level"],
        "fraud_rate": profile_update["fraud_rate"]
    } 
def create_advanced_features(transaction_data: Dict):
    df = pd.DataFrame([transaction_data])
    
    df['balance_change_orig'] = (df['newbalanceOrig'] - df['oldbalanceOrg']).astype(np.float32)
    df['balance_change_dest'] = (df['newbalanceDest'] - df['oldbalanceDest']).astype(np.float32)
    
    df['error_balance_orig'] = (df['balance_change_orig'] + df['amount']).astype(np.float32)
    df['error_balance_dest'] = (df['balance_change_dest'] - df['amount']).astype(np.float32)
    
    df['orig_zero_after'] = (df['newbalanceOrig'] == 0).astype(np.int8)
    df['dest_zero_before'] = (df['oldbalanceDest'] == 0).astype(np.int8)
    df['orig_zero_before'] = (df['oldbalanceOrg'] == 0).astype(np.int8)
    df['dest_zero_after'] = (df['newbalanceDest'] == 0).astype(np.int8)
    
    df['amount_to_orig_ratio'] = (df['amount'] / (df['oldbalanceOrg'] + 1)).astype(np.float32)
    df['amount_to_dest_ratio'] = (df['amount'] / (df['oldbalanceDest'] + 1)).astype(np.float32)
    
    df['is_cash_out'] = (df['type'] == 'CASH_OUT').astype(np.int8)
    df['is_transfer'] = (df['type'] == 'TRANSFER').astype(np.int8)
    df['is_payment'] = (df['type'] == 'PAYMENT').astype(np.int8)
    df['is_cash_in'] = (df['type'] == 'CASH_IN').astype(np.int8)
    df['is_debit'] = (df['type'] == 'DEBIT').astype(np.int8)
    
    df['high_amount'] = (df['amount'] > 100000).astype(np.int8)
    
    df['round_amount'] = (df['amount'] % 1 == 0).astype(np.int8)
    df['exact_balance_transfer'] = (df['amount'] == df['oldbalanceOrg']).astype(np.int8)
    
    return df

@app.get("/")
async def root():
    return {
        "message": "Nidhi-Rakshak Fraud Detection API with UPI Tracking - Cloud Ready",
        "version": "2.0.1",
        "status": "active",
        "environment": ENVIRONMENT,
        "render_configured": bool(RENDER_API_KEY),
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
            "user_lookup": "/user-lookup (POST) - Truecaller-like fraud lookup",
            "fraud_profile": "/fraud-profile/{upi_id} (GET) - Get detailed fraud profile",
            "blacklist": "/blacklist/{upi_id} (POST) - Manually blacklist user",
            "partner_stats": "/partner-stats/{partner_app_id} (GET) - Partner usage stats",
            "register_partner": "/register-partner (POST) - Register new partner app",
            "validate_transaction": "/validate-transaction (POST) - Real-time transaction validation",
            "docs": "/docs"
        },
        "thresholds": {
            "warning_threshold": FRAUD_WARNING_THRESHOLD,
            "high_risk_threshold": HIGH_RISK_THRESHOLD,
            "critical_risk_threshold": CRITICAL_RISK_THRESHOLD,
            "blacklist_threshold": BLACKLIST_THRESHOLD
        }
    }

@app.post("/predict")
async def predict(data: TransactionData):
    try:
        upi_id = data.upi_id
        
        transaction_dict = data.dict()
        transaction_dict.pop('upi_id')  
        
        df = create_advanced_features(transaction_dict)
        
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
        
        X_scaled = scaler.transform(X)
        
        prediction = model.predict(X_scaled)[0]
        probability = model.predict_proba(X_scaled)[0][1]
        is_fraud = bool(prediction)
        
        profile_update = update_user_fraud_profile(
            upi_id, is_fraud, data.amount, data.type, "internal_api"
        )
        
        confidence = float(probability if prediction else 1 - probability)
        
        return {
            "transaction": {
                "is_fraud": is_fraud,
                "fraud_probability": float(probability),
                "confidence": confidence
            },
            "upi_tracking": {
                "upi_id": upi_id,
                "fraud_count": profile_update["fraud_count"],
                "total_transactions": profile_update["total_transactions"],
                "fraud_rate": f"{profile_update['fraud_rate']:.2%}",
                "risk_level": profile_update["risk_level"],
                "risk_score": profile_update["risk_score"],
                "warning_flags": profile_update["warning_flags"],
                "is_blacklisted": profile_update["is_blacklisted"]
            },
            "timestamp": datetime.now().isoformat()
