import 'package:flutter/material.dart';
import 'package:nidhi_rakshak/features/background_module/services/security/security_models.dart';
import 'package:nidhi_rakshak/features/dashboard_module/presentation/widgets.dart';
import 'package:nidhi_rakshak/src/settings/settings_view.dart';
import 'package:nidhi_rakshak/features/background_module/services/service_provider.dart';
import 'package:nidhi_rakshak/src/theme/gradient_theme.dart';

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
    
    return Container(
      decoration: BoxDecoration(
      gradient: AppGradients.getBackgroundGradient(context),
    ),
      child: Scaffold(
     backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text('Security Dashboard'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Theme.of(context).brightness == Brightness.dark 
          ? Colors.white 
          : Colors.black,
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
                  isRbiCompliant: false, // To be implemented later
                  isNpciCompliant: false, // To be implemented later
                  isJailbroken: securityStatus.isJailbroken,
                  isRooted: securityStatus.isRooted,
                ),
      
                SizedBox(height: 16),
                  // Security Threats Section
                _buildSecurityThreatsCard(),
                
                SizedBox(height: 16),
                
                // Suspicious Apps Section
                _buildSuspiciousAppsCard(),
                
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

  // Widget to display security threats
  Widget _buildSecurityThreatsCard() {
    // Use the security status from our service, or default to secure if null
    final securityStatus = _securityStatus ?? SecurityStatus.secure();
    final threats = securityStatus.detectedThreats;
    
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Security Threats',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                    fontSize: 22,
                  ),
                ),
                threats.isEmpty 
                  ? Icon(Icons.verified, color: Colors.green)
                  : Icon(Icons.warning_amber, color: Colors.orange)
              ],
            ),
            SizedBox(height: 16),
            if (threats.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Icon(
                        Icons.security, 
                        color: Colors.green, 
                        size: 48,
                      ),
                      SizedBox(height: 8),
                      Text(
                        'No security threats detected',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                itemCount: threats.length,
                itemBuilder: (context, index) {
                  final threat = threats[index];
                  Color threatColor;
                  IconData threatIcon;
                  
                  // Choose color and icon based on threat level
                  switch (threat.level) {
                    case SecurityThreatLevel.critical:
                      threatColor = Colors.red;
                      threatIcon = Icons.error;
                      break;
                    case SecurityThreatLevel.high:
                      threatColor = Colors.orange;
                      threatIcon = Icons.warning;
                      break;
                    case SecurityThreatLevel.medium:
                      threatColor = Colors.amber;
                      threatIcon = Icons.info;
                      break;                    case SecurityThreatLevel.low:
                      threatColor = Colors.blue;
                      threatIcon = Icons.info_outline;
                      break;
                  }
                  
                  return ListTile(
                    leading: Icon(
                      threatIcon,
                      color: threatColor,
                    ),
                    title: Text(
                      threat.name,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(threat.description),
                    trailing: _getThreatLevelBadge(threat.level),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
  
  // Helper widget to display threat level badge
  Widget _getThreatLevelBadge(SecurityThreatLevel level) {
    String text;
    Color color;
    
    switch (level) {
      case SecurityThreatLevel.critical:
        text = 'CRITICAL';
        color = Colors.red;
        break;
      case SecurityThreatLevel.high:
        text = 'HIGH';
        color = Colors.orange;
        break;
      case SecurityThreatLevel.medium:
        text = 'MEDIUM';
        color = Colors.amber;
        break;
      case SecurityThreatLevel.low:
        text = 'LOW';
        color = Colors.blue;
        break;
    }
    
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha:0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }
  
  // Get suspicious app threats from all threats
  List<SecurityThreat> _getSuspiciousAppThreats() {
    final securityStatus = _securityStatus ?? SecurityStatus.secure();
    return securityStatus.detectedThreats.where((threat) => 
      threat.name.contains('Suspicious App') || 
      threat.name.contains('Harmful App')
    ).toList();
  }
  
  // Widget to display suspicious apps
  Widget _buildSuspiciousAppsCard() {
    final suspiciousApps = _getSuspiciousAppThreats();
    
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    'Suspicious Applications',
                    style:TextStyle( 
                          color: Theme.of(context).colorScheme.primary, 
                          fontSize: 22,
                        ),
                  ),
                ),
                suspiciousApps.isEmpty 
                  ? Icon(Icons.verified, color: Colors.green)
                  : Icon(Icons.warning_amber, color: Colors.red)
              ],
            ),
            SizedBox(height: 16),
            if (suspiciousApps.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Icon(
                        Icons.app_blocking, 
                        color: Colors.green, 
                        size: 48,
                      ),
                      SizedBox(height: 8),
                      Text(
                        'No suspicious apps detected',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              Column(
                children: [
                  Text(
                    'The following apps might pose a security risk:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 12),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: NeverScrollableScrollPhysics(),
                    itemCount: suspiciousApps.length,
                    itemBuilder: (context, index) {
                      final app = suspiciousApps[index];
                      
                      // Extract app name if available
                      String appName = "Unknown App";
                      String appDescription = app.description;
                      
                      // Try to parse out app name from the description
                      if (appDescription.contains(":")) {
                        final parts = appDescription.split(":");
                        if (parts.length > 1) {
                          appName = parts[1].trim();
                          // Remove the app name from the description
                          appDescription = parts[0];
                        }
                      }
                      
                      return Card(
                        elevation: 2,
                        margin: EdgeInsets.symmetric(vertical: 8.0),
                        child: ListTile(
                          leading: Icon(
                            Icons.dangerous,
                            color: Colors.red,
                          ),
                          title: Text(
                            appName,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(appDescription),
                              SizedBox(height: 4),
                              _getThreatLevelBadge(app.level),
                            ],
                          ),
                          trailing: ElevatedButton(
                            
                            onPressed: () => _showAppDetails(app),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: Colors.white,
                            ),
                            child: Text('Info'),
                          ),
                          isThreeLine: true,
                        ),
                      );
                    },
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
  
  // Show detailed information about a suspicious app
  void _showAppDetails(SecurityThreat app) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber, color: Colors.red),
            SizedBox(width: 8),
            Expanded(child: Text('Suspicious App Details')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Type of Threat:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(app.name),
            SizedBox(height: 16),
            Text(
              'Description:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(app.description),
            SizedBox(height: 16),
            Text(
              'Risk Level:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            _getThreatLevelBadge(app.level),
            SizedBox(height: 16),
            Text(
              'Recommended Action:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(_getRecommendedAction(app.level)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // In a real app, this would navigate to app settings or uninstall flow
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('This would navigate to app settings in a real app')),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: Text('Take Action'),
          ),
        ],
      ),
    );
  }
  
  // Get recommended action based on threat level
  String _getRecommendedAction(SecurityThreatLevel level) {
    switch (level) {
      case SecurityThreatLevel.critical:
        return 'Uninstall this app immediately. It poses a severe security risk to your device and financial data.';
      case SecurityThreatLevel.high:
        return 'Consider uninstalling this app as soon as possible, or restrict its permissions until further investigation.';
      case SecurityThreatLevel.medium:
        return 'Review this app\'s permissions and usage. Restrict access to sensitive data if possible.';
      case SecurityThreatLevel.low:
        return 'Monitor this app\'s behavior and consider reviewing its permissions.';
    }
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
      if(!mounted) return;
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
            : 'No security threats detected',
      );
      
      // Update security status in state
      setState(() {
        _securityStatus = result;
      });
      
      // Update UI
      if(!mounted) return;
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
      if(!mounted) return;
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
    
    // This is where we would integrate with RBI/NPCI compliance checks later
  }
}
