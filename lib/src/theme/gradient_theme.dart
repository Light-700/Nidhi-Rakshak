import 'package:flutter/material.dart';

class AppGradients {
  // Light mode gradients
  static const LinearGradient lightBackground = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color.fromARGB(255, 237, 122, 84), 
      Colors.white, 
      Color.fromARGB(255, 93, 221, 93), 
      /* Color.fromARGB(255, 255, 64, 0), 
      Colors.white, 
      Color.fromARGB(255, 3, 146, 3), */ //original gradient colors
    ],
    stops: [0.0, 0.5, 1.0],
  );
  
  static const LinearGradient lightCard = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Colors.white,
      Color(0xFFF5F5F5),
    ],
  );
  
  // Dark mode gradients
  static const LinearGradient darkBackground = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color.fromARGB(255, 155, 48, 12),
      Color.fromARGB(255, 0, 0, 0), 
      Color.fromARGB(255, 5, 99, 5), 
    ],
    stops: [0.0, 0.5, 1.0],
  );
  
  static const LinearGradient darkCard = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF2C2C2C),
      Color(0xFF3A3A3A),
    ],
  );
  
  // Security status gradients (theme-aware)
 /* static LinearGradient getSecureGradient(bool isDark) {
    return LinearGradient(
      colors: isDark 
        ? [Color(0xFF2E7D32), Color(0xFF1B5E20)]
        : [Color(0xFF4CAF50), Color(0xFF66BB6A)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }
  
  static LinearGradient getWarningGradient(bool isDark) {
    return LinearGradient(
      colors: isDark 
        ? [Color(0xFFE65100), Color(0xFFBF360C)]
        : [Color(0xFFFF9800), Color(0xFFFFB74D)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }
  
  static LinearGradient getCriticalGradient(bool isDark) {
    return LinearGradient(
      colors: isDark 
        ? [Color(0xFFB71C1C), Color(0xFF8E0000)]
        : [Color(0xFFF44336), Color(0xFFE57373)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
  }*/ //maybe used later on
  
  // Helper method to get background gradient based on theme
  static LinearGradient getBackgroundGradient(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? darkBackground : lightBackground;
  }
  
  static LinearGradient getCardGradient(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? darkCard : lightCard;
  }
}
