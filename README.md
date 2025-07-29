# Nidhi-Rakshak Fraud Detection API

A sophisticated fraud detection system using machine learning for real-time transaction analysis.

## Features

- **93.73% Accuracy**: Advanced ML model with 24+ fraud indicators
- **Real-time API**: FastAPI-based REST API
- **Advanced Features**: Balance error detection, suspicious patterns, transaction analysis
- **Production Ready**: Scalable and deployable

## API Endpoints

- `GET /health` - Health check
- `POST /predict` - Fraud prediction
- `GET /docs` - Interactive API documentation

## Model Performance

- **Algorithm**: Gradient Boosting Classifier
- **ROC-AUC Score**: 93.73%
- **Training Data**: 50,000 synthetic transactions
- **Features**: 24 advanced fraud indicators

## Deployment

This API is designed to be deployed on cloud platforms like Render, Heroku, or similar services.

## Usage

```json
POST /predict
{
  "step": 1,
  "type": "TRANSFER",
  "amount": 50000,
  "oldbalanceOrg": 100000,
  "newbalanceOrig": 50000,
  "oldbalanceDest": 20000,
  "newbalanceDest": 70000
}
```

Response:
```json
{
  "is_fraud": true,
  "fraud_probability": 0.85,
  "confidence": 0.85
}
```
