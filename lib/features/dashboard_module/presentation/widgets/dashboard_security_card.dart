import 'package:flutter/material.dart';
import 'package:nidhi_rakshak/features/background_module/services/security/security_models.dart';
import 'package:nidhi_rakshak/features/security_module/presentation/pages/security_scanner_screen.dart';

/// A card that displays security information on the dashboard
class DashboardSecurityCard extends StatelessWidget {
  /// Security status to display
  final SecurityStatus securityStatus;

  /// Constructor
  const DashboardSecurityCard({
    Key? key,
    required this.securityStatus,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Process threats to separate system threats and app threats
    final systemThreats = securityStatus.detectedThreats.where(
      (threat) => !threat.name.contains('Suspicious App'),
    ).toList();

    // Create a map of risk levels to counts for app threats
    final appRiskStats = <String, int>{};
    for (final threat in securityStatus.detectedThreats) {
      if (threat.name.contains('Suspicious App')) {
        final level = threat.level.toString().split('.').last;
        final levelName = level[0].toUpperCase() + level.substring(1);
        appRiskStats[levelName] = (appRiskStats[levelName] ?? 0) + 1;
      }
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.blue.shade800,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Security Status',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh, color: Colors.white),
                    onPressed: () {
                      // Show message that security is being refreshed
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Refreshing security status...'),
                          duration: Duration(seconds: 1),
                        ),
                      );

                      // Navigate to security scanner screen
                      Navigator.of(context).pushNamed(
                        SecurityScannerScreen.routeName,
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildSecurityStatusRow(),
              const SizedBox(height: 16),
              _buildSecurityThreats(systemThreats, appRiskStats),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSecurityStatusRow() {
    final bool isSecure = securityStatus.isDeviceSecure;
    final Color statusColor = isSecure ? Colors.green : Colors.red;
    final IconData statusIcon = isSecure
        ? Icons.verified_user
        : Icons.gpp_bad;
    final String statusText = isSecure ? 'SECURE' : 'AT RISK';

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            statusIcon,
            color: statusColor,
            size: 36,
          ),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Device Integrity',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white70,
              ),
            ),
            Text(
              statusText,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSecurityThreats(
    List<SecurityThreat> systemThreats, 
    Map<String, int> appRiskStats
  ) {
    if (systemThreats.isEmpty && appRiskStats.isEmpty) {
      return const Text(
        'No security threats detected',
        style: TextStyle(color: Colors.white),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'SECURITY THREATS',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.white70,
          ),
        ),
        const SizedBox(height: 8),
        
        // Show critical system threats (developer mode, USB debugging, root)
        ...systemThreats.map((threat) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 4.0),
            child: Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: _getThreatColor(threat.level),
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    threat.name,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
        
        // App Risk Statistics
        if (appRiskStats.isNotEmpty) ...[
          const SizedBox(height: 8),
          const Text(
            'App Risk Statistics',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 4),
          ...appRiskStats.entries.map((entry) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 4.0),
              child: Text(
                '${entry.value} apps with ${entry.key.toLowerCase()} risk',
                style: const TextStyle(color: Colors.white),
              ),
            );
          }).toList(),
          
          // View apps list button
          const SizedBox(height: 8),
          Builder(
            builder: (context) => TextButton.icon(
              onPressed: () {
                // For now, just a placeholder
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('This feature will be implemented soon')),
                );
              },
              icon: const Icon(Icons.list, color: Colors.white70),
              label: const Text('View Apps List', style: TextStyle(color: Colors.white)),
              style: ButtonStyle(
                backgroundColor: MaterialStateProperty.all(Colors.white.withOpacity(0.1)),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Color _getThreatColor(SecurityThreatLevel level) {
    switch (level) {
      case SecurityThreatLevel.low:
        return Colors.green;
      case SecurityThreatLevel.medium:
        return Colors.orange;
      case SecurityThreatLevel.high:
        return Colors.deepOrange;
      case SecurityThreatLevel.critical:
        return Colors.red;
    }
  }
}
