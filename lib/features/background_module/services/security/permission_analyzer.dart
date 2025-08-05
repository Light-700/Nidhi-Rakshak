import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:installed_apps/installed_apps.dart';

import 'security_models.dart';

/// Class for analyzing app permissions to detect potentially harmful applications
class PermissionAnalyzer {
  /// Platform channel for native security checks
  static const MethodChannel _platform = MethodChannel('com.nidhi_rakshak.app/security_checks');

  /// List of dangerous Android permissions that could indicate malicious apps
  static const List<String> dangerousPermissions = [
    'android.permission.READ_SMS',
    'android.permission.RECEIVE_SMS',
    'android.permission.SEND_SMS',
    'android.permission.PROCESS_OUTGOING_CALLS',
    'android.permission.CALL_PHONE',
    'android.permission.READ_CALL_LOG',
    'android.permission.WRITE_CALL_LOG',
    'android.permission.SYSTEM_ALERT_WINDOW',
    'android.permission.GET_ACCOUNTS',
    'android.permission.READ_CONTACTS',
    'android.permission.WRITE_CONTACTS',
    'android.permission.RECORD_AUDIO',
    'android.permission.CAMERA',
    'android.permission.ACCESS_FINE_LOCATION',
    'android.permission.ACCESS_BACKGROUND_LOCATION',
    'android.permission.READ_EXTERNAL_STORAGE',
    'android.permission.WRITE_EXTERNAL_STORAGE',
  ];

  /// High-risk combinations of permissions that may indicate malicious behavior
  static const Map<String, List<String>> dangerousPermissionCombinations = {
    'SMS and Call Logger': [
      'android.permission.READ_SMS',
      'android.permission.READ_CALL_LOG',
    ],
    'Call and SMS Interceptor': [
      'android.permission.RECEIVE_SMS',
      'android.permission.PROCESS_OUTGOING_CALLS',
    ],
    'Location and Recording': [
      'android.permission.ACCESS_FINE_LOCATION',
      'android.permission.RECORD_AUDIO',
    ],
    'Full Communication Access': [
      'android.permission.READ_CONTACTS',
      'android.permission.SEND_SMS',
      'android.permission.CALL_PHONE',
    ],
  };

  /// Financial app-specific sensitive permissions
  static const List<String> financialAppSensitivePermissions = [
    'android.permission.USE_BIOMETRIC',
    'android.permission.USE_FINGERPRINT',
    'android.permission.INTERNET',
    'android.permission.CAMERA', // For QR code scanning
  ];

  /// Analyze installed non-system apps for dangerous permission combinations
  static Future<List<SecurityThreat>> analyzeDangerousAppPermissions() async {
    final threats = <SecurityThreat>[];
    
    if (!Platform.isAndroid) {
      return threats; // Only supported on Android for now
    }
    
    try {
      // Get all installed apps
      final apps = await InstalledApps.getInstalledApps(true, false, "");
      
      for (final app in apps) {
        final packageName = app.packageName;
        
        // Get permissions for this app using platform channel
        final permissions = await getAppPermissions(packageName);
        
        if (permissions.isNotEmpty) {
          // Check for dangerous permission combinations
          final dangerousCombo = checkDangerousPermissionCombinations(permissions);
          
          if (dangerousCombo.isNotEmpty) {
            threats.add(SecurityThreat(
              name: 'Suspicious App Detected',
              description: 'App "${app.name}" has suspicious permission combination: $dangerousCombo',
              level: SecurityThreatLevel.high,
              metadata: {
                'packageName': packageName,
                'permissionIssue': dangerousCombo,
                'appName': app.name,
              },
            ));
          }
          // Check for excessive dangerous permissions
          else if (countDangerousPermissions(permissions) >= 3) {
            threats.add(SecurityThreat(
              name: 'Suspicious App Permissions',
              description: 'App "${app.name}" has multiple sensitive permissions',
              level: SecurityThreatLevel.medium,
              metadata: {
                'packageName': packageName,
                'permissionCount': countDangerousPermissions(permissions).toString(),
                'appName': app.name,
              },
            ));
          }
        }
      }
    } catch (e) {
      print('Error analyzing app permissions: $e');
    }
    
    return threats;
  }

  /// Get app permissions from native code
  static Future<List<String>> getAppPermissions(String packageName) async {
    try {
      final result = await _platform.invokeMethod('getAppPermissions', {'packageName': packageName});
      if (result != null && result is List) {
        return result.cast<String>();
      }
    } catch (e) {
      // Method not implemented yet or error occurred
    }
    return [];
  }

  /// Check for dangerous permission combinations
  static String checkDangerousPermissionCombinations(List<String> permissions) {
    for (final entry in dangerousPermissionCombinations.entries) {
      final comboName = entry.key;
      final comboPermissions = entry.value;
      
      bool hasAllPermissions = true;
      for (final permission in comboPermissions) {
        if (!permissions.contains(permission)) {
          hasAllPermissions = false;
          break;
        }
      }
      
      if (hasAllPermissions) {
        return comboName;
      }
    }
    return '';
  }

  /// Count how many permissions from the dangerous list the app has
  static int countDangerousPermissions(List<String> permissions) {
    int count = 0;
    for (final permission in permissions) {
      if (dangerousPermissions.contains(permission)) {
        count++;
      }
    }
    return count;
  }
}
