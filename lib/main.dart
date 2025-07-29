import 'package:flutter/material.dart';
import 'package:nidhi_rakshak/features/background_module/services/security_actions_service.dart';
import 'package:nidhi_rakshak/features/background_module/services/security_service.dart';
import 'package:nidhi_rakshak/features/compliance_module/services/compliance_communication_service.dart';
import 'package:nidhi_rakshak/features/compliance_module/services/npci_validation_service.dart';
import 'package:nidhi_rakshak/features/compliance_module/services/rbi_compliance_checker.dart';

import 'src/app.dart';
import 'src/settings/settings_controller.dart';
import 'src/settings/settings_service.dart';
import 'features/background_module/services/service_provider.dart';
import 'features/compliance_module/services/compliance_service.dart';

void main() async {
  // Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();
  
  // Set up the SettingsController, which will glue user settings to multiple
  // Flutter Widgets.
  final settingsController = SettingsController(SettingsService());
  final complianceService = ComplianceService(RBIComplianceChecker(), NPCIValidationService());
  final securityService = SecurityService();
  final actionsService = SecurityActionsService();
  
  // Initialize communication service
  await ComplianceCommunicationService.initialize(
    complianceService,
    securityService,
    actionsService,
  );
  // Load the user's preferred theme while the splash screen is displayed.
  // This prevents a sudden theme change when the app is first displayed.
  await settingsController.loadSettings();

  // Run the app and pass in the SettingsController. The app listens to the
  // SettingsController for changes, then passes it further down to the
  // SettingsView.
  runApp(
    ServiceProvider(
      securityService: securityService,
      securityActionsService: actionsService,
      complianceService: complianceService,
      child: MyApp(settingsController: settingsController),
    ),
  );
}
