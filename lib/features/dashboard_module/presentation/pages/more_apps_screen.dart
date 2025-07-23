import 'package:flutter/material.dart';

class MoreAppsScreen extends StatelessWidget {
  const MoreAppsScreen({super.key});

  static const routeName = '/more-apps';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('More Apps'),
      ),
      body: const Center(
        child: Text('Apps list will be shown here'),
      ),
    );
  }
}
