# 🛡️ Nidhi-Rakshak Fraud Detection API

## 🚀 **Cloud-Ready Fraud Detection System**

This is the production-ready deployment of the Nidhi-Rakshak fraud detection API, featuring:

### ✅ **Core Features**
- **Real-time fraud detection** with enhanced UPI pattern matching
- **Machine Learning** fraud prediction models
- **RESTful API** with comprehensive endpoints
- **SQLite database** for fraud profiles and transaction history
- **Partner app integration** for seamless UPI fraud checks

### 🎯 **Enhanced Detection Capabilities**
- **Sender & Recipient UPI checks** for suspicious patterns
- **Risk level classification**: LOW, MEDIUM, HIGH, CRITICAL
- **Pattern-based detection** for fraud keywords
- **Transaction amount analysis** with risk escalation
- **Real-time validation** with instant response

### 🔧 **API Endpoints**
- `GET /` - API documentation
- `GET /health` - Health check
- `POST /validate-transaction` - Real-time fraud validation
- `POST /user-lookup` - User fraud profile lookup
- `GET /fraud-profile/{upi_id}` - Detailed fraud profile
- `POST /predict` - ML-based fraud prediction

### 🌐 **Deployment Ready**
- **FastAPI** framework with uvicorn server
- **Production optimized** with proper error handling
- **Auto-scaling** compatible with cloud platforms
- **HTTPS ready** for secure transactions
- **Health monitoring** with built-in health checks

### 📱 **Integration**
Compatible with Flutter apps and any HTTP client for:
- UPI payment validation
- Real-time fraud warnings
- Transaction risk assessment
- User fraud profile checks

---

**Live API Documentation**: Available at deployed URL root (`/`)  
**Health Check**: Available at `/health`  
**Built for**: 24/7 fraud protection in UPI payment systems
