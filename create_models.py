import joblib
import numpy as np
import pandas as pd
from sklearn.ensemble import RandomForestClassifier, GradientBoostingClassifier
from sklearn.model_selection import train_test_split, cross_val_score
from sklearn.preprocessing import StandardScaler, LabelEncoder
from sklearn.metrics import classification_report, confusion_matrix, roc_auc_score
from sklearn.utils import resample
import warnings
warnings.filterwarnings('ignore')

def create_advanced_features(df):
    """Creates the same advanced features as in the API"""
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
    
    # High amount flag
    df['high_amount'] = (df['amount'] > 100000).astype(np.int8)
    
    # Suspicious pattern flags
    df['round_amount'] = (df['amount'] % 1 == 0).astype(np.int8)
    df['exact_balance_transfer'] = (df['amount'] == df['oldbalanceOrg']).astype(np.int8)
    
    return df

def generate_realistic_fraud_data(n_samples=10000):
    """Generate realistic fraud detection dataset based on common fraud patterns"""
    print("Generating realistic fraud detection dataset...")
    
    np.random.seed(42)
    
    # Transaction types with their fraud probabilities
    transaction_types = ['TRANSFER', 'CASH_OUT', 'PAYMENT', 'CASH_IN', 'DEBIT']
    type_fraud_prob = {
        'TRANSFER': 0.15,    # Higher fraud rate
        'CASH_OUT': 0.20,    # Highest fraud rate
        'PAYMENT': 0.05,     # Lower fraud rate
        'CASH_IN': 0.02,     # Very low fraud rate
        'DEBIT': 0.08        # Medium fraud rate
    }
    
    data = []
    
    for i in range(n_samples):
        # Random transaction type
        trans_type = np.random.choice(transaction_types)
        
        # Generate step (time)
        step = np.random.randint(1, 743)
        
        # Generate amount based on transaction type
        if trans_type in ['TRANSFER', 'CASH_OUT']:
            # Higher amounts for these types
            amount = np.random.lognormal(10, 2)
        else:
            # Lower amounts for regular transactions
            amount = np.random.lognormal(8, 1.5)
        
        amount = max(1, amount)  # Ensure positive amount
        
        # Generate original balance
        oldbalanceOrg = np.random.lognormal(12, 1.5) if np.random.random() > 0.1 else 0
        
        # Generate destination balance
        oldbalanceDest = np.random.lognormal(11, 1.5) if np.random.random() > 0.2 else 0
        
        # Determine if this should be fraud based on type and patterns
        is_fraud = np.random.random() < type_fraud_prob[trans_type]
        
        # Generate fraud patterns
        if is_fraud:
            # Fraud patterns
            if np.random.random() < 0.3:  # Draining account
                amount = oldbalanceOrg * np.random.uniform(0.8, 1.0)
                newbalanceOrig = 0
            elif np.random.random() < 0.4:  # Suspicious round amounts
                amount = round(amount, -3)  # Round to nearest thousand
                newbalanceOrig = max(0, oldbalanceOrg - amount)
            else:  # Normal fraud transaction
                newbalanceOrig = max(0, oldbalanceOrg - amount)
            
            # Fraudulent transactions often don't update destination properly
            if np.random.random() < 0.6:
                newbalanceDest = oldbalanceDest  # No change (suspicious)
            else:
                newbalanceDest = oldbalanceDest + amount
        else:
            # Legitimate transactions
            newbalanceOrig = max(0, oldbalanceOrg - amount)
            
            if trans_type in ['TRANSFER', 'PAYMENT']:
                newbalanceDest = oldbalanceDest + amount
            else:
                newbalanceDest = oldbalanceDest
        
        data.append({
            'step': step,
            'type': trans_type,
            'amount': amount,
            'oldbalanceOrg': oldbalanceOrg,
            'newbalanceOrig': newbalanceOrig,
            'oldbalanceDest': oldbalanceDest,
            'newbalanceDest': newbalanceDest,
            'isFraud': int(is_fraud)
        })
    
    return pd.DataFrame(data)

