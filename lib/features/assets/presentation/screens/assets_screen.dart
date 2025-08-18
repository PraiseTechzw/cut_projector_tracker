import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

/// Screen for viewing asset register
class AssetsScreen extends StatelessWidget {
  const AssetsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory, size: 80, color: AppTheme.secondaryColor),
            const SizedBox(height: 24),
            Text(
              'Asset Register',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'View all projectors and their current status',
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: AppTheme.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () {
                // TODO: Implement assets view
              },
              icon: const Icon(Icons.list),
              label: const Text('View Assets'),
            ),
          ],
        ),
      ),
    );
  }
}
