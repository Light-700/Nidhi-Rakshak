
import 'dart:async';
import 'package:flutter/foundation.dart';
import '../Domain/compliance_status.dart';
import '../Domain/transaction_validation.dart';
import 'rbi_compliance_checker.dart';
import 'npci_validation_service.dart';


class ComplianceService extends ChangeNotifier {
final RBIComplianceChecker _rbiChecker;
final NPCIValidationService _npciValidator;
final StreamController<ComplianceStatus> _statusController = StreamController.broadcast();
final List<ComplianceViolation> _violations = [];
ComplianceStatus? _lastStatus;
bool _isMonitoring = false;

ComplianceService(this._rbiChecker, this._npciValidator);

Stream<ComplianceStatus> get complianceStream => _statusController.stream;
ComplianceStatus? get lastStatus => _lastStatus;
List<ComplianceViolation> get recentViolations => List.unmodifiable(_violations);
bool get isMonitoring => _isMonitoring;

Future<void> startMonitoring() async {
if (_isMonitoring) return;
_isMonitoring = true;
notifyListeners();

await checkCompliance();

Timer.periodic(Duration(minutes: 5), (timer) async {
if (!_isMonitoring) {
timer.cancel();
return;
}
await checkCompliance();
});
}

void stopMonitoring() {
_isMonitoring = false;
notifyListeners();
}

Future<ComplianceStatus> checkCompliance() async {
try {
final rbiResult = await _rbiChecker.checkRBICompliance();
final npciResult = await _npciValidator.checkNPCICompliance();

final allViolations = [...rbiResult.violations, ...npciResult.violations];
final status = ComplianceStatus(
isRbiCompliant: rbiResult.isCompliant,
isNpciCompliant: npciResult.isCompliant,
violations: allViolations,
lastChecked: DateTime.now(),
);

_lastStatus = status;
_statusController.add(status);

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

Future<ValidationResult> validateTransaction(Map<String, dynamic> transactionData) async{
try {
final transaction = TransactionData.fromMap(transactionData);

final rbiValidation = await _rbiChecker.validateTransaction(transaction);
final npciValidation = await _npciValidator.validateTransaction(transaction);

final allViolations = [...rbiValidation.violations, ...npciValidation.violations];

if (allViolations.isNotEmpty) {
_violations.addAll(allViolations);
notifyListeners();

await checkCompliance();
return ValidationResult.failure(transaction, allViolations);
} 

return ValidationResult.success(transaction);
} catch (e) {
debugPrint('Error validating transaction: $e');
rethrow;
}
} 

List<ComplianceViolation> getViolationsBySeverity(ViolationSeverity severity) {
return _violations.where((v) => v.severity == severity).toList();
}

List<ComplianceViolation> getViolationsByType(String type) {
return _violations.where((v) => v.type.contains(type)).toList();
} 

void clearViolations() {
_violations.clear();
notifyListeners();
}

@override
void dispose() {
_statusController.close();
super.dispose();
}
}
