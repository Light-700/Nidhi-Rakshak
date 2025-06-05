// lib/features/dashboard_module/presentation/pages/dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:myapp/features/dashboard_module/presentation/widgets.dart';

class DashboardScreen extends StatefulWidget {
  @override
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // These will be connected to your data sources later
  bool _isLoading = false;

  // Sample data - replace with real data from your modules
  final List<ActionItem> _sampleActions = [
    ActionItem(
      title: 'Device Security Scan',
      description: 'Checking for jailbreak/root access',
      type: ActionType.securityScan,
      status: ActionStatus.success,
      timestamp: DateTime.now().subtract(Duration(minutes: 5)),
    ),
    ActionItem(
      title: 'RBI Compliance Check',
      description: 'Verifying transaction limits',
      type: ActionType.complianceCheck,
      status: ActionStatus.success,
      timestamp: DateTime.now().subtract(Duration(minutes: 15)),
    ),
    ActionItem(
      title: 'Suspicious App Detected',
      description: 'Potential security risk identified',
      type: ActionType.threatDetection,
      status: ActionStatus.blocked,
      timestamp: DateTime.now().subtract(Duration(hours: 1)),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Security Dashboard'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(Icons.settings),
            onPressed: () {
              // Navigate to settings
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshDashboard,
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Security Status Section
              SecurityStatusIndicator(
                lastChecked: DateTime.now().subtract(Duration(minutes: 5)),
                // These values will come from your security module
                isDeviceSecure: true,
                isRbiCompliant: true,
                isNpciCompliant: true,
                isJailbroken: false,
                isRooted: false,
              ),

              SizedBox(height: 16),

              // Actions List Section
              ActionsListWidget(
                actions: _sampleActions,
                onRefresh: _refreshActions,
              ),

              SizedBox(height: 16),

              // Quick Actions Section
              _buildQuickActionsCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActionsCard() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quick Actions',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildQuickActionButton(
                    'Run Security Scan',
                    Icons.security,
                    () => _runSecurityScan(),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: _buildQuickActionButton(
                    'Check Compliance',
                    Icons.verified_user,
                    () => _checkCompliance(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionButton(
    String label,
    IconData icon,
    VoidCallback onPressed,
  ) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        padding: EdgeInsets.symmetric(vertical: 16),
      ),
      child: Column(
        children: [
          Icon(icon),
          SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }

  Future<void> _refreshDashboard() async {
    setState(() {
      _isLoading = true;
    });

    // This is where you'll connect to your security module
    // await securityService.refreshSecurityStatus();
    // await complianceService.checkCompliance();

    await Future.delayed(Duration(seconds: 2)); // Simulate loading

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _refreshActions() async {
    // Connect to your background service module
    // final newActions = await backgroundService.getRecentActions();
  }

  void _runSecurityScan() {
    // Connect to your security module
    // securityService.runFullSecurityScan();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Security scan initiated...')));
  }

  void _checkCompliance() {
    // Connect to your compliance module
    // complianceService.performComplianceCheck();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Compliance check initiated...')));
  }
}
