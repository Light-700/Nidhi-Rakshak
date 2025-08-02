package com.example.myapp

import android.content.Context
import android.content.pm.ApplicationInfo
import android.content.pm.PackageInfo
import android.content.pm.PackageManager
import android.os.Build
import android.provider.Settings
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.io.File
import java.util.*

/**
 * SecurityChecksPlugin
 *
 * Plugin that provides native security checks for the Flutter app
 */
class SecurityChecksPlugin: MethodCallHandler {
  /// The MethodChannel that will the communication between Flutter and native Android
  private lateinit var channel: MethodChannel
  private lateinit var context: Context
  
  companion object {
    // List of dangerous permissions that could indicate malicious apps
    private val DANGEROUS_PERMISSIONS = listOf(
      "android.permission.READ_SMS",
      "android.permission.RECEIVE_SMS",
      "android.permission.SEND_SMS",
      "android.permission.PROCESS_OUTGOING_CALLS",
      "android.permission.CALL_PHONE",
      "android.permission.READ_CALL_LOG",
      "android.permission.WRITE_CALL_LOG",
      "android.permission.SYSTEM_ALERT_WINDOW",
      "android.permission.GET_ACCOUNTS",
      "android.permission.READ_CONTACTS",
      "android.permission.WRITE_CONTACTS",
      "android.permission.RECORD_AUDIO",
      "android.permission.CAMERA",
      "android.permission.ACCESS_FINE_LOCATION",
      "android.permission.ACCESS_BACKGROUND_LOCATION",
      "android.permission.READ_EXTERNAL_STORAGE",
      "android.permission.WRITE_EXTERNAL_STORAGE"
    )
    
    // High-risk combinations of permissions that may indicate malicious behavior
    private val DANGEROUS_PERMISSION_COMBINATIONS = mapOf(
      "SMS and Call Logger" to listOf(
        "android.permission.READ_SMS",
        "android.permission.READ_CALL_LOG"
      ),
      "Call and SMS Interceptor" to listOf(
        "android.permission.RECEIVE_SMS",
        "android.permission.PROCESS_OUTGOING_CALLS"
      ),
      "Location and Recording" to listOf(
        "android.permission.ACCESS_FINE_LOCATION",
        "android.permission.RECORD_AUDIO"
      ),
      "Full Communication Access" to listOf(
        "android.permission.READ_CONTACTS",
        "android.permission.SEND_SMS",
        "android.permission.CALL_PHONE"
      ),
      "Overlay and Accessibility" to listOf(
        "android.permission.SYSTEM_ALERT_WINDOW",
        "android.permission.BIND_ACCESSIBILITY_SERVICE"
      )
    )
    
    // Known legitimate financial apps
    private val LEGITIMATE_FINANCIAL_APPS = mapOf(
      "com.ucobank.mobile" to "UCO Bank",
      "com.sbi.lotusintouch" to "SBI YONO",
      "com.hdfc.hdfcbank" to "HDFC Bank",
      "com.csam.icici.bank.imobile" to "ICICI iMobile",
      "com.bankofbaroda.mconnect" to "Bank of Baroda",
      "com.axisbank.mobilebanking" to "Axis Mobile",
      "com.google.android.apps.nbu.paisa.user" to "Google Pay",
      "in.org.npci.upiapp" to "BHIM",
      "net.one97.paytm" to "Paytm",
      "com.phonepe.app" to "PhonePe",
      "in.amazon.mShop.android.shopping" to "Amazon"
    )
  }

  fun onAttachedToEngine(binaryMessenger: BinaryMessenger, applicationContext: Context) {
    context = applicationContext
    channel = MethodChannel(binaryMessenger, "com.nidhi_rakshak/security_checks")
    channel.setMethodCallHandler(this)
  }

  override fun onMethodCall(call: MethodCall, result: Result) {
    when (call.method) {
      "isDeveloperModeEnabled" -> {
        result.success(isDeveloperOptionsEnabled())
      }
      "getAndroidSettingsInt" -> {
        val settingsType = call.argument<String>("settingsType")
        val settingsKey = call.argument<String>("settingsKey")
        val defaultValue = call.argument<Int>("defaultValue") ?: 0
        
        if (settingsType == null || settingsKey == null) {
          result.error("INVALID_ARGUMENTS", "settingsType and settingsKey must be provided", null)
          return
        }
        
        result.success(getSettingsInt(settingsType, settingsKey, defaultValue))
      }
      "getAppPermissions" -> {
        val packageName = call.argument<String>("packageName")
        if (packageName == null) {
          result.error("INVALID_ARGUMENTS", "packageName must be provided", null)
          return
        }
        
        try {
          result.success(getAppPermissions(packageName))
        } catch (e: Exception) {
          result.error("PERMISSION_ERROR", "Failed to get app permissions: ${e.message}", null)
        }
      }
      "calculateAppRiskScore" -> {
        val packageName = call.argument<String>("packageName")
        if (packageName == null) {
          result.error("INVALID_ARGUMENTS", "packageName must be provided", null)
          return
        }
        
        try {
          result.success(calculateAppRiskScore(packageName))
        } catch (e: Exception) {
          result.error("RISK_SCORE_ERROR", "Failed to calculate risk score: ${e.message}", null)
        }
      }
      "detectSuspiciousApps" -> {
        try {
          result.success(detectSuspiciousApps())
        } catch (e: Exception) {
          result.error("SUSPICIOUS_APPS_ERROR", "Failed to detect suspicious apps: ${e.message}", null)
        }
      }
      // Add more methods as needed
      else -> {
        result.notImplemented()
      }
    }
  }

