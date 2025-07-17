// lib/features/compliance_module/services/npci_validation_service.dart
import '../domain/compliance_status.dart';
import '../domain/transaction_validation.dart';
class NPCIComplianceResult {
final bool isCompliant;
final List<ComplianceViolation> violations;
NPCIComplianceResult({required this.isCompliant, required this.violations});
}
 class NPCIValidationService {
// NPCI compliance rules
// ignore: constant_identifier_names
static const double UPI_TRANSACTION_LIMIT = 100000.0;
// ignore: constant_identifier_names
static const double RTGS_MIN_AMOUNT = 200000.0;
// ignore: constant_identifier_names
static const int MAX_TRANSACTIONS_PER_DAY = 10;

// Check overall NPCI compliance
Future<NPCIComplianceResult> checkNPCICompliance() async {
final violations = <ComplianceViolation>[];
// Simulate NPCI compliance check
await Future.delayed(Duration(milliseconds: 300));
// In a real app, this would check various NPCI compliance aspects
return NPCIComplianceResult(
isCompliant: violations.isEmpty,
violations: violations,
);
}
 // Validate transaction against NPCI guidelines
Future<ValidationResult> validateTransaction(TransactionData transaction) async {
final violations = <ComplianceViolation>[];
// Rule 1: UPI transaction limit validation
if (transaction.amount > UPI_TRANSACTION_LIMIT) {
violations.add(ComplianceViolation.npciLimitViolation(
transaction.amount,
transaction.appId,
));
}
// Rule 2: Check for valid account format
if (!_isValidAccountNumber(transaction.fromAccount) || !_isValidAccountNumber(transaction.toAccount)) {
violations.add(ComplianceViolation(
id: 'NPCI_INVALID_ACCOUNT_${DateTime.now().millisecondsSinceEpoch}',
type: 'NPCI Invalid Account Format',
description: 'Account number format does not comply with NPCI standards',
severity: ViolationSeverity.high,
timestamp: DateTime.now(),
appId: transaction.appId,
details: {
'fromAccount': transaction.fromAccount,
'toAccount': transaction.toAccount,
},
));
}

// Rule 3: Check transaction frequency
if (await _exceedsTransactionFrequency(transaction.fromAccount)) {
violations.add(ComplianceViolation(
id: 'NPCI_FREQUENCY_${DateTime.now().millisecondsSinceEpoch}',
type: 'NPCI Transaction Frequency Violation',
description: 'Account has exceeded maximum transactions per day (${MAX_TRANSACTIONS_PER_DAY})',
severity: ViolationSeverity.medium,
timestamp: DateTime.now(),
appId: transaction.appId,
details: {
'account': transaction.fromAccount, 
'maxTransactions': MAX_TRANSACTIONS_PER_DAY
},
));
}

// Rule 4: Validate transaction type appropriateness
if (transaction.amount >= RTGS_MIN_AMOUNT) {
// For large amounts, suggest RTGS instead of UPI
violations.add(ComplianceViolation(
id: 'NPCI_RTGS_RECOMMENDED_${DateTime.now().millisecondsSinceEpoch}',
type: 'NPCI Transaction Type Recommendation',
description: 'Amount ₹${transaction.amount.toStringAsFixed(2)} is eligible for RTGS, consider using RTGS for large transactions',
severity: ViolationSeverity.low,
timestamp: DateTime.now(),
appId: transaction.appId,
details: {'amount': transaction.amount, 'recommendedType': 'RTGS'},
));
}
 if (violations.where((v) => v.severity == ViolationSeverity.critical).isEmpty) {
    _trackTransactionFrequency(transaction.fromAccount);
  }

  return violations.isEmpty
      ? ValidationResult.success(transaction)
      : ValidationResult.failure(transaction, violations);
} 
// Helper method to validate account number format
bool _isValidAccountNumber(String accountNumber) {
// Simple validation - in real app, this would be more comprehensive
return accountNumber.length >= 10 &&
accountNumber.length <= 18 &&
RegExp(r'^[0-9]+$').hasMatch(accountNumber);} 

 // Validate if the app is NPCI certified
Future<bool> isAppNPCICertified(String appId) async {
// In real implementation, check against NPCI certified app list
const certifiedApps = ['com.ucobank.securepay', 'com.ucobank.main'];
return certifiedApps.contains(appId);
}

// Add these enhanced methods to your NPCIValidationService class

// Transaction frequency tracking
final Map<String, List<DateTime>> _transactionFrequency = {};

// Enhanced transaction frequency check
Future<bool> _exceedsTransactionFrequency(String accountNumber) async {
  final today = DateTime.now();
  final key = '$accountNumber-${today.toIso8601String().split('T')[0]}';
  
  final todayTransactions = _transactionFrequency[key] ?? [];
  
  // Clean up old entries (older than 24 hours)
  final cutoff = today.subtract(Duration(hours: 24));
  todayTransactions.removeWhere((timestamp) => timestamp.isBefore(cutoff));
  
  return todayTransactions.length >= MAX_TRANSACTIONS_PER_DAY;
}

// Track transaction frequency
void _trackTransactionFrequency(String accountNumber) {
  final today = DateTime.now();
  final key = '$accountNumber-${today.toIso8601String().split('T')[0]}';
  
  _transactionFrequency[key] = _transactionFrequency[key] ?? [];
  _transactionFrequency[key]!.add(today);
}




// Check if system is overloaded
Future<bool> _isSystemOverloaded() async {
  // Simulate system load check
  final totalTransactions = _transactionFrequency.values
      .expand((transactions) => transactions)
      .where((timestamp) => timestamp.isAfter(DateTime.now().subtract(Duration(minutes: 5))))
      .length;
  
  return totalTransactions > 100; // Arbitrary threshold
}

// Get NPCI compliance metrics
Future<Map<String, dynamic>> getComplianceMetrics() async {
  final today = DateTime.now().toIso8601String().split('T')[0];
  final totalTransactions = _transactionFrequency.values
      .expand((transactions) => transactions)
      .length;

  final highVolumeAccounts = _transactionFrequency.entries
      .where((entry) => entry.key.contains(today) && entry.value.length > 5)
      .length;

  return {
    'totalTransactionsToday': totalTransactions,
    'highVolumeAccounts': highVolumeAccounts,
    'systemLoad': await _isSystemOverloaded() ? 'high' : 'normal',
    'lastUpdated': DateTime.now().toIso8601String(),
  };
}

}