import 'package:flutter/material.dart';
import 'package:nidhi_rakshak/features/background_module/services/security/security_models.dart';
import 'package:nidhi_rakshak/features/dashboard_module/presentation/widgets.dart';
import 'package:nidhi_rakshak/src/settings/settings_view.dart';
import 'package:nidhi_rakshak/features/background_module/services/service_provider.dart';

import 'package:nidhi_rakshak/features/compliance_module/Domain/compliance_status.dart';
import 'package:nidhi_rakshak/src/theme/gradient_theme.dart';
import 'package:nidhi_rakshak/features/dashboard_module/presentation/pages/more_apps_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  // ignore: library_private_types_in_public_api
  _DashboardScreenState createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // ignore: unused_field
  bool _isLoading = false;

  SecurityStatus? _securityStatus;

  ComplianceStatus? _complianceStatus;
  List<ActionItem> _recentActions = [];
  @override
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
    ServiceProvider.of(context).securityActionsService.actionsStream.listen((
      actions,
    ) {
      if (mounted) {
        setState(() {
          _recentActions = actions;
        });
      }
    });

    final complianceService = ServiceProvider.of(context).complianceService;
    complianceService.complianceStream.listen((status) {
      if (mounted) {
        setState(() {
          _complianceStatus = status;
        });
      }
    });
  }

  Future<void> _loadData() async {
    // Get initial security status
    final securityStatus =
        ServiceProvider.of(context).securityService.lastStatus;

    // Get initial actions
    final actions =
        ServiceProvider.of(context).securityActionsService.getRecentActions();

    final complianceService = ServiceProvider.of(context).complianceService;
    final complianceStatus = complianceService.lastStatus;

    if (mounted) {
      setState(() {
        _securityStatus = securityStatus;
        _recentActions = actions;
        _complianceStatus = complianceStatus;
      });
    }
  }

  List<SecurityThreat> _getComplianceThreats() {
    final securityStatus = _securityStatus ?? SecurityStatus.secure();
    return securityStatus.detectedThreats
        .where(
          (threat) =>
              threat.name.contains('Compliance Violation') ||
              threat.name.contains('RBI') ||
              threat.name.contains('NPCI'),
        )
        .toList();
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
          title: const Text('Security Dashboard'),
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor:
              Theme.of(context).brightness == Brightness.dark
                  ? Colors.white
                  : Colors.black,
          actions: [
            IconButton(
              icon: const Icon(Icons.security),
              tooltip: 'Security Scanner',
              onPressed: () {
                // Navigate to security scanner
                Navigator.pushNamed(context, '/security-scanner');
              },
            ),
            IconButton(
              icon: const Icon(Icons.apps),
              tooltip: 'More Apps',
              onPressed: () {
                // Navigate to more apps
                Navigator.pushNamed(context, MoreAppsScreen.routeName);
              },
            ),
            IconButton(
              icon: const Icon(Icons.settings),
              tooltip: 'Settings',
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
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SecurityStatusIndicator(
                  lastChecked: securityStatus.lastChecked,
                  // Values from our security service - ensure device is shown as not secure if threats exist
                  isDeviceSecure: securityStatus.isDeviceSecure && securityStatus.detectedThreats.isEmpty,
                  isRbiCompliant: _complianceStatus?.isRbiCompliant ?? false,
                  isNpciCompliant: _complianceStatus?.isNpciCompliant ?? false,
                  isJailbroken: securityStatus.isJailbroken,
                  isRooted: securityStatus.isRooted,
                ),

                const SizedBox(height: 16),
                // Security Threats Section
                _buildSecurityThreatsCard(),

                const SizedBox(height: 16),

                // Suspicious Apps Section
                _buildSuspiciousAppsCard(),

                const SizedBox(height: 16),

                // Actions List Section
                ActionsListWidget(
                  actions: _recentActions,
                  onRefresh: _refreshActions,
                ),

                const SizedBox(height: 16),

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
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildQuickActionButton(
                    'Run Security Scan',
                    Icons.security,
                    () => _runSecurityScan(),
                  ),
                ),
                const SizedBox(width: 12),
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
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }

  // Widget to display security threats
  Widget _buildSecurityThreatsCard() {
    final securityStatus = _securityStatus ?? SecurityStatus.secure();
    final allThreats = securityStatus.detectedThreats;
    final complianceThreats = _getComplianceThreats();
    
    // Filter to show only system threats (not app threats) and critical app threats
    final threats = allThreats.where((threat) => 
      // Include system threats (not app threats)
      (!threat.name.contains('Suspicious App')) ||
      // Or include critical app threats
      (threat.name.contains('Suspicious App') && threat.level == SecurityThreatLevel.critical)
    ).toList();

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
                    : Icon(Icons.warning_amber, color: Colors.orange),
              ],
            ),

            // Show compliance status if there are compliance threats
            if (complianceThreats.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error, color: Colors.red, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Not RBI/NPCI Compliant',
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 16),
            if (threats.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Icon(Icons.security, color: Colors.green, size: 48),
                      SizedBox(height: 8),
                      Text(
                        'No security threats detected',
                        style: TextStyle(fontSize: 16, color: Colors.green),
                      ),
                    ],
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: threats.length,
                itemBuilder: (context, index) {
                  final threat = threats[index];
                  Color threatColor;
                  IconData threatIcon;

                  // Special handling for compliance threats
                  bool isComplianceThreat = threat.name.contains(
                    'Compliance Violation',
                  );
                  
                  // Is this an app threat?
                  bool isAppThreat = threat.name.contains('Suspicious App');

                  switch (threat.level) {
                    case SecurityThreatLevel.critical:
                      threatColor = Colors.red;
                      threatIcon = isComplianceThreat 
                          ? Icons.gavel 
                          : (isAppThreat ? Icons.phone_android : Icons.error);
                      break;
                    case SecurityThreatLevel.high:
                      threatColor = Colors.orange;
                      threatIcon = isComplianceThreat 
                          ? Icons.gavel 
                          : (isAppThreat ? Icons.phone_android : Icons.warning);
                      break;
                    case SecurityThreatLevel.medium:
                      threatColor = Colors.amber;
                      threatIcon = isComplianceThreat 
                          ? Icons.gavel 
                          : (isAppThreat ? Icons.phone_android : Icons.info);
                      break;
                    case SecurityThreatLevel.low:
                      threatColor = Colors.blue;
                      threatIcon = isComplianceThreat 
                          ? Icons.gavel 
                          : (isAppThreat ? Icons.phone_android : Icons.info_outline);
                      break;
                  }

                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    color: isComplianceThreat
                        ? Colors.red.withOpacity(0.05)
                        : null,
                    child: ListTile(
                      leading: Icon(threatIcon, color: threatColor),
                      title: Text(
                        threat.name,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(threat.description),
                          if (isComplianceThreat) ...[
                            const SizedBox(height: 4),
                            const Text(
                              'This violation affects RBI/NPCI compliance',
                              style: TextStyle(
                                color: Colors.red,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ],
                      ),
                      trailing: _getThreatLevelBadge(threat.level),
                      isThreeLine: isComplianceThreat,
                    ),
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
        color: color.withOpacity(0.2),
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
    return securityStatus.detectedThreats
        .where(
          (threat) =>
              threat.name.contains('Suspicious App') ||
              threat.name.contains('Harmful App'),
        )
        .toList();
  }

  // Widget to display app risk statistics
  Widget _buildSuspiciousAppsCard() {
    final suspiciousApps = _getSuspiciousAppThreats();
    
    // Create a map of risk levels to counts
    final Map<String, int> riskStats = {
      'Critical': 0,
      'High': 0,
      'Medium': 0,
      'Low': 0,
    };
    
    // Count apps by risk level
    for (final app in suspiciousApps) {
      switch (app.level) {
        case SecurityThreatLevel.critical:
          riskStats['Critical'] = (riskStats['Critical'] ?? 0) + 1;
          break;
        case SecurityThreatLevel.high:
          riskStats['High'] = (riskStats['High'] ?? 0) + 1;
          break;
        case SecurityThreatLevel.medium:
          riskStats['Medium'] = (riskStats['Medium'] ?? 0) + 1;
          break;
        case SecurityThreatLevel.low:
          riskStats['Low'] = (riskStats['Low'] ?? 0) + 1;
          break;
      }
    }

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
                    'App Risk Statistics',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontSize: 22,
                    ),
                  ),
                ),
                suspiciousApps.isEmpty
                    ? Icon(Icons.verified, color: Colors.green)
                    : Icon(Icons.warning_amber, color: Colors.orange),
              ],
            ),
            const SizedBox(height: 16),
            if (suspiciousApps.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Icon(Icons.app_blocking, color: Colors.green, size: 48),
                      SizedBox(height: 8),
                      Text(
                        'No suspicious apps detected',
                        style: TextStyle(fontSize: 16, color: Colors.green),
                      ),
                    ],
                  ),
                ),
              )
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Display statistics for each risk level
                  ...riskStats.entries
                      .where((entry) => entry.value > 0)
                      .map((entry) => Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Row(
                              children: [
                                Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: _getRiskColor(entry.key),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${entry.value} apps with ${entry.key.toLowerCase()} risk',
                                  style: const TextStyle(fontSize: 16),
                                ),
                              ],
                            ),
                          ))
                      .toList(),
                  
                  const SizedBox(height: 16),
                  
                  // View apps list button
                  Center(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        // Navigate to the More Apps screen
                        Navigator.pushNamed(context, MoreAppsScreen.routeName);
                      },
                      icon: const Icon(Icons.list),
                      label: const Text('View Apps List'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
  
  // Helper method to get color for risk level
  Color _getRiskColor(String riskLevel) {
    switch (riskLevel) {
      case 'Critical':
        return Colors.red;
      case 'High':
        return Colors.deepOrange;
      case 'Medium':
        return Colors.orange;
      case 'Low':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  // Future implementation of app details will go here

  Future<void> _refreshDashboard() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final securityService = ServiceProvider.of(context).securityService;

      final updatedStatus = await securityService.refreshSecurityStatus();

      setState(() {
        _securityStatus = updatedStatus;
      });
    } catch (e) {
      if (!mounted) return;

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
      final actionsService = ServiceProvider.of(context).securityActionsService;

      final actions = actionsService.getRecentActions();

      if (mounted) {
        setState(() {
          _recentActions = actions;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error refreshing actions: $e')));
    }
  }

  Future<void> _runSecurityScan() async {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Running security scan...')));

    try {
      final securityService = ServiceProvider.of(context).securityService;
      final actionsService = ServiceProvider.of(context).securityActionsService;

      // Run security scan
      final result = await securityService.runFullSecurityScan();

      // Record the action
      actionsService.recordSecurityScan(
        wasSuccessful: result.isDeviceSecure,
        details:
            result.detectedThreats.isNotEmpty
                ? 'Found ${result.detectedThreats.length} security threats'
                : 'No security threats detected',
      );

      // Update security status in state
      setState(() {
        _securityStatus = result;
      });

      // Update UI
      if (!mounted) return;
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
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error during security scan: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _checkCompliance() async {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Running compliance check...')));

    try {
      final complianceService = ServiceProvider.of(context).complianceService;
      final actionsService = ServiceProvider.of(context).securityActionsService;

      // Run compliance check
      final result = await complianceService.checkCompliance();

      // Record the action
      actionsService.recordAction(
        ActionItem(
          title: 'Compliance Check',
          description:
              result.isFullyCompliant
                  ? 'All compliance checks passed'
                  : 'Found ${result.violations.length} compliance violations',
          type: ActionType.complianceCheck,
          status:
              result.isFullyCompliant
                  ? ActionStatus.success
                  : ActionStatus.warning,
          timestamp: DateTime.now(),
          details:
              'RBI: ${result.isRbiCompliant ? "✓" : "✗"}, NPCI: ${result.isNpciCompliant ? "✓" : "✗"}',
        ),
      );

      setState(() {
        _complianceStatus = result;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result.isFullyCompliant
                  ? 'Compliance check passed: All systems compliant'
                  : 'Compliance issues found: ${result.violations.length} violations',
            ),
            backgroundColor:
                result.isFullyCompliant ? Colors.green : Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error during compliance check: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
