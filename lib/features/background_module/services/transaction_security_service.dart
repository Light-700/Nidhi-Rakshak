import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../models/transaction_models.dart';
import 'transaction_anomaly_detector.dart';
import '../../background_module/services/security_actions_service.dart';
import '../../dashboard_module/presentation/widgets.dart'; // Import for ActionItem, ActionType, ActionStatus

/// Main service for transaction security
class TransactionSecurityService {
  static final TransactionSecurityService _instance = TransactionSecurityService._internal();
  factory TransactionSecurityService() => _instance;
  TransactionSecurityService._internal();

  final TransactionAnomalyDetector _anomalyDetector = TransactionAnomalyDetector();
  final SecurityActionsService _actionsService = SecurityActionsService();

  // Stream for transaction security events
  final _securityEventController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get securityEventStream => _securityEventController.stream;

  /// Process a new transaction and check for anomalies
  Future<List<TransactionAnomaly>> processTransaction(Transaction transaction) async {
    try {
      debugPrint('Processing transaction: ${transaction.id}');

      // Analyze transaction for anomalies
      final anomalies = await _anomalyDetector.analyzeTransaction(transaction);

      // Record security action for each anomaly
      for (final anomaly in anomalies) {
        _actionsService.recordThreatDetection(
          threatName: anomaly.anomalyType,
          description: anomaly.description,
          wasBlocked: anomaly.isBlocked,
          details: 'Transaction ID: ${transaction.id}, Risk: ${anomaly.riskLevel.name}',
        );

        // Broadcast security event
        _securityEventController.add({
          'type': 'anomaly_detected',
          'anomaly': anomaly,
          'transaction': transaction,
        });
      }

      // Record successful processing
      _actionsService.recordAction(
        ActionItem(
          title: 'Transaction Processed',
          description: 'Transaction ${transaction.id} processed with ${anomalies.length} anomalies detected',
          type: ActionType.backgroundCheck,
          status: anomalies.isEmpty ? ActionStatus.success : ActionStatus.warning,
          timestamp: DateTime.now(),
          details: 'Amount: ₹${transaction.amount}, Type: ${transaction.type.name}',
        ),
      );

      return anomalies;
    } catch (e) {
      debugPrint('Error processing transaction: $e');
      
      // Record error
      _actionsService.recordAction(
        ActionItem(
          title: 'Transaction Processing Error',
          description: 'Failed to process transaction ${transaction.id}',
          type: ActionType.backgroundCheck,
          status: ActionStatus.failed,
          timestamp: DateTime.now(),
          details: 'Error: $e',
        ),
      );

      return [];
    }
  }

  /// Create a sample transaction for testing (emulator-friendly)
  Future<Transaction> createSampleTransaction({
    double? amount,
    TransactionType? type,
    String? description,
  }) async {
    final deviceInfo = await _getDeviceInfo();
    final random = Random();

    return Transaction(
      id: 'txn_${DateTime.now().millisecondsSinceEpoch}',
      accountId: 'acc_12345',
      amount: amount ?? (random.nextDouble() * 10000) + 100,
      type: type ?? TransactionType.values[random.nextInt(TransactionType.values.length)],
      description: description ?? 'Sample transaction',
      recipientId: 'recipient_${random.nextInt(1000)}',
      recipientName: 'Sample Recipient',
      timestamp: DateTime.now(),
      location: 'Emulator Location', // Emulator-friendly location
      deviceInfo: deviceInfo,
      metadata: {
        'isSimulated': true,
        'platform': Platform.operatingSystem,
      },
    );
  }

  /// Get device information (emulator-friendly)
  Future<String> _getDeviceInfo() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        return 'Android ${androidInfo.version.release} - ${androidInfo.model}';
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        return 'iOS ${iosInfo.systemVersion} - ${iosInfo.model}';
      }
      
      return 'Unknown Device';
    } catch (e) {
      return 'Emulator Device'; // Fallback for emulator
    }
  }

  /// Get transaction statistics
  Map<String, dynamic> getTransactionStats() {
    final transactions = _anomalyDetector.recentTransactions;
    final anomalies = _anomalyDetector.detectedAnomalies;

    if (transactions.isEmpty) {
      return {
        'totalTransactions': 0,
        'totalAnomalies': 0,
        'riskLevel': 'low',
        'lastTransaction': null,
      };
    }

    final totalAmount = transactions.map((t) => t.amount).reduce((a, b) => a + b);
    final highRiskAnomalies = anomalies.where((a) => 
        a.riskLevel == TransactionRiskLevel.high || 
        a.riskLevel == TransactionRiskLevel.critical
    ).length;

    String riskLevel = 'low';
    if (highRiskAnomalies > 3) {
      riskLevel = 'high';
    } else if (anomalies.length > 5) {
      riskLevel = 'medium';
    }

    return {
      'totalTransactions': transactions.length,
      'totalAmount': totalAmount,
      'averageAmount': totalAmount / transactions.length,
      'totalAnomalies': anomalies.length,
      'highRiskAnomalies': highRiskAnomalies,
      'riskLevel': riskLevel,
      'lastTransaction': transactions.last,
    };
  }

  /// Get anomaly detector instance
  TransactionAnomalyDetector get anomalyDetector => _anomalyDetector;

  /// Dispose resources
  void dispose() {
    _securityEventController.close();
    _anomalyDetector.dispose();
  }
}