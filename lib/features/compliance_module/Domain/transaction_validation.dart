import '../Domain/compliance_status.dart';

class TransactionData {
  final String id;
  final double amount;
  final String fromAccount;
  final String toAccount;
  final String appId;
  final DateTime timestamp;
  final bool mfaCompleted;
  final String? mfaMethod;
  final String transactionType;
  final Map<String, dynamic> metadata;

  TransactionData({
    required this.id,
    required this.amount,
    required this.fromAccount,
    required this.toAccount,
    required this.appId,
    required this.timestamp,
    this.mfaCompleted = false,
    this.mfaMethod,
    this.transactionType = 'UPI',
    this.metadata = const {},
  });

  factory TransactionData.fromMap(Map<String, dynamic> map) {
    return TransactionData(
      id: map['id'] ?? '',
      amount: (map['amount'] ?? 0.0).toDouble(),
      fromAccount: map['fromAccount'] ?? '',
      toAccount: map['toAccount'] ?? '',
      appId: map['appId'] ?? '',
      timestamp: map['timestamp'] != null 
          ? DateTime.parse(map['timestamp'])
          : DateTime.now(),
      mfaCompleted: map['mfaCompleted'] ?? false,
      mfaMethod: map['mfaMethod'],
      transactionType: map['transactionType'] ?? 'UPI',
      metadata: map['metadata'] ?? {},
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'amount': amount,
      'fromAccount': fromAccount,
      'toAccount': toAccount,
      'appId': appId,
      'timestamp': timestamp.toIso8601String(),
      'mfaCompleted': mfaCompleted,
      'mfaMethod': mfaMethod,
      'transactionType': transactionType,
      'metadata': metadata,
    };
  }
}

class ValidationResult {
  final TransactionData transaction;
  final bool isValid;
  final String message;
  final List<ComplianceViolation> violations;

  ValidationResult({
    required this.transaction,
    required this.isValid,
    required this.message,
    required this.violations,
  });

  factory ValidationResult.success(TransactionData transaction) {
    return ValidationResult(
      transaction: transaction,
      isValid: true,
      message: 'Transaction validation successful',
      violations: [],
    );
  }

  factory ValidationResult.failure(
    TransactionData transaction,
    List<ComplianceViolation> violations,
  ) {
    return ValidationResult(
      transaction: transaction,
      isValid: false,
      message: 'Transaction validation failed: ${violations.length} violations found',
      violations: violations,
    );
  }
}
