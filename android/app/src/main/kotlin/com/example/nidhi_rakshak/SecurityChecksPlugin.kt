package com.example.nidhi_rakshak

import android.content.Context
import android.os.Build
import android.provider.Settings
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

/**
 * SecurityChecksPlugin
 *
 * Plugin that provides native security checks for the Flutter app
 */
class SecurityChecksPlugin: MethodCallHandler {
  /// The MethodChannel that will the communication between Flutter and native Android
  private lateinit var channel: MethodChannel
  private lateinit var context: Context

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
   * Detect potentially harmful apps based on dangerous permission combinations
   */
  private fun detectHarmfulApps(): List<String> {
    val harmfulApps = mutableListOf<String>()
    val packageManager = context.packageManager
    
    // List of dangerous permission combinations to check
    val dangerousPermissionCombinations = mapOf(
      "SMS_AND_CALLS" to listOf(
        "android.permission.READ_SMS",
        "android.permission.READ_CALL_LOG"
      ),
      "LOCATION_AND_RECORDING" to listOf(
        "android.permission.ACCESS_FINE_LOCATION",
        "android.permission.RECORD_AUDIO"
      ),
      "SMS_INTERCEPT" to listOf(
        "android.permission.RECEIVE_SMS",
        "android.permission.READ_SMS"
      )
    )
    
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
        for ((_, comboPermissions) in dangerousPermissionCombinations) {
          if (permissions.containsAll(comboPermissions)) {
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
