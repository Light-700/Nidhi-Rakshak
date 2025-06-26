import 'package:flutter/foundation.dart';

/// Enum for transaction types
enum TransactionType {
  payment,
  transfer,
  withdrawal,
  deposit,
  investment,
  bill,
  other
}

/// Enum for transaction risk levels
enum TransactionRiskLevel {
  low,
  medium,
  high,
  critical
}

/// Model for a financial transaction
class Transaction {
  final String id;
  final String accountId;
  final double amount;
  final TransactionType type;
  final String description;
  final String recipientId;
  final String recipientName;
  final DateTime timestamp;
  final String location;
  final String deviceInfo;
  final Map<String, dynamic> metadata;

  const Transaction({
    required this.id,
    required this.accountId,
    required this.amount,
    required this.type,
    required this.description,
    required this.recipientId,
    required this.recipientName,
    required this.timestamp,
    required this.location,
    required this.deviceInfo,
    this.metadata = const {},
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'accountId': accountId,
      'amount': amount,
      'type': type.name,
      'description': description,
      'recipientId': recipientId,
      'recipientName': recipientName,
      'timestamp': timestamp.toIso8601String(),
      'location': location,
      'deviceInfo': deviceInfo,
      'metadata': metadata,
    };
  }

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      id: json['id'],
      accountId: json['accountId'],
      amount: json['amount'].toDouble(),
      type: TransactionType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => TransactionType.other,
      ),
      description: json['description'],
      recipientId: json['recipientId'],
      recipientName: json['recipientName'],
      timestamp: DateTime.parse(json['timestamp']),
      location: json['location'],
      deviceInfo: json['deviceInfo'],
      metadata: json['metadata'] ?? {},
    );
  }
}

/// Model for transaction anomaly
class TransactionAnomaly {
  final String id;
  final String transactionId;
  final TransactionRiskLevel riskLevel;
  final String anomalyType;
  final String description;
  final DateTime detectedAt;
  final Map<String, dynamic> details;
  final bool isBlocked;

  const TransactionAnomaly({
    required this.id,
    required this.transactionId,
    required this.riskLevel,
    required this.anomalyType,
    required this.description,
    required this.detectedAt,
    this.details = const {},
    this.isBlocked = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'transactionId': transactionId,
      'riskLevel': riskLevel.name,
      'anomalyType': anomalyType,
      'description': description,
      'detectedAt': detectedAt.toIso8601String(),
      'details': details,
      'isBlocked': isBlocked,
    };
  }

  factory TransactionAnomaly.fromJson(Map<String, dynamic> json) {
    return TransactionAnomaly(
      id: json['id'],
      transactionId: json['transactionId'],
      riskLevel: TransactionRiskLevel.values.firstWhere(
        (e) => e.name == json['riskLevel'],
        orElse: () => TransactionRiskLevel.low,
      ),
      anomalyType: json['anomalyType'],
      description: json['description'],
      detectedAt: DateTime.parse(json['detectedAt']),
      details: json['details'] ?? {},
      isBlocked: json['isBlocked'] ?? false,
    );
  }
}