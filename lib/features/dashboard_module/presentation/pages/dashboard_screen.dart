// lib/features/dashboard_module/presentation/pages/dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:nidhi_rakshak/features/background_module/services/security/security_models.dart';
import 'package:nidhi_rakshak/features/dashboard_module/presentation/widgets.dart';
import 'package:nidhi_rakshak/src/settings/settings_view.dart';
import 'package:nidhi_rakshak/features/background_module/services/service_provider.dart';
import 'package:nidhi_rakshak/features/background_module/services/security_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // ignore: unused_field
  bool _isLoading = false;

  // Security status
  SecurityStatus? _securityStatus;
  
  // Recent actions
  List<ActionItem> _recentActions = [];  @override
  void initState() {
    super.initState();
    
    // We need to use addPostFrameCallback since we need context
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupListeners();
      _loadData();
    });
  }
  
  void _setupListeners() {
    // Listen for security status updates
    ServiceProvider.of(context).securityService.securityStream.listen((status) {
      if (mounted) {
        setState(() {
          _securityStatus = status;
        });
      }
    });
    
    // Listen for action updates
    ServiceProvider.of(context).securityActionsService.actionsStream.listen((actions) {
      if (mounted) {
        setState(() {
          _recentActions = actions;
        });
      }
    });
  }
  
  Future<void> _loadData() async {
    // Get initial security status
    final securityStatus = ServiceProvider.of(context).securityService.lastStatus;
    
    // Get initial actions
    final actions = ServiceProvider.of(context).securityActionsService.getRecentActions();
    
    if (mounted) {
      setState(() {
        _securityStatus = securityStatus;
        _recentActions = actions;
      });
    }
  }
  @override
  Widget build(BuildContext context) {    
    // Use the security status from our service, or default to secure if null
    final securityStatus = _securityStatus ?? SecurityStatus.secure();
    
    return Scaffold(
      appBar: AppBar(
        title: Text('Security Dashboard'),
        backgroundColor: const Color.fromARGB(255, 255, 254, 254),
        foregroundColor: const Color.fromARGB(255, 0, 0, 0),
        actions: [
          IconButton(
            icon: Icon(Icons.settings),
            onPressed: () {
              // Navigate to settings
              Navigator.pushNamed(context, SettingsView.routeName);
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
                lastChecked: securityStatus.lastChecked,
                // Values from our security service
                isDeviceSecure: securityStatus.isDeviceSecure,
                isRbiCompliant: true, // To be implemented later
                isNpciCompliant: true, // To be implemented later
                isJailbroken: securityStatus.isJailbroken,
                isRooted: securityStatus.isRooted,
              ),

              SizedBox(height: 16),

              // Actions List Section
              ActionsListWidget(
                actions: _recentActions,
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

    try {
      // Get security service
      final securityService = ServiceProvider.of(context).securityService;
      
      // Refresh security status
      final updatedStatus = await securityService.refreshSecurityStatus();
      
      // Update state
      setState(() {
        _securityStatus = updatedStatus;
      });
    } catch (e) {
      // Handle errors
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error refreshing security data: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _refreshActions() async {
    try {
      // Get action service
      final actionsService = ServiceProvider.of(context).securityActionsService;
      
      // Refresh actions
      final actions = actionsService.getRecentActions();
      
      // Update state
      if (mounted) {
        setState(() {
          _recentActions = actions;
        });
      }
    } catch (e) {
      // Handle errors
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error refreshing actions: $e')),
      );
    }
  }

  Future<void> _runSecurityScan() async {
    // Show progress indicator
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Running security scan...')),
    );
    
    try {
      // Get security service
      final securityService = ServiceProvider.of(context).securityService;
      final actionsService = ServiceProvider.of(context).securityActionsService;
      
      // Run security scan
      final result = await securityService.runFullSecurityScan();
      
      // Record the action
      actionsService.recordSecurityScan(
        wasSuccessful: result.isDeviceSecure,
        details: result.detectedThreats.isNotEmpty 
            ? 'Found ${result.detectedThreats.length} security threats' 
            : null,
      );
      
      // Update UI
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.isDeviceSecure
                ? 'Security scan completed: Device secure'
                : 'Security scan completed: Issues found',
          ),
          backgroundColor: result.isDeviceSecure ? Colors.green : Colors.orange,
        ),
      );
    } catch (e) {
      // Handle errors
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error during security scan: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _checkCompliance() {
    // Since compliance checks are to be implemented later,
    // we'll keep this as a placeholder
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Compliance check initiated...')),
    );
    
    // This is where you would integrate with RBI/NPCI compliance checks later
  }
}
