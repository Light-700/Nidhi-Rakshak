import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'compliance_service.dart';
import '../../../features/background_module/services/security_service.dart';
import '../../../features/background_module/services/security_actions_service.dart';
import '../../../features/background_module/services/security/security_models.dart';
import '../../../features/dashboard_module/presentation/widgets.dart';

class ComplianceCommunicationService {
  static const platform = MethodChannel('com.nidhi_rakshak.app/compliance');
  static ComplianceService? _complianceService;
  static SecurityService? _securityService;
  static SecurityActionsService? _actionsService;
  static bool _isInitialized = false;

  static Future<void> initialize(
    ComplianceService complianceService,
    SecurityService securityService,
    SecurityActionsService actionsService,
  ) async {
    if (_isInitialized) return;
    
    _complianceService = complianceService;
    _securityService = securityService;
    _actionsService = actionsService;
    
    // Set up handler to receive calls FROM Kotlin
    platform.setMethodCallHandler(_handleMethodCall);
    
    try {
      await platform.invokeMethod('initializeComplianceMonitoring');
      _isInitialized = true;
      debugPrint('Compliance communication initialized successfully');
    } catch (e) {
      debugPrint('Error initializing compliance communication: $e');
    }
  }

  static Future<dynamic> _handleMethodCall(MethodCall call) async {
  debugPrint('ComplianceCommunicationService received method call: ${call.method}');
  debugPrint('Arguments: ${call.arguments}');
  
  switch (call.method) {
    case 'validateTransaction':
      debugPrint(' Processing transaction validation request');
      final result = await _validateTransaction(call.arguments);
      debugPrint('Validation result: $result');
      return result;
    case 'checkCompliance':
      return await _checkCompliance();
    case 'reportViolation':
      return await _reportViolation(call.arguments);
    default:
      debugPrint(' Unknown method: ${call.method}');
      throw PlatformException(
        code: 'UNIMPLEMENTED',
        message: 'Method ${call.method} not implemented',
      );
  }
}

static Future<Map<String, dynamic>> _validateTransaction(dynamic arguments) async {
  debugPrint(' _validateTransaction function called with arguments type: ${arguments.runtimeType}');
  debugPrint('Arguments content: $arguments');
  
  if (_complianceService == null) {
    return {
      'isValid': false,
      'message': 'Compliance service not initialized',
      'violations': ['SERVICE_NOT_INITIALIZED'],
    };
  }
  
  try {
    final transactionData = Map<String, dynamic>.from(arguments);
    
    // Add debug logging for all data extraction
    debugPrint('🔍 Extracted transaction data: $transactionData');
    
    final amount = (transactionData['amount'] as num?)?.toDouble() ?? 0.0;
    final mfaCompleted = transactionData['mfaCompleted'] as bool? ?? false;
    final appId = transactionData['appId'] as String? ?? '';
    
    debugPrint('Parsed values - Amount: $amount, MFA: $mfaCompleted, AppId: $appId');
    
    // Apply RBI compliance rules
    final violations = <String>[];
    
    // RBI Limit Check: ₹1,00,000
    if (amount > 100000.0) {
      violations.add('RBI_TRANSACTION_LIMIT_EXCEEDED');
      debugPrint('RBI violation: Amount ₹$amount exceeds ₹1,00,000 limit');
    }
    
    // MFA requirement for transactions above ₹5,000
    if (amount > 5000.0 && !mfaCompleted) {
      violations.add('RBI_MFA_REQUIRED');
      debugPrint(' RBI violation: MFA required for amount ₹$amount');
    }
    
    debugPrint(' Violations list: $violations (type: ${violations.runtimeType})');
    
    final isValid = violations.isEmpty;
    final message = isValid 
      ? 'Transaction compliant with RBI/NPCI guidelines'
      : 'Transaction blocked: ${violations.length} violations detected';
    
    debugPrint('Validation result: $message');
    
    // Convert violations to security threats if needed
    if (!isValid && violations.isNotEmpty) {
      debugPrint('Converting ${violations.length} violations to security threats');
      await _convertViolationsToSecurityThreats(violations, transactionData);
      debugPrint(' Violation conversion completed');
    }
    
    return {
      'isValid': isValid,
      'clearance_granted': isValid,
      'message': message,
      'violations': violations,
      'amount': amount,
      'rbiCompliant': !violations.contains('RBI_TRANSACTION_LIMIT_EXCEEDED'),
      'npciCompliant': !violations.contains('RBI_MFA_REQUIRED'),
      'security_score': isValid ? 0.95 : 0.30,
      'mfa_verified': mfaCompleted,
    };
  } catch (e, stackTrace) {
    debugPrint(' Validation error: $e');
    debugPrint('Stack trace: $stackTrace');
    return {
      'isValid': false,
      'clearance_granted': false,
      'message': 'Compliance validation failed: $e',
      'violations': ['SYSTEM_ERROR'],
    };
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

  for (int i = 0; i < violations.length; i++) {
    try {
      final violation = violations[i];
      String violationType;
      String description;
      
      if (violation is String) {
        violationType = violation;
        description = _getViolationDescription(violation);
      } else if (violation is Map<String, dynamic>) {
        // Handle violation as a map
        violationType = violation['type']?.toString() ?? 'UNKNOWN_VIOLATION';
        description = violation['description']?.toString() ?? _getViolationDescription(violationType);
      } else {
        // Handle other object types safely
        violationType = violation.toString();
        description = _getViolationDescription(violationType);
        
        // Try to extract type and description if they exist
        try {
          final typeProperty = violation.runtimeType.toString().contains('type') 
            ? violation.type?.toString() 
            : null;
          if (typeProperty != null) {
            violationType = typeProperty;
          }
          
          final descProperty = violation.runtimeType.toString().contains('description')
            ? violation.description?.toString()
            : null;
          if (descProperty != null) {
            description = descProperty;
          }
        } catch (e) {
          debugPrint('Warning: Could not extract violation properties: $e');
        }
      }

      // Create security threat based on violation
      final threat = SecurityThreat(
        name: 'Compliance Violation: $violationType',
        description: description,
        level: _mapViolationSeverityToThreatLevel(violationType),
      );

      // Add threat to security service
      await _securityService!.addComplianceThreat(threat);

      // Record action
      _actionsService!.recordAction(ActionItem(
        title: 'Compliance Violation Detected',
        description: description,
        type: _mapViolationTypeToActionType(violationType),
        status: ActionStatus.warning,
        timestamp: DateTime.now(),
        details: transactionData != null 
            ? 'Transaction ID: ${transactionData['transactionId']}'
            : 'Compliance check violation',
      ));
    } catch (e) {
      debugPrint('Error processing violation at index $i: $e');
      // Continue processing other violations
      continue;
    }
  }
}

  static String _getViolationDescription(String violationType) {
    switch (violationType) {
      case 'RBI_TRANSACTION_LIMIT_EXCEEDED':
        return 'Transaction amount exceeds RBI limit of ₹1,00,000';
      case 'RBI_MFA_REQUIRED':
        return 'Multi-factor authentication required for transactions above ₹5,000';
      case 'SERVICE_NOT_INITIALIZED':
        return 'Compliance service not properly initialized';
      case 'SYSTEM_ERROR':
        return 'System error during compliance validation';
      default:
        return 'Compliance violation detected: $violationType';
    }
  }

  static SecurityThreatLevel _mapViolationSeverityToThreatLevel(String violationType) {
    switch (violationType) {
      case 'RBI_TRANSACTION_LIMIT_EXCEEDED':
        return SecurityThreatLevel.critical;
      case 'RBI_MFA_REQUIRED':
        return SecurityThreatLevel.high;
      case 'SERVICE_NOT_INITIALIZED':
      case 'SYSTEM_ERROR':
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

  // Public methods for external use
  static Future<Map<String, dynamic>> validateTransactionExternal(Map<String, dynamic> transactionData) async {
    if (!_isInitialized) {
      throw Exception('Compliance communication not initialized');
    }

    try {
      final result = await platform.invokeMethod('validateTransaction', transactionData);
      return Map<String, dynamic>.from(result);
    } catch (e) {
      debugPrint('Error validating transaction: $e');
      return {
        'isValid': false,
        'message': 'Unable to verify compliance - transaction blocked for security',
        'violations': ['COMMUNICATION_FAILURE'],
      };
    }
  }

  static Future<Map<String, dynamic>> checkComplianceExternal() async {
    if (!_isInitialized) {
      throw Exception('Compliance communication not initialized');
    }

    try {
      final result = await platform.invokeMethod('checkCompliance');
      return Map<String, dynamic>.from(result);
    } catch (e) {
      debugPrint('Error checking compliance: $e');
      return {
        'isRbiCompliant': false,
        'isNpciCompliant': false,
        'isFullyCompliant': false,
        'violationCount': 1,
        'lastChecked': DateTime.now().toIso8601String(),
      };
    }
  }
}
