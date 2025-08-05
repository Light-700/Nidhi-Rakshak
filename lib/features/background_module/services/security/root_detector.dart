import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:device_info_plus/device_info_plus.dart';

/// Class for detecting root on Android devices using multiple methods
class RootDetector {
  /// Platform channel for native security checks
  static const MethodChannel _platform = MethodChannel('com.nidhi_rakshak.app/security_checks');

  /// Check if device is rooted (Android) using multiple detection methods
  static Future<bool> isRooted() async {
    if (!Platform.isAndroid) return false;
    
    try {
      // Method 1: Enhanced file-based detection
      final isRootedByFiles = await _checkRootFiles();
      if (isRootedByFiles) {
        debugPrint('Root detected via file-based checks');
        return true;
      }
      
      // Method 2: Check for su command execution
      final canExecuteSu = await _checkSuExecution();
      if (canExecuteSu) {
        debugPrint('Root detected via su command execution');
        return true;
      }
      
      // Method 3: Check for suspicious packages
      final hasSuspiciousPackages = await _checkRootPackages();
      if (hasSuspiciousPackages) {
        debugPrint('Root detected via package checks');
        return true;
      }
      
      // Method 4: Check build tags and system properties
      final hasSuspiciousBuildProps = await _checkBuildProperties();
      if (hasSuspiciousBuildProps) {
        debugPrint('Root detected via build properties');
        return true;
      }
      
      // Method 5: Check for read/write permissions in system directories
      final hasSystemWriteAccess = await _checkSystemWriteAccess();
      if (hasSystemWriteAccess) {
        debugPrint('Root detected via system write access');
        return true;
      }
      
      debugPrint('No root detected');
      return false;
    } catch (e) {
      debugPrint('Error checking for root: $e');
      // Conservative approach: return false to avoid false positives
      return false;
    }
  }
  
  /// Method 1: Enhanced file-based detection for root
  static Future<bool> _checkRootFiles() async {
    // Comprehensive list of root indicators
    final rootPaths = [
      '/system/app/Superuser.apk',
      '/system/app/SuperSU.apk',
      '/system/app/Magisk.apk',
      '/system/app/KingUser.apk',
      '/system/xbin/su',
      '/system/bin/su',
      '/system/bin/failsafe/su',
      '/system/sbin/su',
      '/sbin/su',
      '/su/bin/su',
      '/data/adb/su',
      '/data/local/su',
      '/data/local/xbin/su',
      '/data/local/bin/su',
      '/system/sd/xbin/su',
      '/system/bin/mu',
      '/system/usr/we-need-root/su',
      '/system/xbin/mu',
      '/data/adb/magisk', // Magisk installation directory
      '/cache/magisk.log', // Magisk log
      '/data/adb/modules', // Magisk modules
      '/data/adb/magisk.db', // Magisk database
    ];

    // Look for busybox, which often indicates rooted devices
    final busyboxPaths = [
      '/system/xbin/busybox',
      '/system/bin/busybox',
      '/sbin/busybox',
      '/data/local/busybox',
    ];

    // Check for root files
    for (final path in rootPaths) {
      if (await FileSystemEntity.isDirectory(path) || 
          await FileSystemEntity.isFile(path)) {
        debugPrint('Root detected: Found $path');
        return true;
      }
    }
    
    // Check for busybox
    for (final path in busyboxPaths) {
      if (await File(path).exists()) {
        debugPrint('Root potential: Found busybox at $path');
        return true;
      }
    }
    
    return false;
  }
  
  /// Method 2: Check for su command execution
  static Future<bool> _checkSuExecution() async {
    try {
      // Try executing su commands (will be prevented on non-rooted devices)
      final process = await Process.run('su', ['-c', 'id']);
      
      // Check if the command executed successfully
      if (process.exitCode == 0) {
        debugPrint('Root detected: su command executed successfully');
        return true;
      }
      
      return false;
    } catch (e) {
      // Expected: non-rooted devices should throw an exception
      return false;
    }
  }
  
  /// Method 3: Check for suspicious packages
  static Future<bool> _checkRootPackages() async {
    try {
      // List of known root management apps
      final suspiciousPackages = [
        'com.noshufou.android.su',
        'com.koushikdutta.superuser',
        'eu.chainfire.supersu',
        'com.topjohnwu.magisk',
        'com.kingroot.kinguser',
        'com.kingo.root',
        'com.smedialink.oneclickroot',
        'com.zhiqupk.root.global',
        'com.alephzain.framaroot',
      ];
      
      // This would require platform channels to check installed packages
      // Placeholder for actual implementation through native code
      try {
        final result = await _platform.invokeMethod('checkRootPackages', {'packages': suspiciousPackages});
        if (result == true) {
          debugPrint('Root detected: Found root management package');
          return true;
        }
      } catch (e) {
        // If method not implemented yet, ignore
        debugPrint('Package check not implemented: $e');
      }
      
      return false;
    } catch (e) {
      return false;
    }
  }
  
  /// Method 4: Check build tags and system properties
  static Future<bool> _checkBuildProperties() async {
    try {
      // Use device_info_plus to get Android build properties
      final deviceInfoPlugin = DeviceInfoPlugin();
      final androidInfo = await deviceInfoPlugin.androidInfo;
      
      // Check build tags
      final tags = androidInfo.tags;
      if (tags.contains('test-keys')) {
        debugPrint('Root indicator: Build signed with test-keys');
        return true;
      }
      
      // Additional system properties through platform channels
      try {
        final Map<dynamic, dynamic>? props = await _platform.invokeMethod('getSystemProperties');
        if (props != null) {
          if (props['ro.debuggable'] == '1') {
            debugPrint('Root indicator: Device is debuggable');
            return true;
          }
          if (props['ro.secure'] == '0') {
            debugPrint('Root indicator: ro.secure is 0');
            return true;
          }
        }
      } catch (e) {
        // If method not implemented yet, ignore
        debugPrint('System properties check not implemented: $e');
      }
      
      return false;
    } catch (e) {
      debugPrint('Error checking build properties: $e');
      return false;
    }
  }
  
  /// Method 5: Check for read/write permissions in system directories
  static Future<bool> _checkSystemWriteAccess() async {
    try {
      // Try to write to a system directory that should be read-only
      final testFile = '/system/rootcheck_${DateTime.now().millisecondsSinceEpoch}.txt';
      final file = File(testFile);
      
      try {
        await file.writeAsString('Root test');
        
        // If write succeeds, check if file exists and delete it
        final exists = await file.exists();
        if (exists) {
          await file.delete();
          debugPrint('Root detected: Could write to /system');
          return true;
        }
      } catch (e) {
        // Expected: write should fail on non-rooted devices
      }
      
      return false;
    } catch (e) {
      return false;
    }
  }
}
