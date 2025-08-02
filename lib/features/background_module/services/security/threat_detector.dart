import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
// import 'package:package_info_plus/package_info_plus.dart';

import 'security_models.dart';
import 'permission_analyzer.dart';

/// Class for detecting various security threats on the device
class ThreatDetector {
  /// Platform channel for native security checks
  static const MethodChannel _platform = MethodChannel('com.nidhi_rakshak/security_checks');

  /// Detect security threats on the device
  static Future<List<SecurityThreat>> detectThreats() async {
    final threats = <SecurityThreat>[];
    
    try {
      // Check for outdated OS versions
      final osVersionThreats = await _checkOSVersion();
      threats.addAll(osVersionThreats);
      
      // Check for harmful apps installed
      final appThreats = await _checkHarmfulApps();
      threats.addAll(appThreats);
      
      // Emulator detection (useful in banking apps)
      final isEmulator = await _checkForEmulator();
      if (isEmulator) {
        threats.add(
          SecurityThreat(
            name: 'Emulator Detected',
            description: 'Application running in an emulator, which may be less secure than a physical device',
            level: SecurityThreatLevel.medium,
          ),
        );
      }
      
      // Debug detection
      final isDebuggable = await _checkForDebugging();
      if (isDebuggable) {
        threats.add(
          SecurityThreat(
            name: 'Debugging Enabled',
            description: 'Application is running in debug mode, which may expose sensitive information',
            level: SecurityThreatLevel.medium,
          ),
        );
      }
        // Check for Frida and other dynamic instrumentation tools
      final hasDynamicInstrumentation = await _checkForDynamicInstrumentation();
      if (hasDynamicInstrumentation) {
        threats.add(
          SecurityThreat(
            name: 'Dynamic Instrumentation Detected',
            description: 'Tools for runtime manipulation of the app detected',
            level: SecurityThreatLevel.critical,
          ),
        );
      }
      
      // Check if developer mode is enabled
      final isDeveloperModeEnabled = await _checkForDeveloperMode();
      if (isDeveloperModeEnabled) {
        threats.add(
          SecurityThreat(
            name: 'Developer Mode Enabled',
            description: 'Developer mode is enabled on this device, which can expose sensitive features and reduce security',
            level: SecurityThreatLevel.medium,
          ),
        );
      }
      // We've removed the dummy suspicious app code here since we now use the AppSecurityScanner
      // for actual app risk assessment
      
      return threats;
    } catch (e) {
      debugPrint('Error detecting threats: $e');
      return threats;
    }
  }
  
  /// Check for outdated OS versions with known vulnerabilities
  static Future<List<SecurityThreat>> _checkOSVersion() async {
    final threats = <SecurityThreat>[];
    
    try {
      if (Platform.isAndroid) {
        // Android version check
        try {
          final platformVersion = int.parse(Platform.operatingSystemVersion.split('.')[0]);
          
          if (platformVersion < 7) { // Android 7.0 Nougat
            threats.add(SecurityThreat(
              name: 'Outdated Android Version',
              description: 'Your Android version is outdated and has known security vulnerabilities',
              level: SecurityThreatLevel.high,
            ));
          } else if (platformVersion < 10) { // Android 10
            threats.add(SecurityThreat(
              name: 'Aging Android Version',
              description: 'Consider updating your Android version for better security',
              level: SecurityThreatLevel.medium,
            ));
          }
        } catch (e) {
          debugPrint('Error parsing Android version: $e');
        }
      } 
      else if (Platform.isIOS) {
        // iOS version check
        try {
          final version = Platform.operatingSystemVersion;
          final majorVersion = int.parse(version.split('.')[0]);
          
          if (majorVersion < 13) { // iOS 13
            threats.add(SecurityThreat(
              name: 'Outdated iOS Version',
              description: 'Your iOS version is outdated and has known security vulnerabilities',
              level: SecurityThreatLevel.high,
            ));
          } else if (majorVersion < 15) { // iOS 15
            threats.add(SecurityThreat(
              name: 'Aging iOS Version',
              description: 'Consider updating your iOS version for better security',
              level: SecurityThreatLevel.low,
            ));
          }
        } catch (e) {
          debugPrint('Error parsing iOS version: $e');
        }
      }
    } catch (e) {
      debugPrint('Error checking OS version: $e');
    }
    
    return threats;
  }
  
