import 'package:flutter/material.dart';
import 'package:nidhi_rakshak/features/background_module/services/security_actions_service.dart';
import 'package:nidhi_rakshak/features/background_module/services/security_service.dart';
import 'package:nidhi_rakshak/features/compliance_module/services/compliance_service.dart';
import 'package:nidhi_rakshak/features/compliance_module/services/rbi_compliance_checker.dart';
import 'package:nidhi_rakshak/features/compliance_module/services/npci_validation_service.dart';

class ServiceProvider extends InheritedWidget {
  final SecurityService securityService;
  final SecurityActionsService securityActionsService;
  final ComplianceService complianceService;

  const ServiceProvider({
    super.key,
    required this.securityService,
    required this.securityActionsService,
    required this.complianceService,
    required super.child,
  });

  static ServiceProvider of(BuildContext context) {
    final ServiceProvider? result = 
        context.dependOnInheritedWidgetOfExactType<ServiceProvider>();
    assert(result != null, 'No ServiceProvider found in context');
    return result!;
  }

  @override
  bool updateShouldNotify(ServiceProvider oldWidget) {
    return securityService != oldWidget.securityService ||
           securityActionsService != oldWidget.securityActionsService ||
           complianceService != oldWidget.complianceService; 
  }
}

class AppServices {
  static final SecurityService security = SecurityService();
  static final SecurityActionsService actions = SecurityActionsService();
//for compliance module
  static final RBIComplianceChecker _rbiChecker = RBIComplianceChecker();
  static final NPCIValidationService _npciValidator = NPCIValidationService();
  static final ComplianceService compliance = ComplianceService(_rbiChecker, _npciValidator);

  // Initialize all services
  static Future<void> initialize() async {
    await security.initialize();
  }

  // Dispose all services
  static void dispose() {
    security.dispose();
    actions.dispose();
    compliance.dispose(); 
  }
}
