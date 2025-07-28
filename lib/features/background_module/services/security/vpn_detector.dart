import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'security_models.dart';

/// Class for detecting VPN connections and VPN-related applications
class VpnDetector {
  /// Platform channel for native VPN checks
  static const MethodChannel _platform = MethodChannel('com.nidhi_rakshak/security_checks');

  /// Comprehensive VPN detection using multiple methods
  static Future<VpnDetectionResult> detectVpn() async {
    final detectionMethods = <String, bool>{};
    final vpnApps = <String>[];
    final vpnThreats = <SecurityThreat>[];

    try {
      // Method 1: Network Interface Detection
      final hasVpnInterface = await _checkVpnNetworkInterfaces();
      detectionMethods['Network Interface'] = hasVpnInterface;
      
      if (hasVpnInterface) {
        debugPrint('VPN detected via network interface');
        vpnThreats.add(SecurityThreat(
          name: 'Active VPN Connection',
          description: 'VPN tunnel interface detected. This may indicate an active VPN connection.',
          level: SecurityThreatLevel.medium,
          metadata: {'detection_method': 'network_interface'},
        ));
      }

      // Method 2: VPN App Detection
      final installedVpnApps = await _checkInstalledVpnApps();
      vpnApps.addAll(installedVpnApps);
      detectionMethods['VPN Apps'] = installedVpnApps.isNotEmpty;

      if (installedVpnApps.isNotEmpty) {
        debugPrint('VPN apps detected: ${installedVpnApps.join(', ')}');
        vpnThreats.add(SecurityThreat(
          name: 'VPN Applications Detected',
          description: 'Found ${installedVpnApps.length} VPN application(s): ${installedVpnApps.join(', ')}',
          level: SecurityThreatLevel.low,
          metadata: {
            'detection_method': 'app_packages',
            'vpn_apps': installedVpnApps,
          },
        ));
      }

      // Method 3: System VPN Service Detection (Android/iOS specific)
      final hasActiveVpnService = await _checkActiveVpnService();
      detectionMethods['VPN Service'] = hasActiveVpnService;

      if (hasActiveVpnService) {
        debugPrint('Active VPN service detected');
        vpnThreats.add(SecurityThreat(
          name: 'Active VPN Service',
          description: 'System VPN service is currently active and running.',
          level: SecurityThreatLevel.high,
          metadata: {'detection_method': 'vpn_service'},
        ));
      }

      // Method 4: DNS Analysis
      final hasSuspiciousDns = await _checkDnsConfiguration();
      detectionMethods['DNS Analysis'] = hasSuspiciousDns;

      if (hasSuspiciousDns) {
        debugPrint('Suspicious DNS configuration detected');
        vpnThreats.add(SecurityThreat(
          name: 'Suspicious DNS Configuration',
          description: 'Non-standard DNS servers detected, which may indicate VPN usage.',
          level: SecurityThreatLevel.low,
          metadata: {'detection_method': 'dns_analysis'},
        ));
      }

      // Method 5: Network Route Analysis
      final hasVpnRoutes = await _checkNetworkRoutes();
      detectionMethods['Network Routes'] = hasVpnRoutes;

      if (hasVpnRoutes) {
        debugPrint('VPN routes detected in routing table');
        vpnThreats.add(SecurityThreat(
          name: 'VPN Network Routes',
          description: 'VPN-specific routes found in the network routing table.',
          level: SecurityThreatLevel.medium,
          metadata: {'detection_method': 'network_routes'},
        ));
      }

      return VpnDetectionResult(
        isVpnDetected: vpnThreats.isNotEmpty,
        detectionMethods: detectionMethods,
        installedVpnApps: vpnApps,
        vpnThreats: vpnThreats,
        lastChecked: DateTime.now(),
      );

    } catch (e) {
      debugPrint('Error during VPN detection: $e');
      return VpnDetectionResult(
        isVpnDetected: false,
        detectionMethods: detectionMethods,
        installedVpnApps: vpnApps,
        vpnThreats: vpnThreats,
        lastChecked: DateTime.now(),
        error: e.toString(),
      );
    }
  }