def train_fraud_detection_model():
    """Train a sophisticated fraud detection model"""
    print("🚀 Training Real Fraud Detection Model")
    print("=" * 50)
    
    # Generate realistic dataset
    df = generate_realistic_fraud_data(50000)  # 50k samples for better training
    
    print(f"Dataset size: {len(df):,} transactions")
    print(f"Fraud rate: {df['isFraud'].mean():.2%}")
    print(f"Transaction types: {df['type'].value_counts().to_dict()}")
    
    # Create advanced features
    df = create_advanced_features(df)
    
    # Define feature columns (same as in app.py)
    feature_columns = [
        'step', 'amount', 'oldbalanceOrg', 'newbalanceOrig',
        'oldbalanceDest', 'newbalanceDest', 'balance_change_orig',
        'balance_change_dest', 'error_balance_orig', 'error_balance_dest',
        'orig_zero_after', 'dest_zero_before', 'orig_zero_before', 'dest_zero_after',
        'amount_to_orig_ratio', 'amount_to_dest_ratio', 'high_amount',
        'is_cash_out', 'is_transfer', 'is_payment', 'is_cash_in', 'is_debit',
        'round_amount', 'exact_balance_transfer'
    ]
    
    # Prepare features and target
    X = df[feature_columns]
    y = df['isFraud']
    
    print(f"\nFeatures: {len(feature_columns)}")
    print("Feature importance will be calculated after training...")
    
    # Split the data
    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=0.2, random_state=42, stratify=y
    )
    
    print(f"\nTraining set: {len(X_train):,} samples")
    print(f"Test set: {len(X_test):,} samples")
    
    # Scale the features
    scaler = StandardScaler()
    X_train_scaled = scaler.fit_transform(X_train)
    X_test_scaled = scaler.transform(X_test)
    
    # Train multiple models and select the best
    models = {
        'RandomForest': RandomForestClassifier(
            n_estimators=100,
            max_depth=15,
            min_samples_split=10,
            min_samples_leaf=5,
            random_state=42,
            n_jobs=-1
        ),
        'GradientBoosting': GradientBoostingClassifier(
            n_estimators=100,
            learning_rate=0.1,
            max_depth=6,
            random_state=42
        )
    }
    
    best_model = None
    best_score = 0
    best_name = ""
    
    print("\n🔍 Evaluating Models:")
    print("-" * 30)
    
    for name, model in models.items():
        # Cross-validation
        cv_scores = cross_val_score(model, X_train_scaled, y_train, cv=5, scoring='roc_auc')
        mean_score = cv_scores.mean()
        
        print(f"{name}:")
        print(f"  CV ROC-AUC: {mean_score:.4f} (±{cv_scores.std()*2:.4f})")
        
        if mean_score > best_score:
            best_score = mean_score
            best_model = model
            best_name = name
    
    print(f"\n🏆 Best Model: {best_name} (ROC-AUC: {best_score:.4f})")
    
    # Train the best model
    print(f"\n🔧 Training {best_name}...")
    best_model.fit(X_train_scaled, y_train)
    
    # Evaluate on test set
    y_pred = best_model.predict(X_test_scaled)
    y_pred_proba = best_model.predict_proba(X_test_scaled)[:, 1]
    
    test_auc = roc_auc_score(y_test, y_pred_proba)
    
    print(f"\n📊 Test Set Performance:")
    print(f"ROC-AUC Score: {test_auc:.4f}")
    print("\nClassification Report:")
    print(classification_report(y_test, y_pred))
    
    # Feature importance
    if hasattr(best_model, 'feature_importances_'):
        feature_importance = pd.DataFrame({
            'feature': feature_columns,
            'importance': best_model.feature_importances_
        }).sort_values('importance', ascending=False)
        
        print("\n🔍 Top 10 Most Important Features:")
        for idx, row in feature_importance.head(10).iterrows():
            print(f"  {row['feature']}: {row['importance']:.4f}")
    
    # Save the model and scaler
    print(f"\n💾 Saving trained model and scaler...")
    joblib.dump(best_model, 'fraud_model.joblib')
    joblib.dump(scaler, 'scaler.joblib')
    
    print("✅ Model training completed successfully!")
    print(f"📁 Files saved:")
    print(f"  - fraud_model.joblib ({best_name})")
    print(f"  - scaler.joblib")
    print(f"\n🎯 Model Performance Summary:")
    print(f"  - Algorithm: {best_name}")
    print(f"  - ROC-AUC Score: {test_auc:.4f}")
    print(f"  - Training Samples: {len(X_train):,}")
    print(f"  - Features: {len(feature_columns)}")
    
    return best_model, scaler, test_auc

if __name__ == "__main__":
    train_fraud_detection_model()