  private fun isDeveloperOptionsEnabled(): Boolean {
    return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.JELLY_BEAN_MR1) {
      // Android 4.2 and above
      Settings.Global.getInt(context.contentResolver,
        Settings.Global.DEVELOPMENT_SETTINGS_ENABLED, 0) != 0
    } else {
      // For older devices
      Settings.Secure.getInt(context.contentResolver,
        Settings.Secure.DEVELOPMENT_SETTINGS_ENABLED, 0) != 0
    }
  }

  private fun getSettingsInt(settingsType: String, settingsKey: String, defaultValue: Int): Int {
    return try {
      when (settingsType) {
        "Global" -> Settings.Global.getInt(context.contentResolver, settingsKey, defaultValue)
        "Secure" -> Settings.Secure.getInt(context.contentResolver, settingsKey, defaultValue)
        "System" -> Settings.System.getInt(context.contentResolver, settingsKey, defaultValue)
        else -> defaultValue
      }
    } catch (e: Settings.SettingNotFoundException) {
      defaultValue
    }
  }

  fun onDetachedFromEngine() {
    channel.setMethodCallHandler(null)
  }
  
  /**
   * Get all permissions requested by the app in its manifest
   */
  private fun getAppPermissions(packageName: String): List<String> {
    val packageManager = context.packageManager
    try {
      val packageInfo = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
        packageManager.getPackageInfo(packageName, PackageManager.PackageInfoFlags.of(PackageManager.GET_PERMISSIONS.toLong()))
      } else {
        @Suppress("DEPRECATION")
        packageManager.getPackageInfo(packageName, PackageManager.GET_PERMISSIONS)
      }
      
      return packageInfo.requestedPermissions?.toList() ?: listOf()
    } catch (e: Exception) {
      return listOf()
    }
  }
  
  /**
   * Calculate risk score for an app based on multiple factors
   */
  private fun calculateAppRiskScore(packageName: String): Map<String, Any> {
    var riskScore = 0
    val riskFactors = mutableListOf<String>()
    val packageManager = context.packageManager
    
    try {
      // Get app information
      val appInfo = packageManager.getApplicationInfo(packageName, 0)
      val appLabel = packageManager.getApplicationLabel(appInfo).toString()
      
      // Skip our own app and system apps
      if (packageName == context.packageName || 
          (appInfo.flags and ApplicationInfo.FLAG_SYSTEM) != 0) {
        return mapOf(
          "packageName" to packageName,
          "appName" to appLabel,
          "riskScore" to 0,
          "riskLevel" to "Safe",
          "riskFactors" to listOf<String>(),
          "isSystemApp" to ((appInfo.flags and ApplicationInfo.FLAG_SYSTEM) != 0)
        )
      }
      
      // 1. Permission-based risk (max 50 points)
      val permissions = getAppPermissions(packageName)
      val dangerousPermCount = countDangerousPermissions(permissions)
      
      if (dangerousPermCount > 0) {
        val points = minOf(dangerousPermCount * 10, 50)
        riskScore += points
        riskFactors.add("Has $dangerousPermCount dangerous permissions")
      }
      
      // 2. Permission combination risk (max 30 points)
      val dangerousCombo = checkDangerousPermissionCombinations(permissions)
      if (dangerousCombo.isNotEmpty()) {
        riskScore += 30
        riskFactors.add("Has suspicious permission combination: $dangerousCombo")
      }
      
      // 3. Installation source risk (max 20 points)
      if (!isInstalledFromPlayStore(packageName)) {
        riskScore += 20
        riskFactors.add("Not installed from Play Store")
      }
      
      // 4. Financial app impersonation risk (max 50 points)
      val impersonationRisk = checkFinancialAppImpersonation(packageName, appLabel)
      if (impersonationRisk.isNotEmpty()) {
        riskScore += 50
        riskFactors.add(impersonationRisk)
      }
      
      // Risk classification
      val riskLevel = when {
        riskScore >= 70 -> "Critical"
        riskScore >= 50 -> "High"
        riskScore >= 30 -> "Medium"
        riskScore >= 10 -> "Low"
        else -> "Safe"
      }
      
      return mapOf(
        "packageName" to packageName,
        "appName" to appLabel,
        "riskScore" to riskScore,
        "riskLevel" to riskLevel,
        "riskFactors" to riskFactors,
        "isSystemApp" to ((appInfo.flags and ApplicationInfo.FLAG_SYSTEM) != 0)
      )
    } catch (e: Exception) {
      return mapOf(
        "packageName" to packageName,
        "appName" to "Unknown",
        "riskScore" to 0,
        "riskLevel" to "Unknown",
        "riskFactors" to listOf("Error analyzing app: ${e.message}"),
        "isSystemApp" to false
      )
    }
  }
  
  /**
   * Check if an app's name or package suggests it might be impersonating 
   * a legitimate financial app
   */
  private fun checkFinancialAppImpersonation(packageName: String, appLabel: String): String {
    val appLabelLower = appLabel.lowercase(Locale.ROOT)
    
    // Skip if it's a legitimate financial app
    if (LEGITIMATE_FINANCIAL_APPS.containsKey(packageName)) {
      return ""
    }
    
    // Check for financial keywords in the app name
    val financialKeywords = listOf("bank", "upi", "pay", "wallet", "finance", "money", "transaction", "loan")
    val containsFinancialKeyword = financialKeywords.any { appLabelLower.contains(it) }
    
    if (!containsFinancialKeyword) {
      return ""
    }
    
    // Check if app name is similar to any legitimate financial app
    for ((_, bankName) in LEGITIMATE_FINANCIAL_APPS) {
      val bankNameLower = bankName.lowercase(Locale.ROOT)
      val similarity = calculateNameSimilarity(bankNameLower, appLabelLower)
      
      if (similarity > 0.6) {  // More than 60% similar
        return "Potential impersonation of $bankName"
      }
      
      // Check for partial name inclusion
      val bankWords = bankNameLower.split(" ", "-", "_")
      for (word in bankWords) {
        if (word.length > 3 && appLabelLower.contains(word)) {
          return "Contains name similar to $bankName"
        }
      }
    }
    
    return if (containsFinancialKeyword) "Unverified financial app" else ""
  }
  
  /**
   * Calculate similarity between two strings (simple algorithm)
   */
  private fun calculateNameSimilarity(s1: String, s2: String): Double {
    if (s1 == s2) return 1.0
    if (s1.isEmpty() || s2.isEmpty()) return 0.0
    
    // Count matching characters
    var matches = 0
    val s1Set = s1.toSet()
    val s2Set = s2.toSet()
    
    for (c in s1Set) {
      if (c in s2Set) matches++
    }
    
    return matches.toDouble() / maxOf(s1Set.size, s2Set.size)
  }
  
  /**
   * Check if app was installed from Google Play Store
   */
  private fun isInstalledFromPlayStore(packageName: String): Boolean {
    val packageManager = context.packageManager
    val installerPackageName = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
      val installerInfo = packageManager.getInstallSourceInfo(packageName)
      installerInfo.initiatingPackageName
    } else {
      @Suppress("DEPRECATION")
      packageManager.getInstallerPackageName(packageName)
    }
    
    return installerPackageName == "com.android.vending" || // Google Play Store
           installerPackageName == "com.google.android.packageinstaller" // System installer
  }
  
  /**
   * Count how many permissions from the dangerous list the app has
   */
  private fun countDangerousPermissions(permissions: List<String>): Int {
    var count = 0
    for (permission in permissions) {
      if (permission in DANGEROUS_PERMISSIONS) {
        count++
      }
    }
    return count
  }
  
  /**
   * Check for dangerous permission combinations
   */
  private fun checkDangerousPermissionCombinations(permissions: List<String>): String {
    for ((comboName, comboPermissions) in DANGEROUS_PERMISSION_COMBINATIONS) {
      var hasAllPermissions = true
      for (permission in comboPermissions) {
        if (permission !in permissions) {
          hasAllPermissions = false
          break
        }
      }
      
      if (hasAllPermissions) {
        return comboName
      }
    }
    return ""
  }
  
  /**
   * Scan all installed apps and return list of suspicious apps
   */
  private fun detectSuspiciousApps(): List<Map<String, Any>> {
    val suspiciousApps = mutableListOf<Map<String, Any>>()
    val packageManager = context.packageManager
    
    try {
      // Get all installed applications
      val installedApps = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
        packageManager.getInstalledApplications(PackageManager.ApplicationInfoFlags.of(0))
      } else {
        @Suppress("DEPRECATION")
        packageManager.getInstalledApplications(0)
      }
      
      // Filter out system apps 
      val nonSystemApps = installedApps.filter { appInfo ->
        (appInfo.flags and ApplicationInfo.FLAG_SYSTEM) == 0 && 
        appInfo.packageName != context.packageName
      }
      
      // Analyze each app
      for (appInfo in nonSystemApps) {
        val riskInfo = calculateAppRiskScore(appInfo.packageName)
        val riskLevel = riskInfo["riskLevel"] as String
        
        if (riskLevel != "Safe" && riskLevel != "Unknown") {
          suspiciousApps.add(riskInfo)
        }
      }
      
      // Sort by risk score (highest first)
      return suspiciousApps.sortedByDescending { it["riskScore"] as Int }
      
    } catch (e: Exception) {
      e.printStackTrace()
      return listOf(mapOf("error" to "Failed to scan apps: ${e.message}"))
    }
  }
}
