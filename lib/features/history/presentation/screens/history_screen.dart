import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

/// Screen for viewing transaction history
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 80, color: AppTheme.warningColor),
            const SizedBox(height: 24),
            Text(
              'Transaction History',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'View all projector issuance and return history',
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: AppTheme.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () {
                // TODO: Implement history view
              },
              icon: const Icon(Icons.timeline),
              label: const Text('View History'),
            ),
          ],
        ),
      ),
    );
  }
}
