import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Model for security status
class SecurityStatus {
  final bool isDeviceSecure;
  final bool isJailbroken;
  final bool isRooted;
  final DateTime lastChecked;
  final List<SecurityThreat> detectedThreats;

  SecurityStatus({
    required this.isDeviceSecure,
    required this.isJailbroken,
    required this.isRooted,
    required this.lastChecked,
    required this.detectedThreats,
  });

  factory SecurityStatus.secure() {
    return SecurityStatus(
      isDeviceSecure: true,
      isJailbroken: false,
      isRooted: false,
      lastChecked: DateTime.now(),
      detectedThreats: [],
    );
  }
}

class SecurityThreat {
  final String name;
  final String description;
  final SecurityThreatLevel level;

  SecurityThreat({
    required this.name,
    required this.description,
    required this.level,
  });
}

enum SecurityThreatLevel { low, medium, high, critical }

class SecurityService {
  static final SecurityService _instance = SecurityService._internal();
  factory SecurityService() => _instance;

  SecurityService._internal();

  SecurityStatus? _lastStatus;
  SecurityStatus get lastStatus => _lastStatus ?? SecurityStatus.secure();

  // Stream controller to broadcast security updates
  final _securityStreamController = StreamController<SecurityStatus>.broadcast();
  Stream<SecurityStatus> get securityStream => _securityStreamController.stream;

  // Initialize the service
  Future<void> initialize() async {
    // Perform initial security check
    await refreshSecurityStatus();

    // Setup periodic checks (every 15 minutes)
    Timer.periodic(Duration(minutes: 15), (_) async {
      await refreshSecurityStatus();
    });
  }

  // Refresh security status
  Future<SecurityStatus> refreshSecurityStatus() async {
    // Perform security checks
    final isJailbroken = await _checkForJailbreak();
    final isRooted = await _checkForRoot();
    
    // Check for suspicious apps
    final detectedThreats = await _detectThreats();
    
    // Device is secure if not jailbroken/rooted and no critical threats
    final hasCriticalThreats = detectedThreats.any(
      (threat) => threat.level == SecurityThreatLevel.critical
    );
    
    final isDeviceSecure = !isJailbroken && !isRooted && !hasCriticalThreats;

    // Create security status
    _lastStatus = SecurityStatus(
      isDeviceSecure: isDeviceSecure,
      isJailbroken: isJailbroken,
      isRooted: isRooted,
      lastChecked: DateTime.now(),
      detectedThreats: detectedThreats,
    );

    // Save last checked time
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_security_check', DateTime.now().toIso8601String());

    // Broadcast the update
    _securityStreamController.add(_lastStatus!);
    
    return _lastStatus!;
  }

  // Run a full security scan
  Future<SecurityStatus> runFullSecurityScan() async {
    // This would be a more comprehensive scan
    // For now, we'll use the same implementation as refreshSecurityStatus
    return refreshSecurityStatus();
  }

  // Check if device is jailbroken (iOS)
  Future<bool> _checkForJailbreak() async {
    if (!Platform.isIOS) return false;

    try {
      // Check for common jailbreak files and apps
      final jailbreakPaths = [
        '/Applications/Cydia.app',
        '/Library/MobileSubstrate/MobileSubstrate.dylib',
        '/bin/bash',
        '/usr/sbin/sshd',
        '/etc/apt',
        '/private/var/lib/apt/',
      ];

      for (final path in jailbreakPaths) {
        if (await Directory(path).exists()) {
          return true;
        }
      }

      return false;
    } catch (e) {
      // If we can't check (e.g., due to permissions), assume not jailbroken
      return false;
    }
  }

  // Check if device is rooted (Android)
  Future<bool> _checkForRoot() async {
    if (!Platform.isAndroid) return false;

    try {
      // Check for common root files and apps
      final rootPaths = [
        '/system/app/Superuser.apk',
        '/system/xbin/su',
        '/system/bin/su',
        '/sbin/su',
        '/system/su',
        '/system/bin/.ext/.su',
      ];

      for (final path in rootPaths) {
        if (await File(path).exists()) {
          return true;
        }
      }

      return false;
    } catch (e) {
      // If we can't check (e.g., due to permissions), assume not rooted
      return false;
    }
  }

  // Detect security threats
  Future<List<SecurityThreat>> _detectThreats() async {
    // This would connect to a real threat detection system
    // For demonstration, we'll return a simulated result
    
    final threats = <SecurityThreat>[];
    
    // Simulate finding threats 20% of the time for demo purposes
    if (DateTime.now().second % 5 == 0) {
      threats.add(
        SecurityThreat(
          name: 'Suspicious App',
          description: 'An app with potentially harmful permissions was detected',
          level: SecurityThreatLevel.medium,
        ),
      );
    }
    
    return threats;
  }

  // Dispose resources
  void dispose() {
    _securityStreamController.close();
  }
}
