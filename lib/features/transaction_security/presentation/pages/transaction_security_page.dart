import 'package:flutter/material.dart';
import 'package:nidhi_rakshak/features/background_module/models/transaction_models.dart';
import 'package:nidhi_rakshak/features/background_module/services/transaction_security_service.dart';
import 'dart:async';


class TransactionSecurityPage extends StatefulWidget {
  static const String routeName = '/transaction-security';

  const TransactionSecurityPage({Key? key}) : super(key: key);

  @override
  State<TransactionSecurityPage> createState() => _TransactionSecurityPageState();
}

class _TransactionSecurityPageState extends State<TransactionSecurityPage> {
  final TransactionSecurityService _securityService = TransactionSecurityService();
  late StreamSubscription _anomalySubscription;
  
  List<Transaction> _recentTransactions = [];
  List<TransactionAnomaly> _detectedAnomalies = [];
  Map<String, dynamic> _stats = {};
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initializeData();
    _setupAnomalyListener();
  }

  void _initializeData() {
    setState(() {
      _recentTransactions = _securityService.anomalyDetector.recentTransactions;
      _detectedAnomalies = _securityService.anomalyDetector.detectedAnomalies;
      _stats = _securityService.getTransactionStats();
    });
  }

  void _setupAnomalyListener() {
    _anomalySubscription = _securityService.anomalyDetector.anomalyStream.listen((anomaly) {
      if (mounted) {
        setState(() {
          _detectedAnomalies = _securityService.anomalyDetector.detectedAnomalies;
          _stats = _securityService.getTransactionStats();
        });
        
        // Show notification for new anomaly
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('New anomaly detected: ${anomaly.anomalyType}'),
            backgroundColor: _getRiskColor(anomaly.riskLevel),
            action: SnackBarAction(
              label: 'View',
              onPressed: () => _showAnomalyDetails(anomaly),
            ),
          ),
        );
      }
    });
  }

  Future<void> _simulateTransaction() async {
    setState(() => _isLoading = true);
    
    try {
      // Create a sample transaction
      final transaction = await _securityService.createSampleTransaction();
      
      // Process the transaction
      await _securityService.processTransaction(transaction);
      
      // Update UI
      _initializeData();
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Transaction simulated: ₹${transaction.amount.toStringAsFixed(2)}'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error simulating transaction: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showAnomalyDetails(TransactionAnomaly anomaly) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(anomaly.anomalyType),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Risk Level: ${anomaly.riskLevel.name.toUpperCase()}'),
            SizedBox(height: 8),
            Text(anomaly.description),
            SizedBox(height: 16),
            Text('Detected: ${_formatDateTime(anomaly.detectedAt)}'),
            if (anomaly.details.isNotEmpty) ...[
              SizedBox(height: 8),
              Text('Details:', style: TextStyle(fontWeight: FontWeight.bold)),
              ...anomaly.details.entries.map((e) => 
                Text('${e.key}: ${e.value}')
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  Color _getRiskColor(TransactionRiskLevel level) {
    switch (level) {
      case TransactionRiskLevel.low:
        return Colors.green;
      case TransactionRiskLevel.medium:
        return Colors.orange;
      case TransactionRiskLevel.high:
        return Colors.red;
      case TransactionRiskLevel.critical:
        return Colors.red.shade900;
    }
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Transaction Security'),
        backgroundColor: Colors.blue.shade600,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _initializeData,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => _initializeData(),
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Statistics Card
              _buildStatsCard(),
              SizedBox(height: 16),
              
              // Recent Anomalies
              _buildAnomaliesSection(),
              SizedBox(height: 16),
              
              // Recent Transactions
              _buildTransactionsSection(),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _isLoading ? null : _simulateTransaction,
        child: _isLoading 
            ? CircularProgressIndicator(color: Colors.white)
            : Icon(Icons.add),
        backgroundColor: Colors.blue.shade600,
        tooltip: 'Simulate Transaction',
      ),
    );
  }

  Widget _buildStatsCard() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Security Overview',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    'Transactions',
                    '${_stats['totalTransactions'] ?? 0}',
                    Icons.payment,
                    Colors.blue,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'Anomalies',
                    '${_stats['totalAnomalies'] ?? 0}',
                    Icons.warning,
                    Colors.orange,
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    'Risk Level',
                    '${_stats['riskLevel'] ?? 'Low'}'.toUpperCase(),
                    Icons.security,
                    _getRiskColorFromString(_stats['riskLevel'] ?? 'low'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 32),
        SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
      ],
    );
  }

  Widget _buildAnomaliesSection() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recent Anomalies',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            if (_detectedAnomalies.isEmpty)
              Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Column(
                    children: [
                      Icon(Icons.security, size: 48, color: Colors.green),
                      SizedBox(height: 8),
                      Text('No anomalies detected'),
                    ],
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                itemCount: _detectedAnomalies.take(5).length,
                itemBuilder: (context, index) {
                  final anomaly = _detectedAnomalies[index];
                  return ListTile(
                    leading: Icon(
                      Icons.warning,
                      color: _getRiskColor(anomaly.riskLevel),
                    ),
                    title: Text(anomaly.anomalyType),
                    subtitle: Text(anomaly.description),
                    trailing: Chip(
                      label: Text(anomaly.riskLevel.name.toUpperCase()),
                      backgroundColor: _getRiskColor(anomaly.riskLevel).withOpacity(0.2),
                    ),
                    onTap: () => _showAnomalyDetails(anomaly),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionsSection() {
    return Card(
      elevation: 4,
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Recent Transactions',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            if (_recentTransactions.isEmpty)
              Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text('No transactions yet'),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                itemCount: _recentTransactions.take(5).length,
                itemBuilder: (context, index) {
                  final transaction = _recentTransactions.reversed.toList()[index];
                  return ListTile(
                    leading: Icon(
                      _getTransactionIcon(transaction.type),
                      color: Colors.blue,
                    ),
                    title: Text('₹${transaction.amount.toStringAsFixed(2)}'),
                    subtitle: Text(
                      '${transaction.description}\n${_formatDateTime(transaction.timestamp)}',
                    ),
                    trailing: Text(transaction.type.name.toUpperCase()),
                    isThreeLine: true,
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  IconData _getTransactionIcon(TransactionType type) {
    switch (type) {
      case TransactionType.payment:
        return Icons.payment;
      case TransactionType.transfer:
        return Icons.swap_horiz;
      case TransactionType.withdrawal:
        return Icons.money_off;
      case TransactionType.deposit:
        return Icons.add_circle;
      case TransactionType.investment:
        return Icons.trending_up;
      case TransactionType.bill:
        return Icons.receipt;
      default:
        return Icons.account_balance_wallet;
    }
  }

  Color _getRiskColorFromString(String risk) {
    switch (risk.toLowerCase()) {
      case 'high':
        return Colors.red;
      case 'medium':
        return Colors.orange;
      default:
        return Colors.green;
    }
  }

  @override
  void dispose() {
    _anomalySubscription.cancel();
    super.dispose();
  }
}