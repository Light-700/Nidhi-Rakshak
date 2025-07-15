import 'dart:async';
import 'package:flutter/foundation.dart';
import '../domain/compliance_status.dart';
import '../domain/transaction_validation.dart';
import 'rbi_compliance_checker.dart';
import 'npci_validation_service.dart';


class ComplianceService extends ChangeNotifier {
final RBIComplianceChecker _rbiChecker; // need to be implemented
final NPCIValidationService _npciValidator; //same here
final StreamController<ComplianceStatus> _statusController = StreamController.broadcast();
final List<ComplianceViolation> _violations = [];
ComplianceStatus? _lastStatus;
bool _isMonitoring = false;
ComplianceService(this._rbiChecker, this._npciValidator);
// Getters
Stream<ComplianceStatus> get complianceStream => _statusController.stream;
ComplianceStatus? get lastStatus => _lastStatus;
List<ComplianceViolation> get recentViolations => List.unmodifiable(_violations);
bool get isMonitoring => _isMonitoring;
// Start compliance monitoring
Future<void> startMonitoring() async {
if (_isMonitoring) return;
_isMonitoring = true;
notifyListeners();
// Perform initial compliance check
await checkCompliance();
// Set up periodic compliance checks (every 5 minutes)
Timer.periodic(Duration(minutes: 5), (timer) async {
if (!_isMonitoring) {
timer.cancel();
return;
}
await checkCompliance();
});
}

 // Stop compliance monitoring
void stopMonitoring() {
_isMonitoring = false;
notifyListeners();
}

 // Perform comprehensive compliance check
Future<ComplianceStatus> checkCompliance() async {
try {
// Run both RBI and NPCI compliance checks
final rbiResult = await _rbiChecker.checkRBICompliance();
final npciResult = await _npciValidator.checkNPCICompliance();
// Combine results
final allViolations = [...rbiResult.violations, ...npciResult.violations];
final status = ComplianceStatus(
isRbiCompliant: rbiResult.isCompliant,
isNpciCompliant: npciResult.isCompliant,
violations: allViolations,
lastChecked: DateTime.now(),
);
_lastStatus = status;
_statusController.add(status);// Update violations list (keep last 50)
_violations.addAll(allViolations);
if (_violations.length > 50) {
_violations.removeRange(0, _violations.length - 50);
}
 notifyListeners();
return status;
} catch (e) {
debugPrint('Error during compliance check: $e');
rethrow;
}
} 
// Validate a specific transaction
Future<ValidationResult> validateTransaction(Map<String, dynamic> transactionData) async{
try {
final transaction = TransactionData.fromMap(transactionData);
// Run validation through both checkers
final rbiValidation = await _rbiChecker.validateTransaction(transaction);
final npciValidation = await _npciValidator.validateTransaction(transaction);
final allViolations = [...rbiValidation.violations, ...npciValidation.violations];
if (allViolations.isNotEmpty) {
_violations.addAll(allViolations);
notifyListeners();
// Update compliance status
await checkCompliance();
return ValidationResult.failure(transaction, allViolations);
} 
return ValidationResult.success(transaction);
} catch (e) {
debugPrint('Error validating transaction: $e');
rethrow;
}
} 
// Get violations by severity
List<ComplianceViolation> getViolationsBySeverity(ViolationSeverity severity) {
return _violations.where((v) => v.severity == severity).toList();
}
 // Get violations by type
List<ComplianceViolation> getViolationsByType(String type) {
return _violations.where((v) => v.type.contains(type)).toList();
} 
// Clear violations (for testing purposes)
void clearViolations() {_violations.clear();
notifyListeners();
}
 @override
void dispose() {
_statusController.close();
super.dispose();
}
}