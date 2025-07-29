import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'compliance_service.dart';
import '../../../features/background_module/services/security_service.dart';
import '../../../features/background_module/services/security_actions_service.dart';
import '../../../features/background_module/services/security/security_models.dart';
import '../../../features/dashboard_module/presentation/widgets.dart';


class ComplianceCommunicationService {
  static const platform = MethodChannel('com.ucobank.compliance');
  static ComplianceService? _complianceService;
  static SecurityService? _securityService;
  static SecurityActionsService? _actionsService;

  static Future initialize(
    ComplianceService complianceService,
    SecurityService securityService,
    SecurityActionsService actionsService,
  ) async {
    _complianceService = complianceService;
    _securityService = securityService;
    _actionsService = actionsService;
    
    platform.setMethodCallHandler(_handleMethodCall);
    
    try {
      await platform.invokeMethod('initializeComplianceMonitoring');
      debugPrint('Compliance communication initialized successfully');
    } catch (e) {
      debugPrint('Error initializing compliance communication: $e');
    }
  }


  static Future<dynamic> _handleMethodCall(MethodCall call) async {
  switch (call.method) {
    case 'validateTransaction':
      return await _validateTransaction(call.arguments);
    case 'checkCompliance':
      return await _checkCompliance();
    case 'reportViolation':
      return await _reportViolation(call.arguments);
    case 'validateTransactionFromNative':
      return await _handleNativeValidation(call.arguments);
    default:
      throw PlatformException(
        code: 'UNIMPLEMENTED',
        message: 'Method ${call.method} not implemented',
      );
  }
}

// ADD THIS METHOD: Handle validation requests from native Android bridge
static Future<Map<String, dynamic>> _handleNativeValidation(Map<String, dynamic> args) async {
  if (_complianceService == null) {
    return {
      'isValid': false,
      'message': 'Compliance service not initialized',
      'violations': ['SERVICE_NOT_INITIALIZED'],
    };
  }

  try {
    // Extract transaction data from native call
    final transactionData = Map<String, dynamic>.from(args);
    
    final result = await _complianceService!.validateTransaction(transactionData);
    
    if (!result.isValid && result.violations.isNotEmpty) {
      await _convertViolationsToSecurityThreats(result.violations, transactionData);
    }
    
    // Return actual validation result
    return {
      'isValid': result.isValid,
      'message': result.message,
      'violations': result.violations.map((v) => {
        'type': v.type,
        'description': v.description,
        'severity': v.severity.toString(),
        'timestamp': v.timestamp.toIso8601String(),
      }).toList(),
    };
  } catch (e) {
    debugPrint('Error in native validation: $e');
    return {
      'isValid': false,
      'message': 'Validation error: $e',
      'violations': ['VALIDATION_ERROR'],
    };
  }
}


  static Future<Map<String, dynamic>> _validateTransaction(Map<String, dynamic> transactionData) async {
    if (_complianceService == null) {
      throw PlatformException(
        code: 'NOT_INITIALIZED',
        message: 'Compliance service not initialized',
      );
    }

    try {
      final result = await _complianceService!.validateTransaction(transactionData);
      
      // If there are violations, convert them to security threats
      if (!result.isValid && result.violations.isNotEmpty) {
        await _convertViolationsToSecurityThreats(result.violations, transactionData);
      }
      
      return {
        'isValid': result.isValid,
        'message': result.message,
        'violations': result.violations.map((v) => {
          'type': v.type,
          'description': v.description,
          'severity': v.severity.toString(),
          'timestamp': v.timestamp.toIso8601String(),
        }).toList(),
      };
    } catch (e) {
      throw PlatformException(
        code: 'VALIDATION_ERROR',
        message: 'Error validating transaction: $e',
      );
    }
  }

  static Future<Map<String, dynamic>> _checkCompliance() async {
    if (_complianceService == null) {
      throw PlatformException(
        code: 'NOT_INITIALIZED',
        message: 'Compliance service not initialized',
      );
    }

    try {
      final status = await _complianceService!.checkCompliance();
      
      // If not compliant, create security threats for violations
      if (!status.isFullyCompliant && status.violations.isNotEmpty) {
        await _convertViolationsToSecurityThreats(status.violations, null);
      }
      
      return {
        'isRbiCompliant': status.isRbiCompliant,
        'isNpciCompliant': status.isNpciCompliant,
        'isFullyCompliant': status.isFullyCompliant,
        'violationCount': status.violations.length,
        'lastChecked': status.lastChecked.toIso8601String(),
      };
    } catch (e) {
      throw PlatformException(
        code: 'COMPLIANCE_ERROR',
        message: 'Error checking compliance: $e',
      );
    }
  }

  static Future<void> _convertViolationsToSecurityThreats(
    List<dynamic> violations,
    Map<String, dynamic>? transactionData,
  ) async {
    if (_securityService == null || _actionsService == null) return;

    for (final violation in violations) {
      // Create security threat based on violation
      final threat = SecurityThreat(
        name: 'Compliance Violation: ${violation.type}',
        description: violation.description,
        level: _mapViolationSeverityToThreatLevel(violation.severity),
      );

      // Add threat to security service
      await _securityService!.addComplianceThreat(threat);

      // Record action
      _actionsService!.recordAction(ActionItem(
        title: 'Compliance Violation Detected',
        description: violation.description,
        type: _mapViolationTypeToActionType(violation.type),
        status: ActionStatus.warning,
        timestamp: DateTime.now(),
        details: transactionData != null 
            ? 'Transaction ID: ${transactionData['transactionId']}'
            : 'Compliance check violation',
      ));
    }
  }

  static SecurityThreatLevel _mapViolationSeverityToThreatLevel(dynamic severity) {
    final severityStr = severity.toString().toLowerCase();
    switch (severityStr) {
      case 'violationseverity.critical':
        return SecurityThreatLevel.critical;
      case 'violationseverity.high':
        return SecurityThreatLevel.high;
      case 'violationseverity.medium':
        return SecurityThreatLevel.medium;
      default:
        return SecurityThreatLevel.low;
    }
  }

  static ActionType _mapViolationTypeToActionType(String violationType) {
    if (violationType.contains('RBI')) {
      return ActionType.rbiViolation;
    } else if (violationType.contains('NPCI')) {
      return ActionType.npciViolation;
    } else {
      return ActionType.complianceAlert;
    }
  }

  static Future<void> _reportViolation(Map<String, dynamic> violationData) async {
    debugPrint('Violation reported from external app: $violationData');
    
    // Record the violation report
    _actionsService?.recordAction(ActionItem(
      title: 'External Violation Report',
      description: violationData['description'] ?? 'Violation reported by external app',
      type: ActionType.complianceAlert,
      status: ActionStatus.warning,
      timestamp: DateTime.now(),
      details: 'App ID: ${violationData['appId']}',
    ));
  }

  static Future<void> notifyPaymentApp(String appId, bool isCompliant, [String? reason]) async {
    try {
      await platform.invokeMethod('notifyComplianceStatus', {
        'appId': appId,
        'isCompliant': isCompliant,
        'message': reason ?? (isCompliant ? 'Compliant' : 'Non-compliant'),
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Error notifying payment app: $e');
    }
  }
}
