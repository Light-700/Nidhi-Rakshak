import 'package:flutter/material.dart';
import 'package:installed_apps/app_info.dart';
import 'package:installed_apps/installed_apps.dart';
import 'package:nidhi_rakshak/src/theme/gradient_theme.dart';
import 'package:nidhi_rakshak/features/background_module/services/security/permission_analyzer.dart';
import 'package:nidhi_rakshak/features/background_module/services/security/app_security_scanner.dart';

class MoreAppsScreen extends StatefulWidget {
  const MoreAppsScreen({super.key});

  static const routeName = '/more-apps';

  @override
  State<MoreAppsScreen> createState() => _MoreAppsScreenState();
}

class _MoreAppsScreenState extends State<MoreAppsScreen> {
  bool _isLoading = true;
  List<AppInfo> _apps = [];
  String _searchQuery = '';
  bool _showSystemApps = false;
  
  // Risk filter options
  String _selectedRiskFilter = 'All'; // Default filter
  final List<String> _riskFilterOptions = [
    'All', 
    'Critical', 
    'High', 
    'Medium', 
    'Low', 
    'Safe'
  ];

  @override
  void initState() {
    super.initState();
    _loadApps();
  }

  Future<void> _loadApps() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Get all installed apps
      final apps = await InstalledApps.getInstalledApps(
        !_showSystemApps,
        true,
        "",
      );

      // Sort alphabetically by name
      apps.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

      setState(() {
        _apps = apps;
        _isLoading = false;
      });
      
