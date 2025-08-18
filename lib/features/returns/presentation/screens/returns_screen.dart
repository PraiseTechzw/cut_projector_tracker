import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';

/// Screen for returning projectors
class ReturnsScreen extends StatelessWidget {
  const ReturnsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.undo, size: 80, color: AppTheme.accentColor),
            const SizedBox(height: 24),
            Text(
              'Return Projector',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Scan a projector barcode to return it',
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: AppTheme.textSecondary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () {
                // TODO: Implement return logic
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
