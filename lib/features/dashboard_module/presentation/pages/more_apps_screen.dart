import 'package:flutter/material.dart';
import 'package:installed_apps/app_info.dart';
import 'package:installed_apps/installed_apps.dart';
import 'package:nidhi_rakshak/src/theme/gradient_theme.dart';
import 'package:nidhi_rakshak/features/background_module/services/security/permission_analyzer.dart';

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
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      
      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load apps: $e')),
        );
      }
    }
  }

  // Filter apps based on search query
  List<AppInfo> get _filteredApps {
    if (_searchQuery.isEmpty) {
      return _apps;
    }
    
    return _apps.where((app) => 
      app.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
      app.packageName.toLowerCase().contains(_searchQuery.toLowerCase())
    ).toList();
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
                    isSystem ? 'System App' : 'User Installed App'
                  );
                }
              ),
              // App permissions section
              const SizedBox(height: 16),
              const Text(
                'App Permissions',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
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
            child: Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              InstalledApps.openSettings(app.packageName);
            },
            child: Text('Open Settings'),
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
    Future.delayed(Duration(milliseconds: 300), () {
      PermissionAnalyzer.getAppPermissions(app.packageName).then((permissions) {
        if (!mounted) return;
        
        final dangerousCount = permissions
            .where((p) => PermissionAnalyzer.dangerousPermissions.contains(p))
            .length;
            
        // Check for dangerous combinations
        final dangerousCombo = PermissionAnalyzer
            .checkDangerousPermissionCombinations(permissions);
            
        if (dangerousCombo.isNotEmpty || dangerousCount >= 3) {
          showModalBottomSheet(
            context: context,
            builder: (context) => Container(
              color: Colors.red.shade50,
              padding: EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
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
                  SizedBox(height: 8),
                  if (dangerousCombo.isNotEmpty)
                    Text('This app uses a suspicious combination of permissions: $dangerousCombo'),
                  if (dangerousCount >= 3)
                    Text('This app uses $dangerousCount dangerous permissions which may pose a security risk.'),
                  SizedBox(height: 12),
                  Center(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text('DISMISS'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.red,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }
      });
    });
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
          SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
            ),
          ),
          Divider(),
        ],
      ),
    );
  }
  
  Widget _buildPermissionsList(List<String> permissions) {
    // Sort permissions alphabetically
    final sortedPermissions = [...permissions]
      ..sort((a, b) => a.compareTo(b));
      
    // Format permission names for better readability
    final formattedPermissions = sortedPermissions.map(_formatPermission).toList();
    
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
          _permissionCategory('Dangerous Permissions', 
            categorizedPermissions['Dangerous']!, Colors.red),
        ],
        if (categorizedPermissions['Normal']!.isNotEmpty) ...[
          _permissionCategory('Normal Permissions', 
            categorizedPermissions['Normal']!, Colors.green),
        ],
        if (categorizedPermissions['Special']!.isNotEmpty) ...[
          _permissionCategory('Special Permissions', 
            categorizedPermissions['Special']!, Colors.orange),
        ],
        if (categorizedPermissions['Others']!.isNotEmpty) ...[
          _permissionCategory('Other Permissions', 
            categorizedPermissions['Others']!, Colors.blue),
        ],
      ],
    );
  }
  
  Widget _permissionCategory(String title, List<String> permissions, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: 16),
        Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
        SizedBox(height: 8),
        ...permissions.map((permission) => Padding(
          padding: const EdgeInsets.only(left: 20.0, bottom: 4.0),
          child: Text('• $permission'),
        )),
      ],
    );
  }
  
  String _formatPermission(String permission) {
    // Remove the "android.permission." prefix
    String formatted = permission.replaceAll('android.permission.', '');
    
    // Replace underscores with spaces
    formatted = formatted.replaceAll('_', ' ');
    
    // Make it title case (first letter of each word capitalized)
    formatted = formatted.split(' ').map((word) => 
      word.isNotEmpty ? '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}' : ''
    ).join(' ');
    
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
              icon: Icon(_showSystemApps ? Icons.visibility : Icons.visibility_off),
              tooltip: _showSystemApps ? 'Hide System Apps' : 'Show System Apps',
              onPressed: () {
                setState(() {
                  _showSystemApps = !_showSystemApps;
                });
                _loadApps();
              },
            ),
            // Refresh button
            IconButton(
              icon: Icon(Icons.refresh),
              onPressed: _loadApps,
            ),
          ],
        ),
        body: Column(
          children: [
            // Search bar
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Search apps...',
                  prefixIcon: Icon(Icons.search),
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
            
            // App count
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Found ${_filteredApps.length} apps',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  // Display loading indicator when refreshing
                  if (_isLoading) 
                    SizedBox(
                      height: 20, 
                      width: 20, 
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                ],
              ),
            ),
            
            // App list
            Expanded(
              child: _isLoading 
                ? Center(child: CircularProgressIndicator())
                : _filteredApps.isEmpty 
                  ? Center(child: Text('No apps found'))
                  : ListView.builder(
                      padding: EdgeInsets.all(8),
                      itemCount: _filteredApps.length,
                      itemBuilder: (context, index) {
                        final app = _filteredApps[index];
                        return FutureBuilder<List<String>>(
                          future: PermissionAnalyzer.getAppPermissions(app.packageName),
                          builder: (context, snapshot) {
                            bool hasDangerousPermissions = false;
                            
                            if (snapshot.hasData && snapshot.data!.isNotEmpty) {
                              final permissions = snapshot.data!;
                              final dangerousCount = permissions
                                  .where((p) => PermissionAnalyzer.dangerousPermissions.contains(p))
                                  .length;
                              final dangerousCombo = PermissionAnalyzer
                                  .checkDangerousPermissionCombinations(permissions);
                              
                              hasDangerousPermissions = dangerousCombo.isNotEmpty || dangerousCount >= 3;
                            }
                            
                            return Card(
                              elevation: 2,
                              margin: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                              shape: hasDangerousPermissions 
                                ? RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                    side: BorderSide(color: Colors.red, width: 1.5),
                                  )
                                : null,
                              child: ListTile(
                                leading: app.icon != null 
                                  ? Image.memory(app.icon!, width: 40, height: 40)
                                  : Icon(Icons.android, size: 40),
                                title: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        app.name,
                                        style: TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                    if (hasDangerousPermissions)
                                      Icon(Icons.warning_amber_rounded, 
                                          color: Colors.orange, size: 18),
                                  ],
                                ),
                                subtitle: Text(
                                  app.packageName,
                                  style: TextStyle(fontSize: 12),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: Icon(Icons.info_outline),
                                      onPressed: () => _showAppDetails(app),
                                      tooltip: 'App Details & Permissions',
                                    ),
                                    IconButton(
                                      icon: Icon(Icons.settings),
                                      onPressed: () => InstalledApps.openSettings(app.packageName),
                                      tooltip: 'App Settings',
                                    ),
                                  ],
                                ),
                                onTap: () => InstalledApps.startApp(app.packageName),
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
