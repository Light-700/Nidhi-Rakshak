package com.nidhi_rakshak.app

import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageInfo
import android.content.pm.PackageManager
import android.os.Build
import android.provider.Settings
import android.util.Log
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.util.Locale
import org.json.JSONObject

/**
 * SecurityChecksPlugin
 *
 * Plugin that provides native security checks for the Flutter app
 */
class SecurityChecksPlugin: MethodCallHandler {
  /// The MethodChannel that will the communication between Flutter and native Android
  private lateinit var channel: MethodChannel
  private lateinit var context: Context
  
  // Cache for intent analysis to improve performance
  private val intentAnalysisCache = mutableMapOf<String, Pair<List<String>, Long>>()
  private val CACHE_DURATION_MS = 3600000 // 1 hour
  
  companion object {
    // Define app categories for context-aware analysis
    enum class AppCategory {
      COMMUNICATION, SOCIAL, FINANCE, PRODUCTIVITY, UTILITY, PHOTOGRAPHY, GAMING, UNKNOWN
    }
    
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
        "android.permission.PROCESS_OUTGOING_CALLS",
        "android.permission.RECEIVE_SMS"
      ),
      "Location and Recording" to listOf(
        "android.permission.ACCESS_FINE_LOCATION",
        "android.permission.RECORD_AUDIO"
      ),
      "Financial Data Access" to listOf(
        "android.permission.READ_SMS", // For OTP interception
        "android.permission.INTERNET"  // To send data out
      )
    )
    
    // Known legitimate financial apps (to prevent false positives)
    private val LEGITIMATE_FINANCIAL_APPS = mapOf(
      "com.ucobank.mobile" to "UCO Bank",
      "com.sbi.lotusintouch" to "SBI YONO",
      "com.icicibank.pockets" to "ICICI iMobile",
      "com.phonepe.app" to "PhonePe",
      "net.one97.paytm" to "Paytm",
      "com.google.android.apps.nbu.paisa.user" to "Google Pay"
    )
    
    // Known trusted app stores
    private val TRUSTED_APP_STORES = listOf(
      "com.android.vending",          // Google Play Store
      "com.amazon.venezia",           // Amazon App Store
      "com.sec.android.app.samsungapps", // Samsung Galaxy Store
      "com.huawei.appmarket"          // Huawei AppGallery
    )
  }

  fun onAttachedToEngine(binaryMessenger: BinaryMessenger, applicationContext: Context) {
    context = applicationContext
    channel = MethodChannel(binaryMessenger, "com.nidhi_rakshak.app/security_checks")
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
          val riskAssessment = calculateAppRiskScore(packageName)
          result.success(riskAssessment)
        } catch (e: Exception) {
          result.error("RISK_ASSESSMENT_ERROR", "Failed to calculate app risk: ${e.message}", null)
        }
      }
      "detectSuspiciousApps" -> {
        try {
          val suspiciousApps = detectSuspiciousApps()
          result.success(suspiciousApps)
        } catch (e: Exception) {
          result.error("SUSPICIOUS_APPS_ERROR", "Failed to detect suspicious apps: ${e.message}", null)
        }
      }
      "checkHarmfulApps" -> {
        // Implement the harmful apps check using permission analysis
        try {
          result.success(detectHarmfulApps())
        } catch (e: Exception) {
          result.error("HARMFUL_APPS_ERROR", "Failed to check for harmful apps: ${e.message}", null)
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
        packageManager.getPackageInfo(packageName, android.content.pm.PackageManager.PackageInfoFlags.of(android.content.pm.PackageManager.GET_PERMISSIONS.toLong()))
      } else {
        @Suppress("DEPRECATION")
        packageManager.getPackageInfo(packageName, android.content.pm.PackageManager.GET_PERMISSIONS)
      }
      
      return packageInfo.requestedPermissions?.toList() ?: listOf()
    } catch (e: Exception) {
      return listOf()
    }
  }
  
  /**
   * Calculate app risk score by combining all three approaches:
   * 1. Intent-Based Analysis (20%)
   * 2. Context-Aware Permission Analysis (40%)
   * 3. Reputation-Based Assessment (40%)
   */
  private fun calculateAppRiskScore(packageName: String): Map<String, Any> {
    // Get app name
    val appName = getAppName(packageName) ?: packageName
    
    // Get app category for context-aware analysis
    val category = determineAppCategory(packageName)
    
    // Get app permissions
    val permissions = getAppPermissions(packageName)
    
    // 1. Intent-Based Analysis (20%)
    val intentRisks = analyzeAppIntents(packageName)
    val intentScore = intentRisks.size * 10
    
    // 2. Context-Aware Permission Analysis (40%)
    val contextScore = calculateContextualRiskScore(permissions, category, packageName)
    val contextFactors = contextScore["riskFactors"] as List<String>
    
    // 3. Reputation-Based Assessment (40%)
    val reputationAssessment = assessAppReputation(packageName)
    val reputationScore = reputationAssessment["reputationScore"] as Int
    val reputationFactors = reputationAssessment["reputationFactors"] as List<String>
    
    // Combine scores with appropriate weighting
    val combinedScore = (
      (contextScore["score"] as Int) * 0.4 + 
      reputationScore * 0.4 + 
      intentScore * 0.2
    ).toInt()
    
    // Combine risk factors
    val combinedFactors = mutableListOf<String>()
    combinedFactors.addAll(intentRisks)
    combinedFactors.addAll(contextFactors)
    combinedFactors.addAll(reputationFactors)
    
    // Determine final risk level
    val riskLevel = when {
      combinedScore >= 50 -> "critical"
      combinedScore >= 30 -> "high"
      combinedScore >= 15 -> "medium"
      combinedScore >= 5 -> "low"
      else -> "safe"
    }
    
    // Check if app is a system app
    val isSystemApp = try {
      val appInfo = context.packageManager.getApplicationInfo(packageName, 0)
      (appInfo.flags and android.content.pm.ApplicationInfo.FLAG_SYSTEM) != 0
    } catch (e: Exception) {
      false
    }
    
    // Create the final result map to return to Flutter
    return mapOf(
      "packageName" to packageName,
      "appName" to appName,
      "riskScore" to combinedScore,
      "riskLevel" to riskLevel,
      "riskFactors" to combinedFactors.distinct(), // Remove duplicates
      "category" to category.toString(),
      "permissions" to permissions,
      "isSystemApp" to isSystemApp
    )
  }
  
  /**
   * Calculate contextual risk score based on app category and permissions
   */
  private fun calculateContextualRiskScore(
    permissions: List<String>, 
    category: AppCategory,
    packageName: String
  ): Map<String, Any> {
    var score = 0
    val riskFactors = mutableListOf<String>()
    
    // Count dangerous permissions
    val dangerousPermCount = permissions.count { DANGEROUS_PERMISSIONS.contains(it) }
    
    // Base risk assessment - add points for each dangerous permission
    if (dangerousPermCount > 0) {
      score += minOf(dangerousPermCount * 5, 25) // Cap at 25 points
      if (dangerousPermCount >= 5) {
        riskFactors.add("Uses $dangerousPermCount dangerous permissions")
      }
    }
    
    // Check for dangerous permission combinations
    for ((comboName, comboPerms) in DANGEROUS_PERMISSION_COMBINATIONS) {
      if (comboPerms.all { permissions.contains(it) }) {
        score += 20
        riskFactors.add("Dangerous combination: $comboName")
      }
    }
    
    // Context-aware permission checking (expected vs. unexpected permissions)
    when (category) {
      AppCategory.FINANCE -> {
        // Banking apps may legitimately need camera for deposits/KYC
        if (permissions.contains("android.permission.CAMERA")) {
          // This is expected
        }
        
        // But if it's not a legitimate financial app and has SMS access, that's suspicious
        if (permissions.contains("android.permission.READ_SMS") && 
            !LEGITIMATE_FINANCIAL_APPS.containsKey(packageName)) {
          score += 25
          riskFactors.add("Financial app with SMS access (high OTP theft risk)")
        }
      }
      AppCategory.GAMING -> {
        // Games shouldn't need call/SMS access
        if (permissions.any { it.contains("SMS") || it.contains("CALL") }) {
          score += 20
          riskFactors.add("Game with call or SMS access")
        }
      }
      AppCategory.UTILITY -> {
        // Utility apps with location and internet access are suspicious
        if (permissions.any { it.contains("LOCATION") } && 
            permissions.contains("android.permission.INTERNET")) {
          score += 15
          riskFactors.add("Utility app tracking location")
        }
      }
      AppCategory.PHOTOGRAPHY -> {
        // Camera apps legitimately need camera and storage
        if (permissions.contains("android.permission.CAMERA")) {
          // Expected permission, don't increase score
        } else if (permissions.contains("android.permission.READ_SMS")) {
          // But a camera app shouldn't need SMS access
          score += 25
          riskFactors.add("Photography app with SMS access")
        }
      }
      else -> {
        // For other categories, just use the base risk assessment
      }
    }
    
    return mapOf(
      "score" to score,
      "riskFactors" to riskFactors
    )
  }
  
  /**
   * Detect suspicious apps and return their risk assessments
   */
  private fun detectSuspiciousApps(): List<Map<String, Any>> {
    val suspiciousApps = mutableListOf<Map<String, Any>>()
    val packageManager = context.packageManager
    
    try {
      // Get all installed apps
      val installedPackages = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
        packageManager.getInstalledPackages(android.content.pm.PackageManager.PackageInfoFlags.of(0L))
      } else {
        @Suppress("DEPRECATION")
        packageManager.getInstalledPackages(0)
      }
      
      // Filter out system apps
      val nonSystemApps = installedPackages.filter { pkg ->
        val appInfo = pkg.applicationInfo ?: return@filter false
        (appInfo.flags and android.content.pm.ApplicationInfo.FLAG_SYSTEM) == 0
      }
      
      // Calculate risk score for each app
      for (pkg in nonSystemApps) {
        val riskAssessment = calculateAppRiskScore(pkg.packageName)
        val riskLevel = riskAssessment["riskLevel"] as String
        
        // Only include apps with medium risk or higher
        if (riskLevel == "medium" || riskLevel == "high" || riskLevel == "critical") {
          suspiciousApps.add(riskAssessment)
        }
      }
    } catch (e: Exception) {
      // Return empty list in case of error
    }
    
    return suspiciousApps
  }
  
  /**
   * Analyze app's registered intents to detect potential security risks
   * This is our first approach: Intent-Based Analysis
   */
  private fun analyzeAppIntents(packageName: String): List<String> {
    // Check if we have a cached result that's still valid
    val cachedResult = intentAnalysisCache[packageName]
    if (cachedResult != null && (System.currentTimeMillis() - cachedResult.second < CACHE_DURATION_MS)) {
      return cachedResult.first
    }
    
    val riskFactors = mutableListOf<String>()
    val packageManager = context.packageManager
    
    try {
      // Check for SMS interception
      val smsIntent = Intent("android.provider.Telephony.SMS_RECEIVED")
      val smsReceivers = packageManager.queryBroadcastReceivers(smsIntent, 0)
      if (smsReceivers.any { it.activityInfo.packageName == packageName }) {
        riskFactors.add("Intercepts SMS messages (high risk for banking OTPs)")
      }
      
      // Check for accessibility service (can read screen content)
      val accessibilityIntent = Intent("android.accessibilityservice.AccessibilityService")
      val accessibilityServices = packageManager.queryIntentServices(accessibilityIntent, 0)
      if (accessibilityServices.any { it.serviceInfo.packageName == packageName }) {
        riskFactors.add("Uses accessibility services (can read screen content)")
      }
      
      // Check for screen overlay capability
      if (hasOverlayPermission(packageName)) {
        val activityIntent = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
        val activities = packageManager.queryIntentActivities(activityIntent, 0)
        if (activities.any { it.activityInfo.packageName == packageName }) {
          riskFactors.add("Can create screen overlays (may overlay banking apps)")
        }
      }
      
      // Check for device admin receivers
      val deviceAdminIntent = Intent("android.app.action.DEVICE_ADMIN_ENABLED")
      val deviceAdminReceivers = packageManager.queryBroadcastReceivers(deviceAdminIntent, 0)
      if (deviceAdminReceivers.any { it.activityInfo.packageName == packageName }) {
        riskFactors.add("Requests device admin privileges")
      }
      
      // Cache the result
      intentAnalysisCache[packageName] = Pair(riskFactors, System.currentTimeMillis())
      return riskFactors
    } catch (e: Exception) {
      return listOf("Error analyzing intents: ${e.message}")
    }
  }

  /**
   * Check if app has overlay permission
   */
  private fun hasOverlayPermission(packageName: String): Boolean {
    return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
      Settings.canDrawOverlays(context)
    } else {
      getAppPermissions(packageName).contains("android.permission.SYSTEM_ALERT_WINDOW")
    }
  }

  /**
   * Determine app category from its package name and metadata
   * This supports our second approach: Context-Aware Assessment
   */
  private fun determineAppCategory(packageName: String): AppCategory {
    // First check known financial apps
    if (LEGITIMATE_FINANCIAL_APPS.containsKey(packageName)) {
      return AppCategory.FINANCE
    }
    
    // Check package name patterns
    return when {
      packageName.contains("bank") || 
      packageName.contains("pay") || 
      packageName.contains("wallet") || 
      packageName.contains("money") -> AppCategory.FINANCE
      
      packageName.contains("mail") || 
      packageName.contains("messaging") || 
      packageName.contains("chat") || 
      packageName.contains("sms") -> AppCategory.COMMUNICATION
      
      packageName.contains("cam") || 
      packageName.contains("photo") || 
      packageName.contains("gallery") -> AppCategory.PHOTOGRAPHY
      
      packageName.contains("game") -> AppCategory.GAMING
      
      packageName.contains("calc") || 
      packageName.contains("note") || 
      packageName.contains("calendar") || 
      packageName.contains("office") -> AppCategory.PRODUCTIVITY
      
      packageName.contains("tool") || 
      packageName.contains("util") -> AppCategory.UTILITY
      
      packageName.contains("social") || 
      packageName.contains("facebook") || 
      packageName.contains("twitter") || 
      packageName.contains("instagram") -> AppCategory.SOCIAL
      
      else -> AppCategory.UNKNOWN
    }
  }
  
  /**
   * Assess app's reputation based on installation source, etc.
   * This is our third approach: Reputation-Based Assessment
   */
  private fun assessAppReputation(packageName: String): Map<String, Any> {
    val riskFactors = mutableListOf<String>()
    var reputationScore = 0
    
    // 1. Check installation source
    val installer = getInstallationSource(packageName)
    when {
      TRUSTED_APP_STORES.contains(installer) -> {
        // Installed from trusted app store (good)
        reputationScore -= 10
      }
      installer == null || installer.isEmpty() -> {
        // Unknown source (suspicious)
        reputationScore += 15
        riskFactors.add("Installed from unknown source")
      }
      else -> {
        // Installed from another app store or via sideloading
        reputationScore += 10
        riskFactors.add("Not installed from official app store")
      }
    }
    
    // 2. Check installation recency (newly installed apps may be more suspicious)
    val installationTime = getInstallationTime(packageName)
    val oneDayAgo = System.currentTimeMillis() - (24 * 60 * 60 * 1000)
    if (installationTime > oneDayAgo) {
      reputationScore += 5
      riskFactors.add("Recently installed (within 24 hours)")
    }
    
    // 3. Check for financial app impersonation attempts
    val appName = getAppName(packageName)
    if (appName != null) {
      val impersonationCheck = checkFinancialAppImpersonation(packageName, appName)
      if (impersonationCheck.isNotEmpty()) {
        reputationScore += 30
        riskFactors.add(impersonationCheck)
      }
    }
    
    // Determine reputation level
    val reputationLevel = when {
      reputationScore >= 30 -> "Critical"
      reputationScore >= 15 -> "High"
      reputationScore >= 5 -> "Medium"
      reputationScore > 0 -> "Low"
      else -> "Trusted"
    }
    
    return mapOf(
      "reputationScore" to reputationScore,
      "reputationLevel" to reputationLevel,
      "reputationFactors" to riskFactors
    )
  }
  
  /**
   * Get app's installation source
   */
  private fun getInstallationSource(packageName: String): String? {
    return try {
      if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
        // Android 11+ uses different API
        val pm = context.packageManager
        val info = pm.getInstallSourceInfo(packageName)
        info.initiatingPackageName ?: info.installingPackageName
      } else {
        @Suppress("DEPRECATION")
        context.packageManager.getInstallerPackageName(packageName)
      }
    } catch (e: Exception) {
      null
    }
  }
  
  /**
   * Get app's installation time
   */
  private fun getInstallationTime(packageName: String): Long {
    return try {
      val packageManager = context.packageManager
      val packageInfo = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
        packageManager.getPackageInfo(packageName, android.content.pm.PackageManager.PackageInfoFlags.of(0L))
      } else {
        @Suppress("DEPRECATION")
        packageManager.getPackageInfo(packageName, 0)
      }
      packageInfo.firstInstallTime
    } catch (e: Exception) {
      0L
    }
  }
  
  /**
   * Get app name from package name
   */
  private fun getAppName(packageName: String): String? {
    return try {
      val packageManager = context.packageManager
      val applicationInfo = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
        packageManager.getApplicationInfo(packageName, android.content.pm.PackageManager.ApplicationInfoFlags.of(0L))
      } else {
        @Suppress("DEPRECATION")
        packageManager.getApplicationInfo(packageName, 0)
      }
      packageManager.getApplicationLabel(applicationInfo).toString()
    } catch (e: Exception) {
      null
    }
  }
  
  /**
   * Check if an app might be impersonating a legitimate financial app
   */
  private fun checkFinancialAppImpersonation(packageName: String, appName: String): String {
    val appNameLower = appName.lowercase()
    
    // Skip if it's a legitimate financial app
    if (LEGITIMATE_FINANCIAL_APPS.containsKey(packageName)) {
      return ""
    }
    
    // Check for financial keywords in the app name
    val financialKeywords = listOf("bank", "upi", "pay", "wallet", "finance", "money", "transaction", "loan")
    val containsFinancialKeyword = financialKeywords.any { appNameLower.contains(it) }
    
    // Check if app name is similar to any legitimate financial app
    for ((_, bankName) in LEGITIMATE_FINANCIAL_APPS) {
      val similarity = calculateNameSimilarity(appNameLower, bankName.lowercase())
      if (similarity > 0.7) { // 70% similarity threshold
        return "Potentially impersonating $bankName"
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
   * Detect potentially harmful apps based on dangerous permission combinations
   */
  private fun detectHarmfulApps(): List<String> {
    val harmfulApps = mutableListOf<String>()
    val packageManager = context.packageManager
    
    try {
      // Get all installed apps
      val installedPackages = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
        packageManager.getInstalledPackages(android.content.pm.PackageManager.PackageInfoFlags.of(android.content.pm.PackageManager.GET_PERMISSIONS.toLong()))
      } else {
        @Suppress("DEPRECATION")
        packageManager.getInstalledPackages(android.content.pm.PackageManager.GET_PERMISSIONS)
      }
      
      // Filter out system apps
      val nonSystemApps = installedPackages.filter { pkg ->
        val appInfo = pkg.applicationInfo ?: return@filter false
        (appInfo.flags and android.content.pm.ApplicationInfo.FLAG_SYSTEM) == 0
      }
      
      // Check each app for dangerous permission combinations
      for (pkg in nonSystemApps) {
        val packageName = pkg.packageName
        // Skip our own app
        if (packageName == context.packageName) continue
        
        val permissions = pkg.requestedPermissions?.toList() ?: continue
        val appInfo = pkg.applicationInfo ?: continue
        
        // Check for dangerous combinations
        for ((_, comboPermissions) in DANGEROUS_PERMISSION_COMBINATIONS) {
          if (permissions.containsAll(comboPermissions as List<String>)) {
            val appLabel = packageManager.getApplicationLabel(appInfo).toString()
            harmfulApps.add("$appLabel ($packageName)")
            break
          }
        }
        
        // Also check for apps with too many dangerous permissions
        val dangerousPermissions = listOf(
          "android.permission.READ_SMS",
          "android.permission.SEND_SMS",
          "android.permission.RECEIVE_SMS",
          "android.permission.READ_CALL_LOG",
          "android.permission.PROCESS_OUTGOING_CALLS",
          "android.permission.RECORD_AUDIO",
          "android.permission.CAMERA",
          "android.permission.ACCESS_FINE_LOCATION",
          "android.permission.ACCESS_BACKGROUND_LOCATION"
        )
        
        val dangerousCount = permissions.count { it in dangerousPermissions }
        if (dangerousCount >= 3) {
          // Use safe call (?.) for handling nullable ApplicationInfo
          val appLabel = packageManager.getApplicationLabel(appInfo).toString()
          if (!harmfulApps.contains("$appLabel ($packageName)")) {
            harmfulApps.add("$appLabel ($packageName)")
          }
        }
      }
      
    } catch (e: Exception) {
      e.printStackTrace()
    }
    
    return harmfulApps
  }
}
