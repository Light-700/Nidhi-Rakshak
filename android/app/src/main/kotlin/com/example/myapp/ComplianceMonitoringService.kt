package com.example.myapp

import android.app.Notification
import android.app.Service
import android.content.Intent
import android.os.IBinder
import android.os.Handler
import android.os.Looper
import androidx.core.app.NotificationCompat

class ComplianceMonitoringService : Service() {
    private val NOTIFICATION_ID = 1001
    private var monitoringHandler: Handler? = null
    private var monitoringRunnable: Runnable? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val notification = createNotification()
        startForeground(NOTIFICATION_ID, notification)
        
        // Start actual monitoring logic
        startComplianceMonitoring()
        
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun createNotification(): Notification {
        return NotificationCompat.Builder(this, "COMPLIANCE_CHANNEL")
            .setContentTitle("Financial Security Monitor")
            .setContentText("Monitoring compliance for financial apps")
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOngoing(true)
            .build()
    }

    private fun startComplianceMonitoring() {
        monitoringHandler = Handler(Looper.getMainLooper())
        monitoringRunnable = object : Runnable {
            override fun run() {
                performComplianceCheck()
                // Check every 5 minutes
                monitoringHandler?.postDelayed(this, 300000)
            }
        }
        monitoringHandler?.post(monitoringRunnable!!)
    }

    private fun performComplianceCheck() {
    val intent = Intent("com.ucobank.VALIDATE_TRANSACTION_REAL")
    intent.putExtra("timestamp", System.currentTimeMillis())
    intent.putExtra("source", "periodic_check")
    sendBroadcast(intent)
    }

    override fun onDestroy() {
        super.onDestroy()
        monitoringHandler?.removeCallbacks(monitoringRunnable!!)
    }
}
