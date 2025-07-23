package com.example.myapp

import android.content.Context
import android.content.Intent
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

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        complianceChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, COMPLIANCE_CHANNEL)
        complianceChannel.setMethodCallHandler { call, result ->
            handleMethodCall(call, result)
        }
        
        createNotificationChannel()
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
            startForegroundService(intent)
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
}

