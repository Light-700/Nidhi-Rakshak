import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Import our modular security components
import 'security/security_models.dart';
import 'security/jailbreak_detector.dart';
import 'security/root_detector.dart';
import 'security/threat_detector.dart';
import 'native_security_bridge.dart';

class SecurityService {
  // The class uses the Singleton pattern
  static final SecurityService _instance = SecurityService._internal();
  factory SecurityService() => _instance;

  SecurityService._internal();

  // Maintains the latest security status
  // Provides a safe getter with default values
  SecurityStatus? _lastStatus;
  SecurityStatus get lastStatus => _lastStatus ?? SecurityStatus.secure();

  // Event Broadcasting - Stream controller to broadcast security updates
  // Uses a broadcast stream to notify listeners of security changes
  // UI components can subscribe to get real-time updates
  final _securityStreamController =
      StreamController<SecurityStatus>.broadcast();
  Stream<SecurityStatus> get securityStream => _securityStreamController.stream;

  // Initialize the service and Periodic Checks
  Future<void> initialize() async {
    // Perform initial security check
    await refreshSecurityStatus();

    // Setup periodic checks (every 15 minutes)
    // Timer.periodic(Duration(minutes: 15), (_) async {
    //   await refreshSecurityStatus();
    // });
  }

  // Refresh security status with comprehensive checks
  Future<SecurityStatus> refreshSecurityStatus() async {
    debugPrint('Starting comprehensive security checks...');

    // Check for jailbreak/root with enhanced detection methods using our modular detectors
    final isJailbroken = await JailbreakDetector.isJailbroken();
    final isRooted = await RootDetector.isRooted();

    if (isJailbroken) {
      debugPrint('SECURITY ALERT: Device appears to be jailbroken!');
    }

    if (isRooted) {
      debugPrint('SECURITY ALERT: Device appears to be rooted!');
    }

    // Check for suspicious apps and other threats using our ThreatDetector
    final detectedThreats = await ThreatDetector.detectThreats();

    // Device is secure if not jailbroken/rooted and no critical threats
    final hasCriticalThreats = detectedThreats.any(
      (threat) => threat.level == SecurityThreatLevel.critical,
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
    await prefs.setString(
      'last_security_check',
      DateTime.now().toIso8601String(),
    );

    // Broadcast the update
    _securityStreamController.add(_lastStatus!);

    return _lastStatus!;
  }

  // Run a full security scan with additional checks
  Future<SecurityStatus> runFullSecurityScan() async {
    debugPrint('Starting full security scan with extended detection...');

    // Standard checks first using our refreshSecurityStatus method
    final status = await refreshSecurityStatus();

    // For a more comprehensive scan, we could add additional checks here
    // such as deeper analysis or more resource-intensive checks
    // that we wouldn't want to run during routine checks

    // Additional native checks through our security bridge
    try {
      if (Platform.isAndroid) {
        final hasRiskySysProps =
            await NativeSecurityBridge.getSystemProperties().then(
              (props) =>
                  props.containsKey('ro.debuggable') &&
                  props['ro.debuggable'] == '1',
            );

        if (hasRiskySysProps) {
          final additionalThreats = [
            SecurityThreat(
              name: 'Debuggable System',
              description:
                  'System is running in debug mode, which is a security risk',
              level: SecurityThreatLevel.high,
            ),
          ];

          // Update status with additional threats
          return _updateSecurityStatus(status, additionalThreats);
        }
      }
    } catch (e) {
      debugPrint('Error during advanced security checks: $e');
    }

    return status;
  }

  // Helper method to update security status with new threats
  SecurityStatus _updateSecurityStatus(
    SecurityStatus currentStatus,
    List<SecurityThreat> newThreats,
  ) {
    if (newThreats.isEmpty) return currentStatus;

    final updatedThreats = [...currentStatus.detectedThreats, ...newThreats];

    // Create updated status
    final hasCriticalThreats = updatedThreats.any(
      (threat) => threat.level == SecurityThreatLevel.critical,
    );

    final isDeviceSecure =
        !currentStatus.isJailbroken &&
        !currentStatus.isRooted &&
        !hasCriticalThreats;

    _lastStatus = SecurityStatus(
      isDeviceSecure: isDeviceSecure,
      isJailbroken: currentStatus.isJailbroken,
      isRooted: currentStatus.isRooted,
      lastChecked: DateTime.now(),
      detectedThreats: updatedThreats,
    );

    // Broadcast the updated status
    _securityStreamController.add(_lastStatus!);

    return _lastStatus!;
  } // Add additional checks or application-specific security logic here

  // when needed. The core security detection logic is now in the modular detector classes.
  // Dispose resources - Resource Management
  void dispose() {
    _securityStreamController.close();
  }
}
