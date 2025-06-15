import 'dart:async';

import 'package:myapp/features/dashboard_module/presentation/widgets.dart';

class SecurityActionsService {
  static final SecurityActionsService _instance = SecurityActionsService._internal();
  factory SecurityActionsService() => _instance;

  SecurityActionsService._internal();

  // Store recent actions
  final List<ActionItem> _recentActions = [];
  List<ActionItem> get recentActions => List.unmodifiable(_recentActions);

  // Stream controller to broadcast action updates
  final _actionsStreamController = StreamController<List<ActionItem>>.broadcast();
  Stream<List<ActionItem>> get actionsStream => _actionsStreamController.stream;

  // Add a new action
  void recordAction(ActionItem action) {
    _recentActions.insert(0, action); // Add to front of list
    
    // Keep only the most recent 50 actions
    if (_recentActions.length > 50) {
      _recentActions.removeLast();
    }
    
    // Broadcast the update
    _actionsStreamController.add(_recentActions);
  }

  // Get recent actions (with optional limit)
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

  // Dispose resources
  void dispose() {
    _actionsStreamController.close();
  }
}
