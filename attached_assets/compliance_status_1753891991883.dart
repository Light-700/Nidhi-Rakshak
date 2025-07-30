//import 'package:flutter/material.dart';

enum ComplianceType { rbi, npci, both }
enum ViolationSeverity { low, medium, high, critical }
class ComplianceStatus {
final bool isRbiCompliant;
final bool isNpciCompliant;
final List<ComplianceViolation> violations;
final DateTime lastChecked;
final Map<String, dynamic>? additionalData;
ComplianceStatus({
required this.isRbiCompliant,
required this.isNpciCompliant,
required this.violations,
required this.lastChecked,
this.additionalData,
});
bool get isFullyCompliant => isRbiCompliant && isNpciCompliant;
static ComplianceStatus compliant() {
return ComplianceStatus(
isRbiCompliant: true,
isNpciCompliant: true,
violations: [],
lastChecked: DateTime.now(),
);
} 
static ComplianceStatus nonCompliant(List<ComplianceViolation> violations) {
final rbiViolations = violations.where((v) => v.type.contains('RBI')).toList();
final npciViolations = violations.where((v) => v.type.contains('NPCI')).toList();
return ComplianceStatus(
isRbiCompliant: rbiViolations.isEmpty,
isNpciCompliant: npciViolations.isEmpty,
violations: violations,
lastChecked: DateTime.now(),
);
}
}
 class ComplianceViolation {
final String id;
final String type;
final String description;
final ViolationSeverity severity;
final DateTime timestamp;
final Map<String, dynamic>? details;
final String? appId;
ComplianceViolation({
required this.id,
required this.type,
required this.description,
required this.severity,
required this.timestamp,
this.details,
this.appId,
});
static ComplianceViolation rbiMfaViolation(double amount, String appId) {
return ComplianceViolation(
id: 'RBI_MFA_${DateTime.now().millisecondsSinceEpoch}',
type: 'RBI MFA Violation',
description: 'Transaction of ₹${amount.toStringAsFixed(2)} attempted without required MFA',
severity: amount > 10000 ? ViolationSeverity.critical : ViolationSeverity.high,
timestamp: DateTime.now(),
appId: appId,
details: {'amount': amount, 'mfaRequired': true},
);
} 
static ComplianceViolation npciLimitViolation(double amount, String appId) {
return ComplianceViolation(
id: 'NPCI_LIMIT_${DateTime.now().millisecondsSinceEpoch}',type: 'NPCI Transaction Limit Violation',
description: 'Transaction amount ₹${amount.toStringAsFixed(2)} exceeds daily limit',
severity: ViolationSeverity.high,
timestamp: DateTime.now(),
appId: appId,
details: {'amount': amount, 'dailyLimit': 100000},
);
}
}