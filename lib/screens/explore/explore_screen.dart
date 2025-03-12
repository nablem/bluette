import 'package:flutter/material.dart';
import '../../constants/app_theme.dart';

class ExploreScreen extends StatelessWidget {
  const ExploreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Explore'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.swipe, size: 100, color: Colors.grey),
            const SizedBox(height: 20),
            Text('Swipe Feature Coming Soon', style: AppTheme.headingStyle),
            const SizedBox(height: 10),
            Text(
              'This is where users will be able to swipe through profiles',
              style: AppTheme.bodyStyle,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
