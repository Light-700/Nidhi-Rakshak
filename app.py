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

# Load environment variables from .env file
load_dotenv()

# Get Render configuration
RENDER_API_KEY = os.getenv("Render")
ENVIRONMENT = os.getenv("ENVIRONMENT", "production")

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

# Global fraud counter storage (In-memory for this implementation)
fraud_counters = {}  # {upi_id: {"count": int, "last_fraud": datetime, "total_transactions": int}}
counter_lock = threading.Lock()  # Thread safety

# Configuration
FRAUD_WARNING_THRESHOLD = 10
HIGH_RISK_THRESHOLD = 20
CRITICAL_RISK_THRESHOLD = 50
BLACKLIST_THRESHOLD = 100

# Database setup for persistent fraud records
DATABASE_FILE = "fraud_database.db"

@contextmanager
def get_db_connection():
    """Context manager for database connections"""
    conn = sqlite3.connect(DATABASE_FILE)
    conn.row_factory = sqlite3.Row
    try:
        yield conn
    finally:
        conn.close()

def initialize_database():
    """Initialize the fraud database with required tables"""
    with get_db_connection() as conn:
        # User fraud profiles table
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
        
        # Transaction history table
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
        
        # Partner app access logs
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
        
        # Partner app registrations
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

# Initialize database on startup
initialize_database()

@app.on_event("startup")
async def startup_event():
    """Initialize default partner apps on startup"""
    try:
        with get_db_connection() as conn:
            # Check if mock_payment_app already exists
            existing = conn.execute(
                "SELECT app_id FROM partner_apps WHERE app_id = ?", ("mock_payment_app",)
            ).fetchone()
            
            if not existing:
                # Register the mock payment app automatically
                conn.execute('''
                    INSERT INTO partner_apps 
                    (app_id, app_name, contact_email, webhook_url, api_key, is_active)
                    VALUES (?, ?, ?, ?, ?, ?)
                ''', ("mock_payment_app", "Mock Payment App", "test@example.com", 
                      None, "default_key", True))
                conn.commit()
                print("✅ Mock Payment App registered automatically")
            else:
                print("✅ Mock Payment App already registered")
                
    except Exception as e:
        print(f"⚠️ Warning: Could not auto-register mock payment app: {e}")

def calculate_risk_score(fraud_count: int, total_transactions: int, recent_frauds: int = 0) -> float:
    """Calculate a numerical risk score (0-100)"""
    if total_transactions == 0:
        return 0.0
    
    fraud_rate = fraud_count / total_transactions
    base_score = fraud_rate * 100
    
    # Add penalties for high absolute fraud count
    if fraud_count > 50:
        base_score += 30
    elif fraud_count > 20:
        base_score += 15
    elif fraud_count > 10:
        base_score += 5
    
    # Add recent activity penalty
    base_score += recent_frauds * 2
    
    return min(base_score, 100.0)

