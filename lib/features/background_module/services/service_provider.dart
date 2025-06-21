import 'package:flutter/material.dart';
import 'package:nidhi_rakshak/features/background_module/services/security_actions_service.dart';
import 'package:nidhi_rakshak/features/background_module/services/security_service.dart';

class ServiceProvider extends InheritedWidget {
  final SecurityService securityService;
  final SecurityActionsService securityActionsService;

  const ServiceProvider({
    super.key,
    required this.securityService,
    required this.securityActionsService,
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
    return false; // Services don't change
  }
}

class AppServices {
  static final SecurityService security = SecurityService();
  static final SecurityActionsService actions = SecurityActionsService();

  // Initialize all services
  static Future<void> initialize() async {
    await security.initialize();
  }

  // Dispose all services
  static void dispose() {
    security.dispose();
    actions.dispose();
  }
}
