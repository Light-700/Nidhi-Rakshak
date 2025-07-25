/// Model class representing the security status of the device.
class SecurityStatus {
  /// Whether the device is secure overall
  final bool isDeviceSecure;
  
  /// Whether the device is jailbroken (iOS)
  final bool isJailbroken;
  
  /// Whether the device is rooted (Android)
  final bool isRooted;
  
  /// When the security scan was performed
  final DateTime lastChecked;
  
  /// List of detected security threats
  final List<SecurityThreat> detectedThreats;

  SecurityStatus({
    required this.isDeviceSecure,
    required this.isJailbroken,
    required this.isRooted,
    required this.lastChecked,
    required this.detectedThreats,
  });

  /// Factory constructor for a secure device state
  factory SecurityStatus.secure() {
    return SecurityStatus(
      isDeviceSecure: true,
      isJailbroken: false,
      isRooted: false,
      lastChecked: DateTime.now(),
      detectedThreats: [],
    );
  }
}

/// Model representing a specific security threat or vulnerability
class SecurityThreat {
  /// Name of the threat
  final String name;
  
  /// Detailed description of the threat
  final String description;
  
  /// Severity level of the threat
  final SecurityThreatLevel level;
  
  /// Additional metadata about the threat
  final Map<String, dynamic>? metadata;

  SecurityThreat({
    required this.name,
    required this.description,
    required this.level,
    this.metadata,
  });
}

/// Enum categorizing threats by severity level
enum SecurityThreatLevel { low, medium, high, critical }
