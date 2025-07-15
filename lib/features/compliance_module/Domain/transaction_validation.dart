// lib/features/compliance_module/domain/entities/transaction_validation.dart
import '../domain/compliance_status.dart';
class TransactionData {
final String transactionId;
final double amount;
final String fromAccount;
final String toAccount;
final String appId;
final bool mfaCompleted;
final String? mfaMethod;
final DateTime timestamp;
final Map<String, dynamic>? metadata;
TransactionData({
required this.transactionId,
required this.amount,
required this.fromAccount,
required this.toAccount,
required this.appId,
required this.mfaCompleted,
this.mfaMethod,
required this.timestamp,
this.metadata,
});
factory TransactionData.fromMap(Map<String, dynamic> map) {
return TransactionData(
transactionId: map['transactionId'] ?? '',
amount: (map['amount'] ?? 0.0).toDouble(),
fromAccount: map['fromAccount'] ?? '',
toAccount: map['toAccount'] ?? '',
appId: map['appId'] ?? '',
mfaCompleted: map['mfaCompleted'] ?? false,
mfaMethod: map['mfaMethod'],
timestamp: DateTime.fromMillisecondsSinceEpoch(
map['timestamp'] ?? DateTime.now().millisecondsSinceEpoch,
),
metadata: map['metadata'],
);
}
} class ValidationResult {final bool isValid;
final List<ComplianceViolation> violations;
final String message;
final TransactionData transaction;
ValidationResult({
required this.isValid,
required this.violations,
required this.message,
required this.transaction,
});
static ValidationResult success(TransactionData transaction) {
return ValidationResult(
isValid: true,
violations: [],
message: 'Transaction complies with all regulations',
transaction: transaction,
);
} static ValidationResult failure(
TransactionData transaction,
List<ComplianceViolation> violations,
) {
return ValidationResult(
isValid: false,
violations: violations,
message: 'Transaction violates ${violations.length} compliance rule(s)',
transaction: transaction,
);
}
}