def get_risk_level_from_score(risk_score: float, fraud_count: int) -> str:
    """Determine risk level based on score and fraud count"""
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
    """Update user's fraud profile in database and return current status"""
    
    with get_db_connection() as conn:
        # Get current profile
        profile = conn.execute(
            "SELECT * FROM fraud_profiles WHERE upi_id = ?", (upi_id,)
        ).fetchone()
        
        current_time = datetime.now().isoformat()
        
        if profile is None:
            # Create new profile
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
            # Update existing profile
            fraud_count = profile['total_fraud_count'] + (1 if is_fraud else 0)
            total_transactions = profile['total_transactions'] + 1
            fraud_rate = fraud_count / total_transactions if total_transactions > 0 else 0
            risk_score = calculate_risk_score(fraud_count, total_transactions)
            risk_level = get_risk_level_from_score(risk_score, fraud_count)
            
            # Update warning flags
            warning_flags = json.loads(profile['warning_flags']) if profile['warning_flags'] else []
            
            # Add new warnings based on thresholds
            if fraud_count == FRAUD_WARNING_THRESHOLD:
                warning_flags.append("MEDIUM_RISK_THRESHOLD_REACHED")
            elif fraud_count == HIGH_RISK_THRESHOLD:
                warning_flags.append("HIGH_RISK_THRESHOLD_REACHED")
            elif fraud_count == CRITICAL_RISK_THRESHOLD:
                warning_flags.append("CRITICAL_RISK_THRESHOLD_REACHED")
            elif fraud_count >= BLACKLIST_THRESHOLD:
                warning_flags.append("BLACKLIST_THRESHOLD_REACHED")
            
            # Check for recent fraud activity (last 24 hours)
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
        
        # Log transaction
        conn.execute('''
            INSERT INTO transaction_history 
            (upi_id, transaction_amount, transaction_type, is_fraud, 
             fraud_probability, risk_level, partner_app_id)
            VALUES (?, ?, ?, ?, ?, ?, ?)
        ''', (upi_id, transaction_amount, transaction_type, is_fraud, 
              risk_score/100, risk_level, partner_app_id))
        
        conn.commit()
        
        # Get updated profile
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
    """Get current fraud profile for a user (Truecaller-like lookup)"""
    
    with get_db_connection() as conn:
        profile = conn.execute(
            "SELECT * FROM fraud_profiles WHERE upi_id = ?", (upi_id,)
        ).fetchone()
        
        # Log partner access
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
        
        # Generate recommendation
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
    """
    Legacy function - now wraps the database-based profile system
    """
    profile_update = update_user_fraud_profile(upi_id, is_fraud)
    
    # Convert to legacy format for backward compatibility
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
        
        # Update fraud profile in database
        profile_update = update_user_fraud_profile(
            upi_id, is_fraud, data.amount, data.type, "internal_api"
        )
        
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
                "fraud_count": profile_update["fraud_count"],
                "total_transactions": profile_update["total_transactions"],
                "fraud_rate": f"{profile_update['fraud_rate']:.2%}",
                "risk_level": profile_update["risk_level"],
                "risk_score": profile_update["risk_score"],
                "warning_flags": profile_update["warning_flags"],
                "is_blacklisted": profile_update["is_blacklisted"]
            },
            "timestamp": datetime.now().isoformat()
        }
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/health")
async def health_check():
    try:
        with get_db_connection() as conn:
            # Get database stats
            total_users = conn.execute("SELECT COUNT(*) as count FROM fraud_profiles").fetchone()["count"]
            blacklisted_users = conn.execute("SELECT COUNT(*) as count FROM fraud_profiles WHERE is_blacklisted = 1").fetchone()["count"]
            high_risk_users = conn.execute("SELECT COUNT(*) as count FROM fraud_profiles WHERE current_risk_level IN ('HIGH', 'CRITICAL')").fetchone()["count"]
            total_transactions = conn.execute("SELECT COUNT(*) as count FROM transaction_history").fetchone()["count"]
            total_fraud_cases = conn.execute("SELECT SUM(total_fraud_count) as count FROM fraud_profiles").fetchone()["count"] or 0
            
            return {
                "status": "healthy",
                "service": "Nidhi-Rakshak Fraud Detection API with UPI Tracking",
                "version": "2.0.0",
                "active_upi_ids": total_users,
                "total_fraud_cases": total_fraud_cases,
                "database_stats": {
                    "total_users_tracked": total_users,
                    "blacklisted_users": blacklisted_users,
                    "high_risk_users": high_risk_users,
                    "total_transactions_processed": total_transactions
                },
                "features": {
                    "fraud_detection": "✅ Active",
                    "user_profiles": "✅ Active",
                    "partner_api": "✅ Active",
                    "blacklist_management": "✅ Active"
                }
            }
    except Exception as e:
        return {
            "status": "degraded",
            "error": str(e),
            "service": "Nidhi-Rakshak Fraud Detection API with UPI Tracking",
            "version": "2.0.0"
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

@app.post("/user-lookup")
async def user_fraud_lookup(request: UserLookupRequest):
    """
    Truecaller-like fraud lookup for partner apps
    Returns instant fraud risk assessment for a user
    """
    try:
        profile = get_user_fraud_profile(request.upi_id, request.partner_app_id)
        
        # Enhanced response with transaction-specific risk assessment
        response = {
            "user_profile": profile,
            "instant_assessment": {
                "safe_to_proceed": not profile["is_blacklisted"] and profile["risk_level"] not in ["CRITICAL"],
                "requires_verification": profile["risk_level"] in ["HIGH", "CRITICAL"],
                "recommended_action": profile["recommendation"]
            },
            "transaction_context": {},
            "timestamp": datetime.now().isoformat()
        }
        
        # Add transaction-specific assessment if amount provided
        if request.transaction_amount:
            # Risk adjustment based on transaction amount
            amount_risk = "LOW"
            if request.transaction_amount > 100000:
                amount_risk = "HIGH"
            elif request.transaction_amount > 50000:
                amount_risk = "MEDIUM"
            
            response["transaction_context"] = {
                "amount": request.transaction_amount,
                "amount_risk_level": amount_risk,
                "adjusted_recommendation": profile["recommendation"]
            }
            
            # Adjust recommendation based on amount and user risk
            if profile["is_blacklisted"] or (profile["risk_level"] == "CRITICAL" and request.transaction_amount > 50000):
                response["transaction_context"]["adjusted_recommendation"] = "BLOCK_TRANSACTION"
            elif profile["risk_level"] == "HIGH" and request.transaction_amount > 100000:
                response["transaction_context"]["adjusted_recommendation"] = "MANUAL_REVIEW_REQUIRED"
        
        return response
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Lookup failed: {str(e)}")

@app.get("/fraud-profile/{upi_id}")
async def get_detailed_fraud_profile(upi_id: str, partner_app_id: str = ""):
    """Get comprehensive fraud profile for a user"""
    try:
        with get_db_connection() as conn:
            # Get profile
            profile = conn.execute(
                "SELECT * FROM fraud_profiles WHERE upi_id = ?", (upi_id,)
            ).fetchone()
            
            if not profile:
                return {
                    "error": "User not found",
                    "upi_id": upi_id,
                    "status": "NO_HISTORY"
                }
            
            # Get recent transaction history
            recent_transactions = conn.execute(
                """SELECT * FROM transaction_history 
                   WHERE upi_id = ? 
                   ORDER BY timestamp DESC 
                   LIMIT 20""", (upi_id,)
            ).fetchall()
            
            # Get fraud trend (last 30 days)
            thirty_days_ago = (datetime.now() - timedelta(days=30)).isoformat()
            recent_frauds = conn.execute(
                """SELECT COUNT(*) as count FROM transaction_history 
                   WHERE upi_id = ? AND is_fraud = 1 AND timestamp > ?""", 
                (upi_id, thirty_days_ago)
            ).fetchone()
            
            return {
                "profile": {
                    "upi_id": profile["upi_id"],
                    "risk_level": profile["current_risk_level"],
                    "risk_score": profile["risk_score"],
                    "total_fraud_count": profile["total_fraud_count"],
                    "total_transactions": profile["total_transactions"],
                    "fraud_rate": profile["fraud_rate"],
                    "is_blacklisted": bool(profile["is_blacklisted"]),
                    "warning_flags": json.loads(profile["warning_flags"]) if profile["warning_flags"] else [],
                    "created_at": profile["created_at"],
                    "last_updated": profile["last_updated"]
                },
                "recent_activity": {
                    "transactions_last_30_days": len([t for t in recent_transactions if (datetime.now() - datetime.fromisoformat(t["timestamp"])).days <= 30]),
                    "frauds_last_30_days": recent_frauds["count"],
                    "latest_transactions": [dict(t) for t in recent_transactions[:10]]
                },
                "risk_indicators": {
                    "high_frequency_fraud": recent_frauds["count"] > 5,
                    "escalating_risk": profile["risk_score"] > 70,
                    "recent_activity": len(recent_transactions) > 0 and (datetime.now() - datetime.fromisoformat(recent_transactions[0]["timestamp"])).days <= 7
                }
            }
            
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Profile retrieval failed: {str(e)}")

@app.post("/blacklist/{upi_id}")
async def manually_blacklist_user(upi_id: str, reason: str = "Manual review", partner_app_id: str = ""):
    """Manually blacklist a user"""
    try:
        with get_db_connection() as conn:
            # Check if user exists
            profile = conn.execute(
                "SELECT * FROM fraud_profiles WHERE upi_id = ?", (upi_id,)
            ).fetchone()
            
            if not profile:
                # Create profile for new user
                conn.execute('''
                    INSERT INTO fraud_profiles 
                    (upi_id, total_fraud_count, total_transactions, fraud_rate, 
                     current_risk_level, risk_score, is_blacklisted, warning_flags, last_updated)
                    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
                ''', (upi_id, 0, 0, 0.0, "BLACKLISTED", 100.0, True, 
                      json.dumps([f"MANUAL_BLACKLIST: {reason}"]), datetime.now().isoformat()))
            else:
                # Update existing profile
                warning_flags = json.loads(profile["warning_flags"]) if profile["warning_flags"] else []
                warning_flags.append(f"MANUAL_BLACKLIST: {reason}")
                
                conn.execute('''
                    UPDATE fraud_profiles 
                    SET is_blacklisted = ?, current_risk_level = ?, risk_score = ?, 
                        warning_flags = ?, last_updated = ?
                    WHERE upi_id = ?
                ''', (True, "BLACKLISTED", 100.0, json.dumps(warning_flags), 
                      datetime.now().isoformat(), upi_id))
            
            # Log the action
            conn.execute('''
                INSERT INTO partner_access_logs (partner_app_id, upi_id, action, response_data)
                VALUES (?, ?, ?, ?)
            ''', (partner_app_id, upi_id, "MANUAL_BLACKLIST", reason))
            
            conn.commit()
            
            return {
                "status": "success",
                "message": f"User {upi_id} has been blacklisted",
                "reason": reason,
                "timestamp": datetime.now().isoformat()
            }
            
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Blacklisting failed: {str(e)}")

@app.get("/partner-stats/{partner_app_id}")
async def get_partner_usage_stats(partner_app_id: str):
    """Get usage statistics for a partner app"""
    try:
        with get_db_connection() as conn:
            # Get access logs for this partner
            logs = conn.execute(
                """SELECT COUNT(*) as total_requests, 
                          COUNT(DISTINCT upi_id) as unique_users,
                          MAX(timestamp) as last_access
                   FROM partner_access_logs 
                   WHERE partner_app_id = ?""", (partner_app_id,)
            ).fetchone()
            
            # Get recent activity
            recent_activity = conn.execute(
                """SELECT action, COUNT(*) as count 
                   FROM partner_access_logs 
                   WHERE partner_app_id = ? AND datetime(timestamp) > datetime('now', '-7 days')
                   GROUP BY action""", (partner_app_id,)
            ).fetchall()
            
            return {
                "partner_app_id": partner_app_id,
                "usage_stats": {
                    "total_requests": logs["total_requests"],
                    "unique_users_accessed": logs["unique_users"],
                    "last_access": logs["last_access"]
                },
                "recent_activity_7_days": [dict(activity) for activity in recent_activity],
                "generated_at": datetime.now().isoformat()
            }
            
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Stats retrieval failed: {str(e)}")

# ========== SERVICE MANAGEMENT ENDPOINTS ==========

@app.post("/register-partner")
async def register_partner_app(registration: PartnerAppRegistration):
    """Register a new partner app for fraud detection service"""
    try:
        import secrets
        
        # Generate API key if not provided
        api_key = registration.api_key or secrets.token_urlsafe(32)
        
        with get_db_connection() as conn:
            # Check if app_id already exists
            existing = conn.execute(
                "SELECT app_id FROM partner_apps WHERE app_id = ?", (registration.app_id,)
            ).fetchone()
            
            if existing:
                raise HTTPException(status_code=400, detail="App ID already registered")
            
            # Insert new partner app
            conn.execute('''
                INSERT INTO partner_apps 
                (app_id, app_name, contact_email, webhook_url, api_key)
                VALUES (?, ?, ?, ?, ?)
            ''', (registration.app_id, registration.app_name, registration.contact_email, 
                  registration.webhook_url, api_key))
            
            conn.commit()
            
            return {
                "status": "success",
                "message": "Partner app registered successfully",
                "app_details": {
                    "app_id": registration.app_id,
                    "app_name": registration.app_name,
                    "api_key": api_key,
                    "webhook_url": registration.webhook_url
                },
                "integration_endpoints": {
                    "user_lookup": "/user-lookup",
                    "transaction_validation": "/validate-transaction", 
                    "fraud_profile": "/fraud-profile/{upi_id}",
                    "partner_stats": f"/partner-stats/{registration.app_id}"
                },
                "timestamp": datetime.now().isoformat()
            }
            
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Registration failed: {str(e)}")

@app.post("/validate-transaction")
async def validate_transaction_realtime(request: TransactionValidationRequest):
    """Real-time transaction validation for partner apps"""
    try:
        # Verify partner app exists
        with get_db_connection() as conn:
            partner = conn.execute(
                "SELECT * FROM partner_apps WHERE app_id = ? AND is_active = 1", 
                (request.partner_app_id,)
            ).fetchone()
            
            if not partner:
                raise HTTPException(status_code=401, detail="Invalid or inactive partner app")
            
            # Update partner usage
            conn.execute(
                "UPDATE partner_apps SET total_requests = total_requests + 1, last_access = ? WHERE app_id = ?",
                (datetime.now().isoformat(), request.partner_app_id)
            )
            conn.commit()
        
        # Get user fraud profile
        profile = get_user_fraud_profile(request.upi_id, request.partner_app_id)
        
        # Transaction risk assessment
        transaction_risk = "LOW"
        risk_factors = []
        
        # Check for known fraudulent patterns in UPI IDs (both sender and recipient)
        fraudulent_patterns = ['fraud', 'scammer', 'fake', 'cheat', 'spam']
        if (any(pattern in request.upi_id.lower() for pattern in fraudulent_patterns) or 
            (request.recipient_upi_id and any(pattern in request.recipient_upi_id.lower() for pattern in fraudulent_patterns))):
            transaction_risk = "CRITICAL"
            risk_factors.append("SUSPICIOUS_UPI_ID")
        
        # Amount-based risk
        if request.transaction_amount > 100000:
            if transaction_risk == "LOW":
                transaction_risk = "HIGH"
            risk_factors.append("HIGH_AMOUNT")
        elif request.transaction_amount > 50000:
            if transaction_risk == "LOW":
                transaction_risk = "MEDIUM"
            risk_factors.append("MEDIUM_AMOUNT")
        
        # User risk-based assessment
        if profile["is_blacklisted"]:
            transaction_risk = "CRITICAL"
            risk_factors.append("BLACKLISTED_USER")
        elif profile["risk_level"] == "CRITICAL":
            transaction_risk = "CRITICAL"
            risk_factors.append("CRITICAL_USER_RISK")
        elif profile["risk_level"] == "HIGH":
            if transaction_risk == "LOW":
                transaction_risk = "MEDIUM"
            risk_factors.append("HIGH_USER_RISK")
        
        # Transaction type risk
        if request.transaction_type in ["CASH_OUT"] and request.transaction_amount > 25000:
            if transaction_risk in ["LOW", "MEDIUM"]:
                transaction_risk = "HIGH"
            risk_factors.append("SUSPICIOUS_CASH_OUT")
        
        # Final recommendation
        recommendation = "PROCEED"
        if transaction_risk == "CRITICAL":
            recommendation = "BLOCK_TRANSACTION"
        elif transaction_risk == "HIGH":
            recommendation = "MANUAL_REVIEW_REQUIRED"
        elif transaction_risk == "MEDIUM":
            recommendation = "PROCEED_WITH_CAUTION"
        
        # Should block transaction?
        should_block = profile["is_blacklisted"] or transaction_risk == "CRITICAL"
        
        response = {
            "validation_result": {
                "should_proceed": not should_block,
                "should_block": should_block,
                "transaction_risk": transaction_risk,
                "risk_factors": risk_factors,
                "recommendation": recommendation
            },
            "user_profile": {
                "upi_id": profile["upi_id"],
                "risk_level": profile["risk_level"],
                "fraud_score": profile["risk_score"],
                "is_blacklisted": profile["is_blacklisted"],
                "total_fraud_count": profile["fraud_count"]
            },
            "transaction_details": {
                "amount": request.transaction_amount,
                "type": request.transaction_type,
                "recipient": request.recipient_upi_id
            },
            "partner_info": {
                "app_id": request.partner_app_id,
                "app_name": partner["app_name"] if partner else "Unknown"
            },
            "timestamp": datetime.now().isoformat()
        }
        
        return response
        
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Transaction validation failed: {str(e)}")

@app.get("/service-stats")
async def get_service_statistics():
    """Get overall fraud detection service statistics"""
    try:
        with get_db_connection() as conn:
            # Get general stats
            total_users = conn.execute("SELECT COUNT(*) as count FROM fraud_profiles").fetchone()["count"]
            total_partners = conn.execute("SELECT COUNT(*) as count FROM partner_apps WHERE is_active = 1").fetchone()["count"]
            total_requests = conn.execute("SELECT SUM(total_requests) as total FROM partner_apps").fetchone()["total"] or 0
            blacklisted_users = conn.execute("SELECT COUNT(*) as count FROM fraud_profiles WHERE is_blacklisted = 1").fetchone()["count"]
            
            # Get risk distribution
            risk_distribution = conn.execute('''
                SELECT current_risk_level, COUNT(*) as count 
                FROM fraud_profiles 
                GROUP BY current_risk_level
            ''').fetchall()
            
            # Get top partner apps by usage
            top_partners = conn.execute('''
                SELECT app_name, app_id, total_requests 
                FROM partner_apps 
                WHERE is_active = 1 
                ORDER BY total_requests DESC 
                LIMIT 10
            ''').fetchall()
            
            return {
                "service_overview": {
                    "total_users_tracked": total_users,
                    "active_partner_apps": total_partners,
                    "total_api_requests": total_requests,
                    "blacklisted_users": blacklisted_users
                },
                "risk_distribution": [dict(row) for row in risk_distribution],
                "top_partner_apps": [dict(row) for row in top_partners],
                "service_health": "HEALTHY" if total_partners > 0 else "NO_PARTNERS",
                "generated_at": datetime.now().isoformat()
            }
            
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Service stats failed: {str(e)}")

@app.get("/partner-apps")
async def list_partner_apps():
    """List all registered partner apps"""
    try:
        with get_db_connection() as conn:
            partners = conn.execute('''
                SELECT app_id, app_name, contact_email, is_active, 
                       total_requests, created_at, last_access
                FROM partner_apps 
                ORDER BY created_at DESC
            ''').fetchall()
            
            return {
                "total_partners": len(partners),
                "partner_apps": [dict(partner) for partner in partners],
                "generated_at": datetime.now().isoformat()
            }
            
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to list partners: {str(e)}")

# ========== END SERVICE MANAGEMENT ENDPOINTS ==========

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