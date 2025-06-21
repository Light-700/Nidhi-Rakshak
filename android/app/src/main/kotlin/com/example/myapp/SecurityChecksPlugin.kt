package com.example.myapp

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
}
