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

class MainActivity: FlutterActivity() {
    private val COMPLIANCE_CHANNEL = "com.ucobank.compliance"
    private lateinit var complianceChannel: MethodChannel
    private lateinit var securityReceiver: SecurityReceiver

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
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
            else -> {
                result.notImplemented()
            }
        }
    }

    private fun initializeComplianceMonitoring(result: Result) {
        try {
            // Start background compliance monitoring service
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
            
            // Broadcast compliance status to payment apps
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

    private fun setupSecurityReceiver() {
        securityReceiver = SecurityReceiver()
        val filter = IntentFilter().apply {
            addAction("com.ucobank.INITIALIZE_SECURITY")
            addAction("com.ucobank.APP_LAUNCH")
            addAction("com.ucobank.MFA_ATTEMPT")
            addAction("com.ucobank.TRANSACTION_CLEARANCE")
            addAction("com.ucobank.VALIDATE_TRANSACTION")
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
                    "com.ucobank.INITIALIZE_SECURITY" -> {
                        // Handle security initialization
                        val appId = it.getStringExtra("appId") ?: ""
                        complianceChannel.invokeMethod("securityInitialized", mapOf(
                            "appId" to appId,
                            "status" to "initialized"
                        ))
                    }
                    "com.ucobank.APP_LAUNCH" -> {
                        // Handle app launch report
                        val appPackage = it.getStringExtra("appPackage") ?: ""
                        complianceChannel.invokeMethod("appLaunchReported", mapOf(
                            "appPackage" to appPackage,
                            "timestamp" to it.getStringExtra("timestamp")
                        ))
                    }
                    "com.ucobank.MFA_ATTEMPT" -> {
                        // Handle MFA attempt report
                        val mfaType = it.getStringExtra("mfaType") ?: ""
                        val success = it.getBooleanExtra("success", false)
                        complianceChannel.invokeMethod("mfaAttemptReported", mapOf(
                            "mfaType" to mfaType,
                            "success" to success
                        ))
                    }
                    "com.ucobank.TRANSACTION_CLEARANCE" -> {
                        // Handle transaction clearance request
                        val transactionData = it.getStringExtra("transactionData") ?: ""
                        complianceChannel.invokeMethod("transactionClearanceRequested", mapOf(
                            "transactionData" to transactionData
                        ))
                    }
                }
            }
        }
    }
}
