import 'package:flutter/material.dart';
import 'package:installed_apps/app_info.dart';
import 'package:installed_apps/installed_apps.dart';
import 'package:nidhi_rakshak/src/theme/gradient_theme.dart';

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
  }

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
                        return Card(
                          elevation: 2,
                          margin: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                          child: ListTile(
                            leading: app.icon != null 
                              ? Image.memory(app.icon!, width: 40, height: 40)
                              : Icon(Icons.android, size: 40),
                            title: Text(
                              app.name,
                              style: TextStyle(fontWeight: FontWeight.bold),
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
                                ),
                                IconButton(
                                  icon: Icon(Icons.settings),
                                  onPressed: () => InstalledApps.openSettings(app.packageName),
                                ),
                              ],
                            ),
                            onTap: () => InstalledApps.startApp(app.packageName),
                          ),
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
