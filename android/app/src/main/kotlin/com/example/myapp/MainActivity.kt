package com.example.myapp

import android.content.Context
import android.content.Intent
import android.content.BroadcastReceiver
import android.content.IntentFilter
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel.Result
import android.app.NotificationManager
import android.app.NotificationChannel
import android.os.Build
import android.os.Handler
import android.os.Looper

class MainActivity: FlutterActivity() {
    private val COMPLIANCE_CHANNEL = "com.ucobank.compliance"
    private lateinit var complianceChannel: MethodChannel
    private lateinit var securityReceiver: SecurityReceiver

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Register SecurityChecksPlugin
        val securityPlugin = SecurityChecksPlugin()
        securityPlugin.onAttachedToEngine(flutterEngine.dartExecutor.binaryMessenger, applicationContext)
        
        complianceChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, COMPLIANCE_CHANNEL)
        complianceChannel.setMethodCallHandler { call, result ->
            handleMethodCall(call, result)
        }
        
        createNotificationChannel()
        setupSecurityReceiver()
    }

    private fun handleMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "initializeComplianceMonitoring" -> {
                initializeComplianceMonitoring(result)
            }
            "notifyComplianceStatus" -> {
                val args = call.arguments as Map<String, Any>
                notifyComplianceStatus(args, result)
            }
            "validateTransactionFromNative" -> {
                val args = call.arguments as Map<String, Any>
                validateTransactionWithDartLogic(args, result)
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    private fun initializeComplianceMonitoring(result: Result) {
        try {
            val intent = Intent(this, ComplianceMonitoringService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                startForegroundService(intent)
            } else {
                startService(intent)
            }
            result.success(true)
        } catch (e: Exception) {
            result.error("INIT_ERROR", "Failed to initialize compliance monitoring", e.message)
        }
    }

    private fun notifyComplianceStatus(args: Map<String, Any>, result: Result) {
        try {
            val appId = args["appId"] as? String ?: ""
            val isCompliant = args["isCompliant"] as? Boolean ?: false
            val timestamp = args["timestamp"] as? String ?: ""
            
            val intent = Intent("com.ucobank.COMPLIANCE_STATUS")
            intent.putExtra("appId", appId)
            intent.putExtra("isCompliant", isCompliant)
            intent.putExtra("timestamp", timestamp)
            sendBroadcast(intent)
            
            result.success(true)
        } catch (e: Exception) {
            result.error("NOTIFY_ERROR", "Failed to notify compliance status", e.message)
        }
    }

    // FIXED: Proper MethodChannel call without lambda callback
    private fun validateTransactionWithDartLogic(args: Map<String, Any>, result: Result) {
        try {
            // Create a Result object to handle the response
            val dartValidationResult = object : MethodChannel.Result {
                override fun success(response: Any?) {
                    when (response) {
                        is Map<*, *> -> {
                            val responseMap = response as Map<String, Any>
                            
                            // Send response back to mock payment app
                            val responseIntent = Intent("com.ucobank.VALIDATION_RESPONSE")
                            responseIntent.putExtra("response", responseMap.toString())
                            responseIntent.putExtra("isValid", responseMap["isValid"] as? Boolean ?: false)
                            responseIntent.putExtra("message", responseMap["message"] as? String ?: "")
                            sendBroadcast(responseIntent)
                            
                            result.success(responseMap)
                        }
                        else -> {
                            result.error("VALIDATION_ERROR", "Invalid response from Dart validation", null)
                        }
                    }
                }

                override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
                    result.error("DART_VALIDATION_ERROR", "Dart validation failed: $errorMessage", errorDetails)
                }

                override fun notImplemented() {
                    result.error("NOT_IMPLEMENTED", "Dart validation method not implemented", null)
                }
            }
            
            // CORRECT: Call Dart validation with proper Result object
            complianceChannel.invokeMethod("validateTransactionFromNative", args, dartValidationResult)
            
        } catch (e: Exception) {
            result.error("DART_VALIDATION_ERROR", "Failed to call Dart validation: ${e.message}", null)
        }
    }

    private fun setupSecurityReceiver() {
        securityReceiver = SecurityReceiver()
        val filter = IntentFilter().apply {
            addAction("com.ucobank.INITIALIZE_SECURITY")
            addAction("com.ucobank.APP_LAUNCH")
            addAction("com.ucobank.MFA_ATTEMPT")
            addAction("com.ucobank.TRANSACTION_CLEARANCE")
            addAction("com.ucobank.VALIDATE_TRANSACTION")
            addAction("com.ucobank.VALIDATE_TRANSACTION_REAL")
            addAction("com.ucobank.CHECK_COMPLIANCE")
        }
        registerReceiver(securityReceiver, filter)
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                "COMPLIANCE_CHANNEL",
                "Compliance Monitoring",
                NotificationManager.IMPORTANCE_LOW
            )
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.createNotificationChannel(channel)
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        if (::securityReceiver.isInitialized) {
            unregisterReceiver(securityReceiver)
        }
    }

    inner class SecurityReceiver : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            intent?.let {
                when (it.action) {
                    "com.ucobank.VALIDATE_TRANSACTION_REAL" -> {
                        val transactionDataStr = it.getStringExtra("transactionData") ?: ""
                        handleRealTransactionValidation(transactionDataStr)
                    }
                    "com.ucobank.INITIALIZE_SECURITY" -> {
                        val appId = it.getStringExtra("appId") ?: ""
                        complianceChannel.invokeMethod("securityInitialized", mapOf(
                            "appId" to appId,
                            "status" to "initialized"
                        ))
                    }
                    "com.ucobank.APP_LAUNCH" -> {
                        val appPackage = it.getStringExtra("appPackage") ?: ""
                        complianceChannel.invokeMethod("appLaunchReported", mapOf(
                            "appPackage" to appPackage,
                            "timestamp" to it.getStringExtra("timestamp")
                        ))
                    }
                    "com.ucobank.MFA_ATTEMPT" -> {
                        val mfaType = it.getStringExtra("mfaType") ?: ""
                        val success = it.getBooleanExtra("success", false)
                        complianceChannel.invokeMethod("mfaAttemptReported", mapOf(
                            "mfaType" to mfaType,
                            "success" to success
                        ))
                    }
                    "com.ucobank.TRANSACTION_CLEARANCE" -> {
                        val transactionData = it.getStringExtra("transactionData") ?: ""
                        complianceChannel.invokeMethod("transactionClearanceRequested", mapOf(
                            "transactionData" to transactionData
                        ))
                    }
                }
            }
        }
        
        private fun handleRealTransactionValidation(transactionDataStr: String) {
            try {
                val transactionData = parseTransactionData(transactionDataStr)
                
                // FIXED: Create proper Result object for Dart call
                val dartValidationResult = object : MethodChannel.Result {
                    override fun success(response: Any?) {
                        val responseIntent = Intent("com.ucobank.VALIDATION_RESPONSE")
                        when (response) {
                            is Map<*, *> -> {
                                val responseMap = response as Map<String, Any>
                                responseIntent.putExtra("isValid", responseMap["isValid"] as? Boolean ?: false)
                                responseIntent.putExtra("message", responseMap["message"] as? String ?: "")
                                responseIntent.putExtra("violations", responseMap["violations"].toString())
                            }
                            else -> {
                                responseIntent.putExtra("isValid", false)
                                responseIntent.putExtra("message", "Invalid validation response")
                            }
                        }
                        sendBroadcast(responseIntent)
                    }

                    override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
                        val errorIntent = Intent("com.ucobank.VALIDATION_RESPONSE")
                        errorIntent.putExtra("isValid", false)
                        errorIntent.putExtra("message", "Validation error: $errorMessage")
                        sendBroadcast(errorIntent)
                    }

                    override fun notImplemented() {
                        val errorIntent = Intent("com.ucobank.VALIDATION_RESPONSE")
                        errorIntent.putExtra("isValid", false)
                        errorIntent.putExtra("message", "Validation method not implemented")
                        sendBroadcast(errorIntent)
                    }
                }
                
                // CORRECT: Call Dart compliance validation with proper Result object
                complianceChannel.invokeMethod("validateTransactionFromNative", transactionData, dartValidationResult)
                
            } catch (e: Exception) {
                val errorIntent = Intent("com.ucobank.VALIDATION_RESPONSE")
                errorIntent.putExtra("isValid", false)
                errorIntent.putExtra("message", "Validation failed: ${e.message}")
                sendBroadcast(errorIntent)
            }
        }
        
        private fun parseTransactionData(dataStr: String): Map<String, Any> {
            return try {
                val amount = extractAmountFromString(dataStr)
                mapOf(
                    "id" to "TXN_${System.currentTimeMillis()}",
                    "amount" to amount,
                    "fromAccount" to "12345678901234",
                    "toAccount" to "98765432109876",
                    "appId" to "com.example.mock_payment_app",
                    "timestamp" to System.currentTimeMillis().toString(),
                    "mfaCompleted" to false,
                    "transactionType" to "UPI"
                )
            } catch (e: Exception) {
                mapOf(
                    "id" to "ERROR_TXN",
                    "amount" to 0.0,
                    "error" to "Failed to parse transaction data"
                )
            }
        }
        
        private fun extractAmountFromString(dataStr: String): Double {
            return try {
                val regex = Regex("amount[\"']?:\\s*([0-9]+\\.?[0-9]*)")
                val match = regex.find(dataStr)
                match?.groupValues?.get(1)?.toDouble() ?: 150000.0 // Default large amount for testing
            } catch (e: Exception) {
                150000.0 // Default large amount for testing
            }
        }
    }
}
