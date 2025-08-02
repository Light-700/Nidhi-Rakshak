import 'package:flutter/services.dart';

/// Risk levels for applications
enum AppRiskLevel {
  safe,
  low,
  medium,
  high,
  critical,
  unknown,
}

/// Class for enhanced app security scanning
class AppSecurityScanner {
  static const MethodChannel _platform = MethodChannel('com.nidhi_rakshak/security_checks');
  
  // Cache to store risk information for faster access
  static final Map<String, Map<String, dynamic>> _riskInfoCache = {};
  
  /// Calculate the app's risk score using our enhanced three-approach method:
  /// 1. Intent-Based Analysis - looks at how apps use their permissions
  /// 2. Context-Aware Analysis - evaluates permissions based on app category
  /// 3. Reputation-Based Assessment - checks app source and installation details
  /// Get cached risk information for an app
  static Map<String, dynamic>? getCachedRiskInfo(String packageName) {
    return _riskInfoCache[packageName];
  }

  /// Calculate the app's risk score using our enhanced three-approach method:
  /// 1. Intent-Based Analysis - looks at how apps use their permissions
  /// 2. Context-Aware Analysis - evaluates permissions based on app category
  /// 3. Reputation-Based Assessment - checks app source and installation details
  static Future<Map<String, dynamic>> calculateAppRiskScore(String packageName) async {
    // Return cached result if available
    if (_riskInfoCache.containsKey(packageName)) {
      return _riskInfoCache[packageName]!;
    }
    
    try {
      final result = await _platform.invokeMethod('calculateAppRiskScore', {
        'packageName': packageName,
      });
      
      final riskInfo = Map<String, dynamic>.from(result);
      // Cache the result
      _riskInfoCache[packageName] = riskInfo;
      
      return riskInfo;
    } on PlatformException catch (e) {
      print('Error calculating app risk score: ${e.message}');
      final riskInfo = {
        'packageName': packageName,
        'appName': 'Unknown',
        'riskScore': 0,
        'riskLevel': 'unknown',
        'riskFactors': ['Error calculating risk: ${e.message}'],
        'isSystemApp': false,
      };
      _riskInfoCache[packageName] = riskInfo;
      return riskInfo;
    }
  }
  
  /// Scan for suspicious apps with medium risk or higher
  static Future<List<Map<String, dynamic>>> detectSuspiciousApps() async {
    try {
      final result = await _platform.invokeMethod('detectSuspiciousApps');
      
      if (result is List) {
        return result
            .map((item) => Map<String, dynamic>.from(item))
            .toList();
      }
      return [];
    } on PlatformException catch (e) {
      print('Error detecting suspicious apps: ${e.message}');
      return [];
    }
  }
  
  /// Get app permissions with enhanced context information
  static Future<Map<String, dynamic>> getEnhancedAppPermissions(String packageName) async {
    try {
      // Call the risk assessment which includes detailed permission info
      final result = await calculateAppRiskScore(packageName);
      
      // Extract the permissions map from the result
      if (result.containsKey('permissions')) {
        return {
          'permissions': result['permissions'],
          'riskFactors': result['riskFactors'],
          'riskLevel': result['riskLevel'],
          'category': result['category'],
        };
      }
      
      return {'error': 'No permissions data available'};
    } on PlatformException catch (e) {
      print('Error getting enhanced app permissions: ${e.message}');
      return {'error': e.message};
    }
  }
  
  /// Parse risk level from string
  static AppRiskLevel parseRiskLevel(String level) {
    switch (level.toLowerCase()) {
      case 'safe':
        return AppRiskLevel.safe;
      case 'low':
        return AppRiskLevel.low;
      case 'medium':
        return AppRiskLevel.medium;
      case 'high':
        return AppRiskLevel.high;
      case 'critical':
        return AppRiskLevel.critical;
      default:
        return AppRiskLevel.unknown;
    }
  }
  
  /// Get color for risk level
  static int getRiskLevelColor(AppRiskLevel level) {
    switch (level) {
      case AppRiskLevel.safe:
        return 0xFF4CAF50; // Green
      case AppRiskLevel.low:
        return 0xFF8BC34A; // Light Green
      case AppRiskLevel.medium:
        return 0xFFFFC107; // Amber
      case AppRiskLevel.high:
        return 0xFFFF9800; // Orange
      case AppRiskLevel.critical:
        return 0xFFF44336; // Red
      case AppRiskLevel.unknown:
        return 0xFF9E9E9E; // Grey
    }
  }
  
  /// Convert risk level to string
  static String riskLevelToString(AppRiskLevel level) {
    switch (level) {
      case AppRiskLevel.safe:
        return 'Safe';
      case AppRiskLevel.low:
        return 'Low Risk';
      case AppRiskLevel.medium:
        return 'Medium Risk';
      case AppRiskLevel.high:
        return 'High Risk';
      case AppRiskLevel.critical:
        return 'Critical Risk';
      case AppRiskLevel.unknown:
        return 'Unknown Risk';
    }
  }
}
