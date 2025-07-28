import 'dart:async';

import 'package:nidhi_rakshak/features/dashboard_module/presentation/widgets.dart';

class SecurityActionsService {
  // The class uses the Singleton pattern to ensure only one instance exists throughout the application
  static final SecurityActionsService _instance = SecurityActionsService._internal();
  factory SecurityActionsService() => _instance;

  SecurityActionsService._internal();

  // Store recent actions - Action Storage and Access
  // Maintains an internal list of security actions
  // Provides read-only access through the getter (using unmodifiable to prevent external modifications)
  final List<ActionItem> _recentActions = [];
  List<ActionItem> get recentActions => List.unmodifiable(_recentActions);

  // Stream controller to broadcast action updates -  Event Broadcasting
  // Uses a broadcast StreamController to notify listeners when actions are added
  // Components (like UI widgets) can subscribe to this stream to get real-time updates
  final _actionsStreamController = StreamController<List<ActionItem>>.broadcast();
  Stream<List<ActionItem>> get actionsStream => _actionsStreamController.stream;

  // Recording Actions - Add a new action
  void recordAction(ActionItem action) {
    _recentActions.insert(0, action); // Add to front of list
    
    // Keep only the most recent 50 actions
    if (_recentActions.length > 50) {
      _recentActions.removeLast();
    }
    
    // Broadcast the update
    _actionsStreamController.add(_recentActions);
  }

  // Retrieving Actions - Get recent actions (with optional limit)
  List<ActionItem> getRecentActions({int limit = 10}) {
    return _recentActions.take(limit).toList();
  }

  // Record a security scan action
  void recordSecurityScan({required bool wasSuccessful, String? details}) {
    final action = ActionItem(
      title: 'Device Security Scan',
      description: wasSuccessful 
          ? 'Security scan completed successfully'
          : 'Security scan encountered issues',
      type: ActionType.securityScan,
      status: wasSuccessful ? ActionStatus.success : ActionStatus.warning,
      timestamp: DateTime.now(),
      details: details,
    );
    recordAction(action);
  }

  // Record a threat detection
  void recordThreatDetection({
    required String threatName,
    required String description,
    required bool wasBlocked,
    String? details,
  }) {
    final action = ActionItem(
      title: 'Threat Detected: $threatName',
      description: description,
      type: ActionType.threatDetection,
      status: wasBlocked ? ActionStatus.blocked : ActionStatus.warning,
      timestamp: DateTime.now(),
      details: details,
    );
    recordAction(action);
  }

  // Record a background security check
  void recordBackgroundCheck({required bool wasSuccessful, String? details}) {
    final action = ActionItem(
      title: 'Background Security Check',
      description: wasSuccessful 
          ? 'Routine security check completed'
          : 'Security check found issues',
      type: ActionType.backgroundCheck,
      status: wasSuccessful ? ActionStatus.success : ActionStatus.warning,
      timestamp: DateTime.now(),
      details: details,
    );
    recordAction(action);
  }

  // Record VPN detection
  void recordVpnDetection({
    required bool vpnDetected,
    required String confidenceLevel,
    List<String> detectedVpnApps = const [],
    String? details,
  }) {
    final action = ActionItem(
      title: vpnDetected ? 'VPN Connection Detected' : 'VPN Scan Completed',
      description: vpnDetected 
          ? 'VPN connection detected with $confidenceLevel confidence'
          : 'No VPN connection detected',
      type: ActionType.vpnDetection,
      status: vpnDetected ? ActionStatus.warning : ActionStatus.success,
      timestamp: DateTime.now(),
      details: details ?? (detectedVpnApps.isNotEmpty 
          ? 'VPN Apps: ${detectedVpnApps.join(', ')}'
          : null),
    );
    recordAction(action);
  }

  // Dispose resources
  // Properly closes the stream controller when the service is no longer needed
  void dispose() {
    _actionsStreamController.close();
  }
}

/*
This service is likely used for:

1. Logging Security Events: Recording when security scans, checks, and threat detections occur
2. Displaying Activity History: Showing users a log of recent security-related actions
3. Real-time Notifications: Updating the UI immediately when new security events happen
4. Security Audit Trail: Maintaining a history of security-related activities
*/