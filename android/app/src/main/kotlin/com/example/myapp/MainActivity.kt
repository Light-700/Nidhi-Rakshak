package com.example.myapp

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.util.Log
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel.Result
import java.time.ZoneOffset
import java.time.ZonedDateTime
import java.time.format.DateTimeFormatter
import org.json.JSONObject
import org.json.JSONException

class MainActivity: FlutterActivity() {
    // Define a single, clear channel name for all compliance communication
    private val COMPLIANCE_CHANNEL = "com.ucobank.compliance"
    private lateinit var complianceChannel: MethodChannel
    private var securityReceiver: SecurityReceiver? = null

    /**
     * This is the single, correct configuration for the Flutter engine.
     * It merges the duplicate code and sets up all necessary channels and plugins.
     */
override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    createNotificationChannels()
    
    // Register SecurityChecksPlugin with correct channel
    SecurityChecksPlugin().onAttachedToEngine(
        flutterEngine.dartExecutor.binaryMessenger, 
        applicationContext
    )
    
    // Setup compliance channel
    complianceChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, COMPLIANCE_CHANNEL)
    complianceChannel.setMethodCallHandler { call, result ->
        handleMethodCall(call, result)
    }
    
    setupSecurityReceiver()
}


    
    /**
     * Creates the notification channels required for the app.
     * This is required for Android 8.0 (API level 26) and higher.
     */
    private fun createNotificationChannels() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val complianceChannel = android.app.NotificationChannel(
                "COMPLIANCE_CHANNEL",
                "Compliance Monitoring",
                android.app.NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Used for compliance monitoring services"
                enableLights(false)
                enableVibration(false)
            }
            
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as android.app.NotificationManager
            notificationManager.createNotificationChannel(complianceChannel)
            Log.d("MainActivity", "Notification channel created: COMPLIANCE_CHANNEL")
            
            // For Android 13+, we need to request notification permissions
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                if (checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS) != android.content.pm.PackageManager.PERMISSION_GRANTED) {
                    requestPermissions(arrayOf(android.Manifest.permission.POST_NOTIFICATIONS), 100)
                }
            }
        }
    }

    /**
     * Handles all method calls invoked from the Dart side of the application.
     */
    private fun handleMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "initializeComplianceMonitoring" -> {
                // This method is preserved to allow Dart to start the background service
                initializeComplianceMonitoring(result)
            }
            "validateTransaction" -> {
                // This allows Dart to request validation for a transaction it originates
                val transactionData = call.arguments as? Map<String, Any>
                if (transactionData != null) {
                    handleRealTransactionValidation(transactionData, result)
                } else {
                    result.error("INVALID_ARGUMENTS", "Transaction data is required", null)
                }
            }
            else -> {
                // Handles any other methods that might be called
                Log.w("MethodHandler", "Method '${call.method}' not implemented on native side.")
                result.notImplemented()
            }
        }
    }

    /**
     * Starts the background ComplianceMonitoringService.
     * This is preserved from your original code.
     */
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
            Log.e("ComplianceInit", "Failed to initialize compliance monitoring", e)
            result.error("INIT_ERROR", "Failed to initialize compliance monitoring", e.message)
        }
    }

    /**
     * Sets up the broadcast receiver to listen for transaction validation requests.
     */
    private fun setupSecurityReceiver() {
        if (securityReceiver != null) return

        securityReceiver = SecurityReceiver()
        val filter = IntentFilter().apply {
            // This is the primary action your AccessibilityService should broadcast
            addAction("com.ucobank.VALIDATE_TRANSACTION_REAL")
            addAction("com.ucobank.PERIODIC_COMPLIANCE_CHECK")
            // Other actions are preserved from your original code
            addAction("com.ucobank.INITIALIZE_SECURITY")
            addAction("com.ucobank.APP_LAUNCH")
        }
        
        // For Android 14+ (API level 34+), we need to specify RECEIVER_NOT_EXPORTED
        // since this receiver is for internal app communication only
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(securityReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(securityReceiver, filter)
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        // Unregister the receiver to prevent memory leaks
        securityReceiver?.let { unregisterReceiver(it) }
    }

    /**
     * Inner class that listens for broadcasts from other parts of the Android system.
     */
    inner class SecurityReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context?, intent: Intent?) {
        Log.d("FinancialEnv", "=== BROADCAST RECEIVED ===")
        Log.d("FinancialEnv", "Intent action: ${intent?.action}")
        Log.d("FinancialEnv", "Intent extras: ${intent?.extras}")
        
        if (intent?.action == "com.ucobank.VALIDATE_TRANSACTION_REAL") {
            val transactionJson = intent.getStringExtra("transactionData")
            Log.d("FinancialEnv", "Transaction data: $transactionJson")
            
            if (transactionJson != null) {
                val transactionData = parseTransactionData(transactionJson)
                Log.d("FinancialEnv", "Parsed data: $transactionData")
                handleRealTransactionValidation(transactionData, null)
            } else {
                Log.e("FinancialEnv", "No transaction data received!")
            }
        }
    }
}



    /**
     * The core validation logic that invokes the Dart method.
     * Can be called from a broadcast or directly from another method call.
     */
    private fun handleRealTransactionValidation(transactionData: Map<String, Any?>, channelResult: Result?) {
        if (transactionData["error"] != null) {
            Log.e("Validation", "Cannot validate transaction due to parsing error: ${transactionData["error"]}")
            channelResult?.error("PARSING_ERROR", "Could not parse transaction data", transactionData["error"])
            return
        }
        
        Log.d("Validation", "Invoking Dart 'validateTransaction' with data: $transactionData")
        
        // Invoke the 'validateTransaction' method in your Dart code
        complianceChannel.invokeMethod("validateTransaction", transactionData, object : MethodChannel.Result {
            private fun broadcastResponse(isValid: Boolean, message: String) {
                val responseIntent = Intent("com.ucobank.VALIDATION_RESPONSE").apply {
                    putExtra("isValid", isValid)
                    putExtra("message", message)
                }
                sendBroadcast(responseIntent)
            }

            override fun success(response: Any?) {
                val responseMap = response as? Map<String, Any>
                val isValid = responseMap?.get("isValid") as? Boolean ?: false
                val message = responseMap?.get("message") as? String ?: "Validation successful"
                Log.d("Validation", "Success from Dart: $message")
                broadcastResponse(isValid, message)
                channelResult?.success(response)
            }

            override fun error(errorCode: String, errorMessage: String?, errorDetails: Any?) {
                Log.e("Validation", "Error from Dart: $errorCode - $errorMessage")
                broadcastResponse(false, "Validation failed: $errorMessage")
                channelResult?.error(errorCode, errorMessage, errorDetails)
            }

            override fun notImplemented() {
                Log.e("Validation", "Dart method 'validateTransaction' is not implemented.")
                broadcastResponse(false, "Validation method not implemented on Dart side.")
                channelResult?.notImplemented()
            }
        })
    }

    /**
     * This function now robustly parses a JSON string instead of using a fragile regex.
     * This is the key fix to ensure reliable data is sent to Dart.
     */
    private fun parseTransactionData(jsonString: String): Map<String, Any?> {
        // ================================ IMPORTANT FIX =================================
        // Your AccessibilityService MUST capture transaction details and construct a JSON string.
        // This function will now safely parse it.
        //
        // EXAMPLE of an expected JSON string:
        // {
        //   "id": "TXN_2023102801",
        //   "amount": 125000.0,
        //   "fromAccount": "user_account_num",
        //   "toAccount": "recipient_account_num",
        //   "appId": "com.google.android.apps.nbu.paisa.user", // The actual payment app
        //   "mfaCompleted": true,
        //   "mfaMethod": "BIOMETRIC"
        // }
        // ===========================================================================
        try {
            val json = JSONObject(jsonString)
            val timestamp = ZonedDateTime.now(ZoneOffset.UTC).format(DateTimeFormatter.ISO_INSTANT)

            return mapOf(
                "id" to json.optString("id", "TXN_${System.currentTimeMillis()}"),
                "amount" to json.optDouble("amount", 0.0),
                "fromAccount" to json.optString("fromAccount", "UNKNOWN"),
                "toAccount" to json.optString("toAccount", "UNKNOWN"),
                "appId" to json.optString("appId", "UNKNOWN"),
                "timestamp" to timestamp,
                "mfaCompleted" to json.optBoolean("mfaCompleted", false),
                "mfaMethod" to if (json.has("mfaMethod")) json.getString("mfaMethod") else null,
                "transactionType" to "UPI"
            )
        } catch (e: JSONException) {
            Log.e("ParseException", "Failed to parse transaction JSON: $jsonString", e)
            return mapOf("error" to "Invalid JSON format: ${e.message}")
        }
    }
}
