import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

/// Screen for issuing projectors to lecturers
class IssuanceScreen extends StatelessWidget {
  const IssuanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.add_circle_outline,
              size: 80,
              color: AppTheme.primaryColor,
            ),
            const SizedBox(height: 24),
            Text(
              'Issue Projector',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Scan a projector barcode to issue it to a lecturer',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: AppTheme.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () {
                // TODO: Implement issuance logic
              },
              icon: const Icon(Icons.qr_code_scanner),
              label: const Text('Scan Projector'),
            ),
          ],
        ),
      ),
    );
  }
}
