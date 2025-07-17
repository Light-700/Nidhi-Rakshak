import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'compliance_service.dart';

class ComplianceCommunicationService {
  static const platform = MethodChannel('com.ucobank.compliance');
  static ComplianceService? _complianceService;

  static Future<void> initialize(ComplianceService complianceService) async {
    _complianceService = complianceService;
    platform.setMethodCallHandler(_handleMethodCall);
    
    try {
      await platform.invokeMethod('initializeComplianceMonitoring');
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
      default:
        throw PlatformException(
          code: 'UNIMPLEMENTED',
          message: 'Method ${call.method} not implemented',
        );
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
      
      return {
        'isValid': result.isValid,
        'message': result.message,
        'violations': result.violations.map((v) => {
          'type': v.type,
          'description': v.description,
          'severity': v.severity.toString(),
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

  static Future<void> _reportViolation(Map<String, dynamic> violationData) async {
    // Handle violation reporting from external apps
    debugPrint('Violation reported from external app: $violationData');
  }

  // Method to send compliance status to mock payment app
  static Future<void> notifyPaymentApp(String appId, bool isCompliant) async {
    try {
      await platform.invokeMethod('notifyComplianceStatus', {
        'appId': appId,
        'isCompliant': isCompliant,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      debugPrint('Error notifying payment app: $e');
    }
  }
}
