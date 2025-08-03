import 'package:flutter/material.dart';
import 'package:nidhi_rakshak/features/background_module/services/security/security_models.dart';
import 'package:nidhi_rakshak/features/background_module/services/service_provider.dart';

class SecurityScannerScreen extends StatefulWidget {
  static const routeName = '/security-scanner';

  const SecurityScannerScreen({super.key});

  @override
  _SecurityScannerScreenState createState() => _SecurityScannerScreenState();
}

class _SecurityScannerScreenState extends State<SecurityScannerScreen> {
  bool _isLoading = false;
  SecurityStatus? _securityStatus;
  String _errorMessage = '';
  bool _hasInitialized = false;

  @override
  void initState() {
    super.initState();
  }

   @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    // Only initialize once
    if (!_hasInitialized) {
      _hasInitialized = true;
      _loadInitialStatus();
    }
  }

  Future<void> _loadInitialStatus() async {
    final securityService = ServiceProvider.of(context).securityService;
    setState(() {
      _securityStatus = securityService.lastStatus;
    });
  }

  Future<void> _runSecurityScan() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final securityService = ServiceProvider.of(context).securityService;
      final status = await securityService.runFullSecurityScan();

      setState(() {
        _securityStatus = status;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error running security scan: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Security Scanner')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildContent(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isLoading ? null : _runSecurityScan,
        label: const Text('Run Scan'),
        icon: const Icon(Icons.security),
      ),
    );
  }

  Widget _buildContent() {
    if (_errorMessage.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            _errorMessage,
            style: const TextStyle(color: Colors.red),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (_securityStatus == null) {
      return const Center(
        child: Text(
          'No security scan results available',
          style: TextStyle(color: Colors.white),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSecurityOverview(),
          const SizedBox(height: 24),
          _buildThreatsList(),
        ],
      ),
    );
  }

  Widget _buildSecurityOverview() {
    final status = _securityStatus!;
    final securityColor = status.isDeviceSecure ? Colors.green : Colors.red;
    final securityIcon = status.isDeviceSecure
        ? Icons.security
        : Icons.security_update_warning;
    final securityText = status.isDeviceSecure
        ? 'Your device is secure'
        : 'Security issues detected';

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Icon(securityIcon, color: securityColor, size: 48),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        securityText,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: securityColor,
                        ),
                      ),
                      Text(
                        'Last checked: ${_formatDateTime(status.lastChecked)}',
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            _buildSecurityDetail('Root Detection', status.isRooted),
            _buildSecurityDetail('Jailbreak Detection', status.isJailbroken),
            _buildSecurityDetail(
              'Suspicious Apps',
              status.detectedThreats.any(
                (t) =>
                    t.name.contains('Suspicious') || t.name.contains('Harmful'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSecurityDetail(String title, bool isIssueDetected) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(
            isIssueDetected ? Icons.error : Icons.check_circle,
            color: isIssueDetected ? Colors.red : Colors.green,
          ),
          const SizedBox(width: 8),
          Text(title),
          const Spacer(),
          Text(
            isIssueDetected ? 'Issue Detected' : 'Secure',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isIssueDetected ? Colors.red : Colors.green,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildThreatsList() {
    final threats = _securityStatus!.detectedThreats;

    if (threats.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Center(
            child: Text(
              'No security threats detected',
              style: TextStyle(fontSize: 16),
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Detected Security Threats',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        ...threats.map((threat) => _buildThreatCard(threat)),
      ],
    );
  }

  Widget _buildThreatCard(SecurityThreat threat) {
    Color threatColor;
    switch (threat.level) {
      case SecurityThreatLevel.low:
        threatColor = Colors.blue;
        break;
      case SecurityThreatLevel.medium:
        threatColor = Colors.orange;
        break;
      case SecurityThreatLevel.high:
        threatColor = Colors.deepOrange;
        break;
      case SecurityThreatLevel.critical:
        threatColor = Colors.red;
        break;
    }

    String threatLevel = threat.level.toString().split('.').last.toUpperCase();

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8.0,
                    vertical: 4.0,
                  ),
                  decoration: BoxDecoration(
                    color: threatColor,
                    borderRadius: BorderRadius.circular(4.0),
                  ),
                  child: Text(
                    threatLevel,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 8.0),
                Expanded(
                  child: Text(
                    threat.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8.0),
            Text(threat.description),
            if (threat.metadata != null && threat.metadata!.isNotEmpty) ...[
              const SizedBox(height: 8.0),
              const Divider(),
              const SizedBox(height: 8.0),
              _buildMetadata(threat.metadata!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMetadata(Map<String, dynamic> metadata) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: metadata.entries
          .where((entry) => entry.value != null)
          .map(
            (entry) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 2.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_formatMetadataKey(entry.key)}: ',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Expanded(child: Text(entry.value.toString())),
                ],
              ),
            ),
          )
          .toList(),
    );
  }

  String _formatMetadataKey(String key) {
    // Convert camelCase to Title Case
    final result = key.replaceAllMapped(
      RegExp(r'([A-Z])'),
      (match) => ' ${match.group(0)}',
    );
    return result[0].toUpperCase() + result.substring(1);
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
