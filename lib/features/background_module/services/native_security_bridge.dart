import 'dart:async';
import 'package:flutter/services.dart';

/// Bridge to native security checks for advanced jailbreak and root detection
class NativeSecurityBridge {
  static const MethodChannel _channel = MethodChannel('com.nidhi_rakshak/security_checks');
  
  /// Check for jailbreak on iOS using native code
  static Future<bool> checkJailbreak() async {
    if (!_isIOS()) return false;
    
    try {
      final bool result = await _channel.invokeMethod('checkJailbreak');
      return result;
    } on PlatformException catch (e) {
      print('Error calling native jailbreak detection: ${e.message}');
      return false;
    }
  }
  
  /// Check for root on Android using native code
  static Future<bool> checkRoot() async {
    if (!_isAndroid()) return false;
    
    try {
      final bool result = await _channel.invokeMethod('checkRoot');
      return result;
    } on PlatformException catch (e) {
      print('Error calling native root detection: ${e.message}');
      return false;
    }
  }
  
  /// Check if a URL scheme can be opened
  static Future<bool> canOpenURLScheme(String urlScheme) async {
    try {
      final bool result = await _channel.invokeMethod('canOpenURL', {'url': urlScheme});
      return result;
    } on PlatformException catch (e) {
      print('Error checking URL scheme: ${e.message}');
      return false;
    }
  }
  
  /// Get system properties (Android)
  static Future<Map<String, String>> getSystemProperties() async {
    if (!_isAndroid()) return {};
    
    try {
      final Map<dynamic, dynamic> result = await _channel.invokeMethod('getSystemProperties');
      return Map<String, String>.from(result);
    } on PlatformException catch (e) {
      print('Error getting system properties: ${e.message}');
      return {};
    }
  }
  
  /// Check for suspicious packages (Android)
  static Future<bool> checkForSuspiciousPackages(List<String> packages) async {
    if (!_isAndroid()) return false;
    
    try {
      final bool result = await _channel.invokeMethod('checkPackages', {'packages': packages});
      return result;
    } on PlatformException catch (e) {
      print('Error checking packages: ${e.message}');
      return false;
    }
  }
  
  /// Helper to check if running on iOS
  static bool _isIOS() => identical(0, 0.0) ? false : true; // Platform.isIOS
  
  /// Helper to check if running on Android
  static bool _isAndroid() => !_isIOS(); // Platform.isAndroid
}

// README: Native side implementation would be needed in iOS and Android
// For iOS, implement in AppDelegate.swift
// For Android, implement in MainActivity.kt
