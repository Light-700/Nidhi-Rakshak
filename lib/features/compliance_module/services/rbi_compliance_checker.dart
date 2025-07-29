// lib/features/compliance_module/services/rbi_compliance_checker.dart
import '../Domain/compliance_status.dart';
import '../Domain/transaction_validation.dart';
class RBIComplianceResult {
final bool isCompliant;
final List<ComplianceViolation> violations;
RBIComplianceResult({required this.isCompliant, required this.violations});
}
 class RBIComplianceChecker {
// RBI compliance rules
static const double mfaThreshold = 5000.0;
static const double dailyTransactionLimit = 100000.0;
static const int maxFailedAttempts = 3;

//just for simulation
Future<RBIComplianceResult> checkRBICompliance() async {
final violations = <ComplianceViolation>[];


await Future.delayed(Duration(milliseconds: 500)); 

return RBIComplianceResult(
isCompliant: violations.isEmpty,
violations: violations,
);
} 

//actual validation method
Future<ValidationResult> validateTransaction(TransactionData transaction) async {
  final violations = <ComplianceViolation>[];

  //  Rule 1: MFA required for transactions above ₹5000
  if (transaction.amount > mfaThreshold && !transaction.mfaCompleted) {
    violations.add(ComplianceViolation.rbiMfaViolation(
      transaction.amount,
      transaction.appId,
    ));
  }

  //  Rule 3: Validate MFA method if provided
  if (transaction.mfaCompleted && transaction.mfaMethod != null) {
    if (!_isValidMFAMethod(transaction.mfaMethod!)) {
      violations.add(ComplianceViolation(
        id: 'RBI_INVALID_MFA_${DateTime.now().millisecondsSinceEpoch}',
        type: 'RBI Invalid MFA Method',
        description: 'MFA method "${transaction.mfaMethod}" is not RBI approved',
        severity: ViolationSeverity.medium,
        timestamp: DateTime.now(),
        appId: transaction.appId,
        details: {'mfaMethod': transaction.mfaMethod},
      ));
    }
  }

  // Rule 4: Check transaction timing (maintenance window)
  final hour = transaction.timestamp.hour;
  if (hour >= 2 && hour < 4) {
    violations.add(ComplianceViolation(
      id: 'RBI_MAINTENANCE_${DateTime.now().millisecondsSinceEpoch}',
      type: 'RBI Maintenance Window Violation',
      description: 'Transaction attempted during system maintenance window (2 AM - 4 AM)',
      severity: ViolationSeverity.low,
      timestamp: DateTime.now(),
      appId: transaction.appId,
      details: {'transactionTime': transaction.timestamp.toIso8601String()},
    ));
  }

  //Rule 5: Check if account is temporarily blocked (enhancement)
  if (_isAccountBlocked(transaction.fromAccount)) {
    violations.add(ComplianceViolation(
      id: 'RBI_ACCOUNT_BLOCKED_${DateTime.now().millisecondsSinceEpoch}',
      type: 'RBI Account Temporarily Blocked',
      description: 'Account temporarily blocked due to $maxFailedAttempts failed authentication attempts',
      severity: ViolationSeverity.critical,
      timestamp: DateTime.now(),
      appId: transaction.appId,
      details: {'account': transaction.fromAccount, 'maxAttempts': maxFailedAttempts},
    ));
  }

  // Rule 6: Enhanced daily transaction limit check (enhancement)
  if (!await _checkDailyLimit(transaction.fromAccount, transaction.amount)) {
    violations.add(ComplianceViolation(
      id: 'RBI_DAILY_LIMIT_TOTAL_${DateTime.now().millisecondsSinceEpoch}',
      type: 'RBI Daily Transaction Limit Exceeded',
      description: 'Transaction would exceed daily limit of ₹${dailyTransactionLimit.toStringAsFixed(2)}',
      severity: ViolationSeverity.high,
      timestamp: DateTime.now(),
      appId: transaction.appId,
      details: {'amount': transaction.amount, 'dailyLimit': dailyTransactionLimit},
    ));
  }

  // Rule 7: Suspicious transaction pattern detection (enhancement)
  if (await _detectSuspiciousPattern(transaction)) {
    violations.add(ComplianceViolation(
      id: 'RBI_SUSPICIOUS_PATTERN_${DateTime.now().millisecondsSinceEpoch}',
      type: 'RBI Suspicious Transaction Pattern',
      description: 'Transaction pattern suggests potential fraud activity',
      severity: ViolationSeverity.high,
      timestamp: DateTime.now(),
      appId: transaction.appId,
      details: {'pattern': 'rapid_consecutive_transactions'},
    ));
  }

  // Store transaction for future reference if valid
  if (violations.isEmpty) {
    _storeTransactionHistory(transaction);
  }

  // Your existing return logic
  return violations.isEmpty
      ? ValidationResult.success(transaction)
      : ValidationResult.failure(transaction, violations);
}
// Helper method to validate MFA methods
bool _isValidMFAMethod(String method) {
const validMethods = ['SMS_OTP', 'EMAIL_OTP', 'BIOMETRIC', 'HARDWARE_TOKEN'];
return validMethods.contains(method.toUpperCase());
}
Future<bool> isAppRBIApproved(String appId) async {
// In a real implementation, this would check against RBI's approved app list
const approvedApps = ['com.ucobank.securepay', 'com.ucobank.main'];
return approvedApps.contains(appId);
}

// Transaction history tracking
final Map<String, List<TransactionData>> _dailyTransactionHistory = {};
final Map<String, int> _failedAttempts = {};

// Check daily transaction limits for an account
Future<bool> _checkDailyLimit(String accountNumber, double amount) async {
  final today = DateTime.now().toIso8601String().split('T')[0];
  final todayTransactions = _dailyTransactionHistory['$accountNumber-$today'] ?? [];
  
  final totalToday = todayTransactions.fold<double>(0, (sum, t) => sum + t.amount);
  return (totalToday + amount) <= dailyTransactionLimit;
}

// Check if account is temporarily blocked due to failed attempts
bool _isAccountBlocked(String accountNumber) {
  final key = '$accountNumber-${DateTime.now().toIso8601String().split('T')[0]}';
  return (_failedAttempts[key] ?? 0) >= maxFailedAttempts;
}

// Track failed authentication attempts

void _trackFailedAttempt(String accountNumber) {
  final key = '$accountNumber-${DateTime.now().toIso8601String().split('T')[0]}';
  _failedAttempts[key] = (_failedAttempts[key] ?? 0) + 1;
}//this is called when MFA fails

// Store transaction in history for pattern analysis
void _storeTransactionHistory(TransactionData transaction) {
  final key = '${transaction.fromAccount}-${DateTime.now().toIso8601String().split('T')[0]}';
  _dailyTransactionHistory[key] = _dailyTransactionHistory[key] ?? [];
  _dailyTransactionHistory[key]!.add(transaction);
}

// Detects suspicious transaction patterns
Future<bool> _detectSuspiciousPattern(TransactionData transaction) async {
  final key = '${transaction.fromAccount}-${DateTime.now().toIso8601String().split('T')[0]}';
  final todayTransactions = _dailyTransactionHistory[key] ?? [];
  
  // rapid consecutive transactions checking (more than 3 in 10 minutes)
  final tenMinutesAgo = DateTime.now().subtract(Duration(minutes: 10));
  final recentTransactions = todayTransactions.where(
    (t) => t.timestamp.isAfter(tenMinutesAgo)
  ).toList();
  
  return recentTransactions.length >= 3;
}

}