      // Preload risk levels for all apps in the background
      _preloadAppRiskLevels(apps);
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load apps: $e')));
      }
    }
  }
  
  // Preload risk levels for all apps to make filtering more responsive
  Future<void> _preloadAppRiskLevels(List<AppInfo> apps) async {
    // Process apps in batches to avoid overloading the device
    const int batchSize = 10;
    
    for (int i = 0; i < apps.length; i += batchSize) {
      final end = (i + batchSize < apps.length) ? i + batchSize : apps.length;
      final batch = apps.sublist(i, end);
      
      // Process each app in the batch
      await Future.wait(
        batch.map((app) => AppSecurityScanner.calculateAppRiskScore(app.packageName)),
      );
      
      // Allow the UI to update by yielding to the event loop
      await Future.delayed(const Duration(milliseconds: 10));
    }
    
    if (mounted) {
      // Refresh the UI after preloading is complete
      setState(() {});
    }
  }

  // Filter apps based on search query and risk level
  List<AppInfo> get _filteredApps {
    // Start with search query filter
    List<AppInfo> filtered = _searchQuery.isEmpty
        ? _apps
        : _apps.where(
            (app) =>
                app.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                app.packageName.toLowerCase().contains(
                  _searchQuery.toLowerCase(),
                ),
          ).toList();
    
    // If "All" is selected, return all apps that match the search
    if (_selectedRiskFilter == 'All') {
      return filtered;
    }
    
    // Show loading indicator if no apps have risk info yet
    if (!_apps.any((app) => AppSecurityScanner.getCachedRiskInfo(app.packageName) != null)) {
      // Pre-calculate risk levels for all apps to make filtering work
      for (final app in _apps) {
        AppSecurityScanner.calculateAppRiskScore(app.packageName);
      }
    }
    
    // Filter by risk level
    return filtered.where((app) {
      // Get risk info - this should now be cached from previous calculations
      final riskInfo = AppSecurityScanner.getCachedRiskInfo(app.packageName);
      if (riskInfo == null) return false; // Skip if no risk info yet
      
      final riskLevel = AppSecurityScanner.parseRiskLevel(riskInfo['riskLevel'] as String);
      
      // Match based on the selected filter name (not the full risk level name)
      switch (_selectedRiskFilter) {
        case 'Critical':
          return riskLevel == AppRiskLevel.critical;
        case 'High':
          return riskLevel == AppRiskLevel.high;
        case 'Medium':
          return riskLevel == AppRiskLevel.medium;
        case 'Low':
          return riskLevel == AppRiskLevel.low;
        case 'Safe':
          return riskLevel == AppRiskLevel.safe;
        default:
          return true;
      }
    }).toList();
  }

  // Show app details dialog
  void _showAppDetails(AppInfo app) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(app.name),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (app.icon != null)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: Image.memory(app.icon!, height: 64),
                  ),
                ),
              _detailRow('Package Name', app.packageName),
              _detailRow('Version', '${app.versionName} (${app.versionCode})'),
              _detailRow('Built With', app.builtWith.toString()),
              FutureBuilder<bool?>(
                future: InstalledApps.isSystemApp(app.packageName),
                builder: (context, snapshot) {
                  final isSystem = snapshot.data ?? false;
                  return _detailRow(
                    'App Type',
                    isSystem ? 'System App' : 'User Installed App',
                  );
                },
              ),
              // App permissions section
              const SizedBox(height: 16),
              const Text(
                'App Permissions',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 8),
              FutureBuilder<List<String>>(
                future: PermissionAnalyzer.getAppPermissions(app.packageName),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 20.0),
                        child: CircularProgressIndicator(),
                      ),
                    );
                  } else if (snapshot.hasError) {
                    return Text('Error loading permissions: ${snapshot.error}');
                  } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Text('No permissions found for this app');
                  }

                  return _buildPermissionsList(snapshot.data!);
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              InstalledApps.openSettings(app.packageName);
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );

    // Show risk assessment bottom sheet for apps with dangerous permissions
    _showRiskAssessment(app);
  }

  // Show risk assessment as a separate bottom sheet
  void _showRiskAssessment(AppInfo app) {
    // Wait a bit for the dialog to show up first
    Future.delayed(const Duration(milliseconds: 300), () async {
      try {
        // Get enhanced risk assessment using the new scanner
        final riskInfo = await AppSecurityScanner.calculateAppRiskScore(app.packageName);
        
        if (!mounted) return;
        
        // Parse the risk level
        final AppRiskLevel riskLevel = AppSecurityScanner.parseRiskLevel(riskInfo['riskLevel'] as String);
        
        // Only show warning for medium risk or higher
        if (riskLevel == AppRiskLevel.safe || riskLevel == AppRiskLevel.low) {
          return;
        }

        // Get color based on risk level
        final riskColor = Color(AppSecurityScanner.getRiskLevelColor(riskLevel));
        final bgColor = riskColor.withOpacity(0.1);
        
        // Get the risk score and risk factors from the map
        final int riskScore = riskInfo['riskScore'] as int;
        final List<dynamic> riskFactorsDynamic = riskInfo['riskFactors'] as List<dynamic>;
        final List<String> riskFactors = riskFactorsDynamic.map((factor) => factor.toString()).toList();
        
        // Show the risk assessment bottom sheet
        showModalBottomSheet(
          context: context,
          builder: (context) => Container(
            color: bgColor,
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.warning_amber, color: riskColor),
                    const SizedBox(width: 8),
                    Text(
                      'Security Risk Assessment: ${_getRiskLevelName(riskLevel)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: riskColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'Risk Score: $riskScore/100',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: riskColor,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Risk Factors:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                ...riskFactors.map(
                  (factor) => Padding(
                    padding: const EdgeInsets.only(bottom: 4.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('• '),
                        Expanded(child: Text(factor)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('DISMISS'),
                    style: TextButton.styleFrom(foregroundColor: riskColor),
                  ),
                ),
              ],
            ),
          ),
        );
      } catch (e) {
        print('Error showing risk assessment: $e');
        // Fallback to the old method if the new one fails
        _showLegacyRiskAssessment(app);
      }
    });
  }
  
  // Legacy method as fallback
  void _showLegacyRiskAssessment(AppInfo app) {
    PermissionAnalyzer.getAppPermissions(app.packageName).then((permissions) {
      if (!mounted) return;

      final dangerousCount = permissions
          .where((p) => PermissionAnalyzer.dangerousPermissions.contains(p))
          .length;

      // Check for dangerous combinations
      final dangerousCombo =
          PermissionAnalyzer.checkDangerousPermissionCombinations(
            permissions,
          );

      if (dangerousCombo.isNotEmpty || dangerousCount >= 3) {
        showModalBottomSheet(
          context: context,
          builder: (context) => Container(
            color: Colors.red.shade50,
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.warning_amber, color: Colors.red),
                    SizedBox(width: 8),
                    Text(
                      'Security Risk Assessment',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.red,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (dangerousCombo.isNotEmpty)
                  Text(
                    'This app uses a suspicious combination of permissions: $dangerousCombo',
                  ),
                if (dangerousCount >= 3)
                  Text(
                    'This app uses $dangerousCount dangerous permissions which may pose a security risk.',
                  ),
                const SizedBox(height: 12),
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('DISMISS'),
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    });
  }
  
  // Helper to convert risk level enum to user-friendly string
  String _getRiskLevelName(AppRiskLevel level) {
    switch (level) {
      case AppRiskLevel.safe:
        return 'Safe';
      case AppRiskLevel.low:
        return 'Low Risk';
      case AppRiskLevel.medium:
        return 'Medium Risk';
      case AppRiskLevel.high:
        return 'High Risk';
      case AppRiskLevel.critical:
        return 'Critical Risk';
      case AppRiskLevel.unknown:
        return 'Unknown Risk';
    }
  }
  
  // Get color based on risk level string
  Color _getRiskColor(String riskLevel) {
    switch (riskLevel) {
      case 'Critical':
        return Colors.red;
      case 'High':
        return Colors.deepOrange;
      case 'Medium':
        return Colors.orange;
      case 'Low':
        return Colors.blue;
      case 'Safe':
        return Colors.green;
      default:
        return Theme.of(context).colorScheme.primary;
    }
  }
  
  // Count apps by risk level
  int _getRiskLevelCount(String riskLevel) {
    return _apps.where((app) {
      final riskInfo = AppSecurityScanner.getCachedRiskInfo(app.packageName);
      if (riskInfo == null) return false;
      
      final appRiskLevel = AppSecurityScanner.parseRiskLevel(riskInfo['riskLevel'] as String);
      
      switch (riskLevel) {
        case 'Critical':
          return appRiskLevel == AppRiskLevel.critical;
        case 'High':
          return appRiskLevel == AppRiskLevel.high;
        case 'Medium':
          return appRiskLevel == AppRiskLevel.medium;
        case 'Low':
          return appRiskLevel == AppRiskLevel.low;
        case 'Safe':
          return appRiskLevel == AppRiskLevel.safe;
        default:
          return false;
      }
    }).length;
  }

  // End of risk assessment

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 16)),
          const Divider(),
        ],
      ),
    );
  }

  Widget _buildPermissionsList(List<String> permissions) {
    // Sort permissions alphabetically
    final sortedPermissions = [...permissions]..sort((a, b) => a.compareTo(b));

    // Format permission names for better readability
    final formattedPermissions = sortedPermissions
        .map(_formatPermission)
        .toList();

    // Categorize permissions
    final Map<String, List<String>> categorizedPermissions = {
      'Dangerous': [],
      'Normal': [],
      'Special': [],
      'Others': [],
    };

    // Categorize each permission
    for (int i = 0; i < sortedPermissions.length; i++) {
      final rawPermission = sortedPermissions[i];
      final formattedPermission = formattedPermissions[i];

      if (PermissionAnalyzer.dangerousPermissions.contains(rawPermission)) {
        categorizedPermissions['Dangerous']!.add(formattedPermission);
      } else if (rawPermission.contains('INTERNET') ||
          rawPermission.contains('ACCESS_NETWORK_STATE')) {
        categorizedPermissions['Normal']!.add(formattedPermission);
      } else if (rawPermission.contains('BIND_') ||
          rawPermission.contains('MANAGE_')) {
        categorizedPermissions['Special']!.add(formattedPermission);
      } else {
        categorizedPermissions['Others']!.add(formattedPermission);
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (categorizedPermissions['Dangerous']!.isNotEmpty) ...[
          _permissionCategory(
            'Dangerous Permissions',
            categorizedPermissions['Dangerous']!,
            Colors.red,
          ),
        ],
        if (categorizedPermissions['Normal']!.isNotEmpty) ...[
          _permissionCategory(
            'Normal Permissions',
            categorizedPermissions['Normal']!,
            Colors.green,
          ),
        ],
        if (categorizedPermissions['Special']!.isNotEmpty) ...[
          _permissionCategory(
            'Special Permissions',
            categorizedPermissions['Special']!,
            Colors.orange,
          ),
        ],
        if (categorizedPermissions['Others']!.isNotEmpty) ...[
          _permissionCategory(
            'Other Permissions',
            categorizedPermissions['Others']!,
            Colors.blue,
          ),
        ],
      ],
    );
  }

  Widget _permissionCategory(
    String title,
    List<String> permissions,
    Color color,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ...permissions.map(
          (permission) => Padding(
            padding: const EdgeInsets.only(left: 20.0, bottom: 4.0),
            child: Text('• $permission'),
          ),
        ),
      ],
    );
  }

  String _formatPermission(String permission) {
    // Remove the "android.permission." prefix
    String formatted = permission.replaceAll('android.permission.', '');

    // Replace underscores with spaces
    formatted = formatted.replaceAll('_', ' ');

    // Make it title case (first letter of each word capitalized)
    formatted = formatted
        .split(' ')
        .map(
          (word) => word.isNotEmpty
              ? '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}'
              : '',
        )
        .join(' ');

    return formatted;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: AppGradients.getBackgroundGradient(context),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          title: const Text('Installed Apps'),
          backgroundColor: Colors.transparent,
          elevation: 0,
          actions: [
            // Toggle system apps
            IconButton(
              icon: Icon(
                _showSystemApps ? Icons.visibility : Icons.visibility_off,
              ),
              tooltip: _showSystemApps
                  ? 'Hide System Apps'
                  : 'Show System Apps',
              onPressed: () {
                setState(() {
                  _showSystemApps = !_showSystemApps;
                });
                _loadApps();
              },
            ),
            // Refresh button
            IconButton(icon: const Icon(Icons.refresh), onPressed: _loadApps),
          ],
        ),
        body: Column(
          children: [
            // Search bar
            Padding(
              padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 16.0, bottom: 8.0),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search apps...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  filled: true,
                  fillColor: Theme.of(context).cardColor.withOpacity(0.9),
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
              ),
            ),
            
            // Risk filter chips
            Padding(
              padding: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 8.0),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _riskFilterOptions.map((filter) {
                    final isSelected = _selectedRiskFilter == filter;
                    Color chipColor;
                    
                    switch (filter) {
                      case 'Critical':
                        chipColor = Colors.red;
                        break;
                      case 'High':
                        chipColor = Colors.deepOrange;
                        break;
                      case 'Medium':
                        chipColor = Colors.orange;
                        break;
                      case 'Low':
                        chipColor = Colors.blue;
                        break;
                      case 'Safe':
                        chipColor = Colors.green;
                        break;
                      default:
                        chipColor = Colors.grey;
                    }
                    
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: FilterChip(
                        selected: isSelected,
                        label: Text(filter),
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : chipColor,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        ),
                        backgroundColor: chipColor.withOpacity(0.1),
                        selectedColor: chipColor,
                        checkmarkColor: Colors.white,
                        onSelected: (selected) {
                          setState(() {
                            _selectedRiskFilter = filter;
                          });
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),

              // App count with filter indicator and risk stats
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        RichText(
                          text: TextSpan(
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.bold,
                            ),
                            children: [
                              TextSpan(text: 'Found ${_filteredApps.length} apps'),
                              if (_selectedRiskFilter != 'All')
                                TextSpan(
                                  text: ' (${_selectedRiskFilter} filter)',
                                  style: TextStyle(
                                    fontStyle: FontStyle.italic,
                                    fontSize: 12,
                                    color: _getRiskColor(_selectedRiskFilter),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        // Display loading indicator when refreshing
                        if (_isLoading)
                          const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                      ],
                    ),
                    
                    // Show risk level statistics when viewing all apps
                    if (_selectedRiskFilter == 'All' && _apps.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              ..._riskFilterOptions.where((filter) => filter != 'All').map((filter) {
                                final count = _getRiskLevelCount(filter);
                                if (count == 0) return const SizedBox.shrink();
                                
                                return Padding(
                                  padding: const EdgeInsets.only(right: 8.0),
                                  child: Chip(
                                    backgroundColor: _getRiskColor(filter).withOpacity(0.1),
                                    side: BorderSide(color: _getRiskColor(filter)),
                                    labelStyle: TextStyle(
                                      color: _getRiskColor(filter),
                                      fontSize: 12,
                                    ),
                                    label: Text('$count $filter'),
                                  ),
                                );
                              }).toList(),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),            // App list
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredApps.isEmpty
                  ? const Center(child: Text('No apps found'))
                  : ListView.builder(
                      padding: const EdgeInsets.all(8),
                      itemCount: _filteredApps.length,
                      itemBuilder: (context, index) {
                        final app = _filteredApps[index];
                        
                        return FutureBuilder<Map<String, dynamic>>(
                          future: AppSecurityScanner.calculateAppRiskScore(app.packageName),
                          builder: (context, snapshot) {
                            // Show loading indicator while waiting
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return Card(
                                elevation: 1,
                                margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                                child: ListTile(
                                  leading: app.icon != null
                                      ? Image.memory(app.icon!, width: 40, height: 40)
                                      : const Icon(Icons.android, size: 40),
                                  title: Text(app.name),
                                  subtitle: Text(app.packageName, style: const TextStyle(fontSize: 12)),
                                  trailing: const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  ),
                                ),
                              );
                            }
                            
                            // Determine if app is suspicious
                            bool hasDangerousPermissions = false;
                            Color? borderColor;
                            String? riskLevelName;
                            
                            if (snapshot.hasData) {
                              final riskInfo = snapshot.data!;
                              final AppRiskLevel riskLevel = AppSecurityScanner.parseRiskLevel(riskInfo['riskLevel'] as String);
                              
                              // Only show warning for medium risk or higher
                              hasDangerousPermissions = 
                                  riskLevel == AppRiskLevel.medium ||
                                  riskLevel == AppRiskLevel.high ||
                                  riskLevel == AppRiskLevel.critical;
                              
                              if (hasDangerousPermissions) {
                                borderColor = Color(AppSecurityScanner.getRiskLevelColor(riskLevel));
                                riskLevelName = AppSecurityScanner.riskLevelToString(riskLevel);
                              }
                            } else if (snapshot.hasError) {
                              // Fall back to the old permission-based check if new method fails
                              hasDangerousPermissions = false;
                              // We could implement fallback here but let's keep it simple
                            }

                            return Card(
                              elevation: 2,
                              margin: const EdgeInsets.symmetric(
                                vertical: 4,
                                horizontal: 8,
                              ),
                              shape: hasDangerousPermissions
                                  ? RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      side: BorderSide(
                                        color: borderColor ?? Colors.red,
                                        width: 1.5,
                                      ),
                                    )
                                  : null,
                              child: ListTile(
                                leading: app.icon != null
                                    ? Image.memory(
                                        app.icon!,
                                        width: 40,
                                        height: 40,
                                      )
                                    : const Icon(Icons.android, size: 40),
                                title: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        app.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    if (hasDangerousPermissions)
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.warning_amber_rounded,
                                            color: borderColor ?? Colors.orange,
                                            size: 16,
                                          ),
                                          if (riskLevelName != null)
                                            Padding(
                                              padding: const EdgeInsets.only(left: 4.0),
                                              child: Text(
                                                riskLevelName,
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: borderColor,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                  ],
                                ),
                                subtitle: Text(
                                  app.packageName,
                                  style: const TextStyle(fontSize: 12),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.info_outline),
                                      onPressed: () => _showAppDetails(app),
                                      tooltip: 'App Details & Permissions',
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.settings),
                                      onPressed: () =>
                                          InstalledApps.openSettings(
                                            app.packageName,
                                          ),
                                      tooltip: 'App Settings',
                                    ),
                                  ],
                                ),
                                // onTap: () =>
                                //     InstalledApps.startApp(app.packageName),
                              ),
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
