// lib/features/dashboard_module/presentation/widgets/security_status_indicator.dart
import 'package:flutter/material.dart';

class SecurityStatusIndicator extends StatelessWidget {
  final bool isDeviceSecure;
  final bool isRbiCompliant;
  final bool isNpciCompliant;
  final bool isJailbroken;
  final bool isRooted;
  final DateTime lastChecked;

  const SecurityStatusIndicator({
    super.key,
    this.isDeviceSecure = false,
    this.isRbiCompliant = false,
    this.isNpciCompliant = false,
    this.isJailbroken = true,
    this.isRooted = true,
    required this.lastChecked,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Main Status Header
            Row(
              children: [
                Icon(
                  isDeviceSecure ? Icons.security : Icons.warning,
                  color: isDeviceSecure ? Colors.green : Colors.red,
                  size: 32,
                ),
                SizedBox(width: 12),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Device Security Status',
                        style: TextStyle( 
                          color: Theme.of(context).colorScheme.primary, 
                          fontSize: 22,
                        ),
                      ),
                      Text(
                        isDeviceSecure ? 'SECURE' : 'COMPROMISED',
                        style: TextStyle(
                          color: isDeviceSecure ? Colors.green : Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            SizedBox(height: 20),

            // Security Check Items
            _buildStatusItem(
              'Device Integrity',
              !isJailbroken && !isRooted,
              isJailbroken || isRooted ? 'Device compromised' : 'Secure',
            ),

            _buildStatusItem(
              'RBI Compliance',
              isRbiCompliant,
              isRbiCompliant ? 'All checks passed' : 'Violations detected',
            ),

            _buildStatusItem(
              'NPCI Guidelines',
              isNpciCompliant,
              isNpciCompliant ? 'Compliant' : 'Non-compliant',
            ),

            SizedBox(height: 16),

            // Last Updated
            Row(
              children: [
                Icon(Icons.access_time, size: 16, color: Colors.grey),
                SizedBox(width: 4),
                Text(
                  'Last checked: ${_formatTime(lastChecked)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusItem(String label, bool isGood, String subtitle) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          Icon(
            isGood ? Icons.check_circle : Icons.error,
            color: isGood ? Colors.green : Colors.red,
            size: 20,
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontWeight: FontWeight.w500)),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }
}

enum ActionType {
securityScan,
complianceCheck,
threatDetection,
policyEnforcement,
backgroundCheck,
rbiViolation,
npciViolation,
transactionBlocked,
complianceAlert,
}

enum ActionStatus { success, failed, blocked, warning }

class ActionItem {
  final String title;
  final String description;
  final ActionType type;
  final ActionStatus status;
  final DateTime timestamp;
  final String? details;

  ActionItem({
    required this.title,
    required this.description,
    required this.type,
    required this.status,
    required this.timestamp,
    this.details,
  });
}

class ActionsListWidget extends StatefulWidget {

  final List<ActionItem> actions;
  final VoidCallback? onRefresh;
  const ActionsListWidget({super.key, required this.actions, this.onRefresh});

  @override
  State<ActionsListWidget> createState() => _ActionsListWidgetState();
}

class _ActionsListWidgetState extends State<ActionsListWidget> {
 /* bool _showAllActions = false; 

  void _toggleShowAll() {
    setState(() { 
      _showAllActions = !_showAllActions;
    });
  }*/  //not required for now 

  @override
  Widget build(BuildContext context) {
    
    return Card(
      elevation: 4,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    'Recent Security Actions',
                    style: TextStyle( 
                          color: Theme.of(context).colorScheme.primary, 
                          fontSize: 22,
                        ),
                        overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                IconButton(icon: Icon(Icons.refresh), onPressed: widget.onRefresh),
              ],
            ),
          ),

          // Actions List
           if (widget.actions.isEmpty)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.history, size: 48, color: Colors.grey),
                    SizedBox(height: 8),
                    Text('No recent actions'),
                  ],
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true, 
              physics: NeverScrollableScrollPhysics(),
              itemCount: widget.actions.length > 5  ? 5: widget.actions.length, // Show only first 5 actions 
              separatorBuilder: (context, index) => Divider(height: 1),
              itemBuilder: (context, index) {
                final action = widget.actions[index];
                return _buildActionTile(action);
              },
            ),

          // Show More/Show Less Button
          if (widget.actions.length > 5)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Center(
                child: TextButton.icon(
                  onPressed: _showAllActionsDialog,
                  label: Text('View All Actions'), 
                ),
              ),
            ),
        ],
      ),
    );
  }

    void _showAllActionsDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog.fullscreen(
          child: Scaffold(
            appBar: AppBar(
              title: Text(
                'Recent Security Actions',
                style: TextStyle(fontSize: 18),
              ),
              leading: IconButton(
                icon: Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            body:ListView.separated(
                    padding: EdgeInsets.all(16.0),
                    itemCount: widget.actions.length, // Shows ALL actions
                    separatorBuilder: (context, index) => Divider(height: 1),
                    itemBuilder: (context, index) {
                      final action = widget.actions[index];
                      return _buildActionTile(action); 
                    },
                  ),
          ),
        );
      },
    );
  }

  Widget _buildActionTile(ActionItem action) {
    return ListTile(
      leading: _getActionIcon(action.type, action.status),
      title: Text(action.title),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(action.description),
          SizedBox(height: 2),
          Text(
            _formatTime(action.timestamp),
            style: TextStyle(fontSize: 11, color: Colors.grey),
          ),
        ],
      ),
      trailing: _getStatusBadge(action.status),
      onTap: () {
        // Show action details
        _showActionDetails(action);
      },
    );
  }

  Widget _getActionIcon(ActionType type, ActionStatus status) {
    IconData iconData;
    Color iconColor;

    switch (type) {
      case ActionType.securityScan:
        iconData = Icons.security;
        break;
      case ActionType.complianceCheck:
        iconData = Icons.verified_user;
        break;
      case ActionType.threatDetection:
        iconData = Icons.warning;
        break;
      case ActionType.policyEnforcement:
        iconData = Icons.policy;
        break;
      case ActionType.backgroundCheck:
        iconData = Icons.schedule;
        break;
      case ActionType.rbiViolation:
        iconData=Icons.assignment;
        break;
      case ActionType.npciViolation:
        iconData=Icons.assignment;
        break;
      case ActionType.transactionBlocked:
        iconData=Icons.cancel_presentation;
        break;
      case ActionType.complianceAlert:
        iconData=Icons.error_outline;
        break;
    }

    switch (status) {
      case ActionStatus.success:
        iconColor = Colors.green;
        break;
      case ActionStatus.failed:
        iconColor = Colors.red;
        break;
      case ActionStatus.blocked:
        iconColor = Colors.orange;
        break;
      case ActionStatus.warning:
        iconColor = Colors.amber;
        break;
    }

    return CircleAvatar(
      radius: 16,
      backgroundColor: iconColor.withValues(alpha: 0.1),
      child: Icon(iconData, color: iconColor, size: 16),
    );
  }

  Widget _getStatusBadge(ActionStatus status) {
    String text;
    Color color;

    switch (status) {
      case ActionStatus.success:
        text = 'SUCCESS';
        color = Colors.green;
        break;
      case ActionStatus.failed:
        text = 'FAILED';
        color = Colors.red;
        break;
      case ActionStatus.blocked:
        text = 'BLOCKED';
        color = Colors.orange;
        break;
      case ActionStatus.warning:
        text = 'WARNING';
        color = Colors.amber;
        break;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  void _showActionDetails(ActionItem action) {
    // unimplemented
  }
}