  /// Method 1: Check for VPN network interfaces (tun0, ppp0, etc.)
  static Future<bool> _checkVpnNetworkInterfaces() async {
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        // Try to get network interfaces through platform channel
        try {
          final result = await _platform.invokeMethod('getNetworkInterfaces');
          if (result != null && result is List) {
            final interfaces = result.cast<String>();
            
            // Common VPN interface names
            final vpnInterfaces = ['tun0', 'tun1', 'tun2', 'ppp0', 'ppp1', 'utun0', 'utun1', 'utun2'];
            
            for (final vpnInterface in vpnInterfaces) {
              if (interfaces.any((interface) => interface.toLowerCase().contains(vpnInterface))) {
                debugPrint('VPN interface found: $vpnInterface');
                return true;
              }
            }
          }
        } catch (e) {
          debugPrint('Platform method getNetworkInterfaces not implemented: $e');
        }

        // Fallback: Try to read network interfaces directly (limited on mobile)
        if (Platform.isAndroid) {
          return await _checkAndroidNetworkInterfaces();
        }
      }
    } catch (e) {
      debugPrint('Error checking VPN network interfaces: $e');
    }
    
    return false;
  }

  /// Android-specific network interface checking
  static Future<bool> _checkAndroidNetworkInterfaces() async {
    try {
      // Try to execute netstat or ip commands (may not work on all devices)
      final result = await Process.run('ip', ['link', 'show']);
      if (result.exitCode == 0) {
        final output = result.stdout.toString().toLowerCase();
        final vpnPatterns = ['tun', 'ppp', 'vpn'];
        
        for (final pattern in vpnPatterns) {
          if (output.contains(pattern)) {
            debugPrint('VPN interface pattern found: $pattern');
            return true;
          }
        }
      }
    } catch (e) {
      debugPrint('Error checking Android network interfaces: $e');
    }
    
    return false;
  }

  /// Method 2: Check for installed VPN applications
  static Future<List<String>> _checkInstalledVpnApps() async {
    final vpnApps = <String>[];
    
    try {
      // Common VPN app package names
      final vpnPackages = [
        // Popular VPN services
        'com.nordvpn.android',
        'com.expressvpn.vpn',
        'net.surfshark.vpnclient.android',
        'com.privateinternetaccess.android',
        'com.cyberghostvpn.android',
        'com.hotspotshield.vpn.android',
        'com.tunnelbear.android',
        'com.protonvpn.android',
        'com.windscribe.vpn',
        'com.ipvanish.vpn',
        
        // Free/Open source VPNs
        'de.blinkt.openvpn',
        'net.openvpn.openvpn',
        'com.wireguard.android',
        'org.strongswan.android',
        
        // Built-in VPN clients
        'com.android.vpndialogs',
        'com.android.vpnservices',
        
        // Suspicious/Free VPNs
        'free.vpn.unblock.proxy.turbovpn',
        'com.touchvpn.android',
        'hotspotshield.android.vpn',
        'com.supervpn.client.android',
        'com.psiphon3.subscription',
      ];

      // Check through platform channel
      try {
        final result = await _platform.invokeMethod('checkVpnPackages', {'packages': vpnPackages});
        if (result != null && result is List) {
          final installedPackages = result.cast<String>();
          vpnApps.addAll(installedPackages);
        }
      } catch (e) {
        debugPrint('Platform method checkVpnPackages not implemented: $e');
      }

      // If platform method not available, we can't easily check installed packages
      // This would require native implementation or using installed_apps package
      
    } catch (e) {
      debugPrint('Error checking VPN apps: $e');
    }
    
    return vpnApps;
  }

  /// Method 3: Check for active VPN service
  static Future<bool> _checkActiveVpnService() async {
    try {
      if (Platform.isAndroid) {
        // Android VpnService detection
        try {
          final result = await _platform.invokeMethod('isVpnActive');
          return result == true;
        } catch (e) {
          debugPrint('Android VPN service check not implemented: $e');
        }
      } else if (Platform.isIOS) {
        // iOS Network Extension detection
        try {
          final result = await _platform.invokeMethod('isVpnActive');
          return result == true;
        } catch (e) {
          debugPrint('iOS VPN service check not implemented: $e');
        }
      }
    } catch (e) {
      debugPrint('Error checking active VPN service: $e');
    }
    
    return false;
  }

  /// Method 4: Check DNS configuration for VPN indicators
  static Future<bool> _checkDnsConfiguration() async {
    try {
      // Get DNS servers through platform channel
      try {
        final result = await _platform.invokeMethod('getDnsServers');
        if (result != null && result is List) {
          final dnsServers = result.cast<String>();
          
          // Common VPN DNS servers
          final vpnDnsServers = [
            '1.1.1.1', '1.0.0.1', // Cloudflare
            '8.8.8.8', '8.8.4.4', // Google (sometimes used by VPNs)
            '9.9.9.9', '149.112.112.112', // Quad9
            '208.67.222.222', '208.67.220.220', // OpenDNS
          ];
          
          // Check if DNS servers match known VPN providers
          for (final dns in dnsServers) {
            if (vpnDnsServers.contains(dns)) {
              debugPrint('VPN DNS server detected: $dns');
              return true;
            }
          }
        }
      } catch (e) {
        debugPrint('Platform method getDnsServers not implemented: $e');
      }
    } catch (e) {
      debugPrint('Error checking DNS configuration: $e');
    }
    
    return false;
  }

  /// Method 5: Check network routes for VPN-specific routes
  static Future<bool> _checkNetworkRoutes() async {
    try {
      // Get routing table through platform channel
      try {
        final result = await _platform.invokeMethod('getNetworkRoutes');
        if (result != null && result is List) {
          final routes = result.cast<String>();
          
          // Look for VPN-specific route patterns
          final vpnRoutePatterns = ['tun', 'ppp', 'vpn', '0.0.0.0/1', '128.0.0.0/1'];
          
          for (final route in routes) {
            for (final pattern in vpnRoutePatterns) {
              if (route.toLowerCase().contains(pattern)) {
                debugPrint('VPN route pattern found: $pattern in $route');
                return true;
              }
            }
          }
        }
      } catch (e) {
        debugPrint('Platform method getNetworkRoutes not implemented: $e');
      }
    } catch (e) {
      debugPrint('Error checking network routes: $e');
    }
    
    return false;
  }

  /// Get a simple boolean result for VPN detection
  static Future<bool> isVpnActive() async {
    final result = await detectVpn();
    return result.isVpnDetected;
  }

  /// Get VPN detection confidence level
  static Future<VpnConfidenceLevel> getVpnConfidenceLevel() async {
    final result = await detectVpn();
    
    if (!result.isVpnDetected) {
      return VpnConfidenceLevel.none;
    }
    
    final detectedMethods = result.detectionMethods.values.where((detected) => detected).length;
    final hasHighConfidenceThreat = result.vpnThreats.any(
      (threat) => threat.level == SecurityThreatLevel.high || threat.level == SecurityThreatLevel.critical
    );
    
    if (hasHighConfidenceThreat || detectedMethods >= 3) {
      return VpnConfidenceLevel.high;
    } else if (detectedMethods >= 2) {
      return VpnConfidenceLevel.medium;
    } else {
      return VpnConfidenceLevel.low;
    }
  }
}

/// Result class for VPN detection
class VpnDetectionResult {
  final bool isVpnDetected;
  final Map<String, bool> detectionMethods;
  final List<String> installedVpnApps;
  final List<SecurityThreat> vpnThreats;
  final DateTime lastChecked;
  final String? error;

  VpnDetectionResult({
    required this.isVpnDetected,
    required this.detectionMethods,
    required this.installedVpnApps,
    required this.vpnThreats,
    required this.lastChecked,
    this.error,
  });
}