  /// Check for harmful apps installed on the device
  static Future<List<SecurityThreat>> _checkHarmfulApps() async {
    final threats = <SecurityThreat>[];
    
    try {
      // Use our permission analyzer to detect apps with suspicious permissions
      final permissionThreats = await PermissionAnalyzer.analyzeDangerousAppPermissions();
      threats.addAll(permissionThreats);
      
      // Also check through native code for any harmful apps
      try {
        final result = await _platform.invokeMethod('checkHarmfulApps');
        if (result != null && result is List) {
          for (final app in result) {
            // Check if we already have this app in our threats list
            bool alreadyDetected = false;
            for (final threat in permissionThreats) {
              if (threat.metadata != null && 
                  threat.metadata!.containsKey('appName') && 
                  app.toString().contains(threat.metadata!['appName'].toString())) {
                alreadyDetected = true;
                break;
              }
            }
            
            if (!alreadyDetected) {
              threats.add(SecurityThreat(
                name: 'Harmful App Detected',
                description: 'Potentially harmful app detected: $app',
                level: SecurityThreatLevel.high,
              ));
            }
          }
        }
      } catch (e) {
        // Native method might not be implemented yet
        debugPrint('Error calling native checkHarmfulApps: $e');
      }
    } catch (e) {
      debugPrint('Error checking for harmful apps: $e');
    }
    
    return threats;
  }
  
  /// Check if running on an emulator
  static Future<bool> _checkForEmulator() async {
    try {
      if (Platform.isAndroid) {
        // Some basic emulator detection
        const emulatorSigns = [
          'google_sdk',
          'emulator',
          'android_sdk',
          'sdk',
          'sdk_gphone',
          'sdk_x86',
          'vbox86p',
        ];
        
        final deviceName = Platform.localHostname.toLowerCase();
        for (final sign in emulatorSigns) {
          if (deviceName.contains(sign)) {
            return true;
          }
        }
        
        // More sophisticated checks would be done in native code
        try {
          final result = await _platform.invokeMethod('isEmulator');
          return result == true;
        } catch (e) {
          // Method not implemented yet
        }
      } 
      else if (Platform.isIOS) {
        // Very basic iOS simulator detection
        // More sophisticated checks would be done in native code
        try {
          final result = await _platform.invokeMethod('isSimulator');
          return result == true;
        } catch (e) {
          // Method not implemented yet
        }
      }
    } catch (e) {
      debugPrint('Error checking for emulator: $e');
    }
    
    return false;
  }
  
  /// Check if app is running in debug mode
  static Future<bool> _checkForDebugging() async {
    // In a real implementation, this would check debugging status
    // For now, just return if we're in debug mode in Flutter
    return kDebugMode;
  }
  
  /// Check for dynamic instrumentation tools like Frida
  static Future<bool> _checkForDynamicInstrumentation() async {
    try {
      // This would require native code to detect
      // Try using the platform channel
      try {
        final result = await _platform.invokeMethod('checkDynamicInstrumentation');
        return result == true;
      } catch (e) {
        // Method not implemented yet
      }
    } catch (e) {
      debugPrint('Error checking for dynamic instrumentation: $e');
    }
    
    return false;
  }
  
  /// Check if developer mode is enabled
  static Future<bool> _checkForDeveloperMode() async {
    try {
      if (Platform.isAndroid) {
        // For Android, we need to use platform channel to check developer options
        try {
          final result = await _platform.invokeMethod('isDeveloperModeEnabled');
          return result == true;
        } catch (e) {
          // Method not implemented yet in native code, use a fallback
          try {
            // Alternative approach: Try to read global settings via platform channel
            final adbEnabled = await _platform.invokeMethod('getAndroidSettingsInt', {
              'settingsType': 'Global',
              'settingsKey': 'adb_enabled',
              'defaultValue': 0
            });
            
            if (adbEnabled == 1) {
              debugPrint('Developer mode detected: ADB enabled');
              return true;
            }
            
            final developerOptionsEnabled = await _platform.invokeMethod('getAndroidSettingsInt', {
              'settingsType': 'Global',
              'settingsKey': 'development_settings_enabled',
              'defaultValue': 0
            });
            
            return developerOptionsEnabled == 1;
          } catch (e) {
            debugPrint('Error checking developer settings: $e');
            // Since we can't detect it reliably without native code, return false
            // to avoid false positives
            return false;
          }
        }
      } 
      else if (Platform.isIOS) {
        // iOS doesn't have a traditional "developer mode" like Android
        // However, you can check for a connected debugger or developer-specific settings
        try {
          // Check if app is connected to debugger (requires native implementation)
          final result = await _platform.invokeMethod('isDebuggerAttached');
          if (result == true) {
            return true;
          }
          
          // Check for developer-specific profiles
          final hasDeveloperProfile = await _platform.invokeMethod('hasDeveloperProfile');
          return hasDeveloperProfile == true;
        } catch (e) {
          // Method not implemented yet
          debugPrint('Developer mode check not implemented for iOS: $e');
          return false;
        }
      }
    } catch (e) {
      debugPrint('Error checking for developer mode: $e');
    }
    
    return false;
  }
}
