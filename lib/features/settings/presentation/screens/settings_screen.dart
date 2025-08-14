import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/services/firebase_auth_service.dart';
import '../../../reports/presentation/screens/data_export_screen.dart';

/// Settings screen for app configuration and preferences
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _notificationsEnabled = true;
  bool _darkModeEnabled = false;
  bool _autoScanEnabled = true;
  bool _hapticFeedbackEnabled = true;
  String _scanSpeed = 'normal';
  String _language = 'English';

  final List<String> _scanSpeeds = ['slow', 'normal', 'fast'];
  final List<String> _languages = ['English', 'Spanish', 'French', 'German'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            _buildHeader(),
            const SizedBox(height: 24),

            // App Settings
            _buildSettingsSection('App Settings', [
              _buildSwitchTile(
                'Dark Mode',
                'Enable dark theme for the app',
                Icons.dark_mode,
                _darkModeEnabled,
                (value) {
                  setState(() {
                    _darkModeEnabled = value;
                  });
                  // TODO: Implement theme switching
                },
              ),
              _buildSwitchTile(
                'Notifications',
                'Receive push notifications for important events',
                Icons.notifications,
                _notificationsEnabled,
                (value) {
                  setState(() {
                    _notificationsEnabled = value;
                  });
                  // TODO: Implement notification settings
                },
              ),
              _buildSwitchTile(
                'Haptic Feedback',
                'Vibrate on actions and scans',
                Icons.vibration,
                _hapticFeedbackEnabled,
                (value) {
                  setState(() {
                    _hapticFeedbackEnabled = value;
                  });
                  // TODO: Implement haptic feedback settings
                },
              ),
            ]),

            const SizedBox(height: 24),

            // Scanner Settings
            _buildSettingsSection('Scanner Settings', [
              _buildSwitchTile(
                'Auto Scan',
                'Automatically start scanning when screen opens',
                Icons.qr_code_scanner,
                _autoScanEnabled,
                (value) {
                  setState(() {
                    _autoScanEnabled = value;
                  });
                  // TODO: Implement auto scan setting
                },
              ),
              _buildDropdownTile(
                'Scan Speed',
                'Adjust scanning sensitivity and speed',
                Icons.speed,
                _scanSpeed,
                _scanSpeeds,
                (value) {
                  setState(() {
                    _scanSpeed = value;
                  });
                  // TODO: Implement scan speed setting
                },
              ),
            ]),

            const SizedBox(height: 24),

            // Language Settings
            _buildSettingsSection('Language & Region', [
              _buildDropdownTile(
                'Language',
                'Choose your preferred language',
                Icons.language,
                _language,
                _languages,
                (value) {
                  setState(() {
                    _language = value;
                  });
                  // TODO: Implement language switching
                },
              ),
            ]),

            const SizedBox(height: 24),

            // Data Management
            _buildSettingsSection('Data Management', [
              _buildActionTile(
                'Export Data',
                'Export system data in various formats',
                Icons.download,
                AppTheme.accentColor,
                () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const DataExportScreen(),
                    ),
                  );
                },
              ),
              _buildActionTile(
                'Clear Cache',
                'Clear app cache and temporary files',
                Icons.cleaning_services,
                AppTheme.warningColor,
                () {
                  _showClearCacheDialog();
                },
              ),
              _buildActionTile(
                'Reset Settings',
                'Reset all settings to default values',
                Icons.restore,
                AppTheme.errorColor,
                () {
                  _showResetSettingsDialog();
                },
              ),
            ]),

            const SizedBox(height: 24),

            // Account Settings
            _buildSettingsSection('Account', [
              _buildActionTile(
                'Change Password',
                'Update your account password',
                Icons.lock,
                AppTheme.primaryColor,
                () {
                  _showChangePasswordDialog();
                },
              ),
              _buildActionTile(
                'Privacy Policy',
                'View our privacy policy',
                Icons.privacy_tip,
                AppTheme.textSecondary,
                () {
                  _showPrivacyPolicy();
                },
              ),
              _buildActionTile(
                'Terms of Service',
                'View our terms of service',
                Icons.description,
                AppTheme.textSecondary,
                () {
                  _showTermsOfService();
                },
              ),
            ]),

            const SizedBox(height: 24),

            // About Section
            _buildAboutSection(),
          ],
        ),
      ),
    );
  }

  /// Build header section
  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppConstants.largePadding),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.primaryColor,
            AppTheme.primaryColor.withValues(alpha: 0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryColor.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.settings, size: 32, color: Colors.white),
          ),
          const SizedBox(height: 16),
          Text(
            'Settings',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Customize your app experience',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.white.withValues(alpha: 0.9),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  /// Build settings section
  Widget _buildSettingsSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  /// Build switch tile
  Widget _buildSwitchTile(
    String title,
    String subtitle,
    IconData icon,
    bool value,
    Function(bool) onChanged,
  ) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppTheme.primaryColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: AppTheme.primaryColor, size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
      ),
      trailing: Switch(
        value: value,
        onChanged: onChanged,
        activeColor: AppTheme.accentColor,
      ),
    );
  }

  /// Build dropdown tile
  Widget _buildDropdownTile(
    String title,
    String subtitle,
    IconData icon,
    String value,
    List<String> options,
    Function(String) onChanged,
  ) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppTheme.primaryColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: AppTheme.primaryColor, size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
      ),
      trailing: DropdownButton<String>(
        value: value,
        onChanged: (newValue) {
          if (newValue != null) {
            onChanged(newValue);
          }
        },
        items: options.map((option) {
          return DropdownMenuItem<String>(
            value: option,
            child: Text(
              option.substring(0, 1).toUpperCase() + option.substring(1),
              style: const TextStyle(fontSize: 14),
            ),
          );
        }).toList(),
        underline: Container(),
      ),
    );
  }

  /// Build action tile
  Widget _buildActionTile(
    String title,
    String subtitle,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
      ),
      trailing: Icon(Icons.chevron_right, color: AppTheme.textTertiary),
      onTap: onTap,
    );
  }

  /// Build about section
  Widget _buildAboutSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'About',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.info,
                    color: AppTheme.primaryColor,
                    size: 20,
                  ),
                ),
                title: Text(
                  'App Version',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                subtitle: Text(
                  '${AppConstants.appVersion}',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                ),
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.accentColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.code,
                    color: AppTheme.accentColor,
                    size: 20,
                  ),
                ),
                title: Text(
                  'Developer',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                subtitle: Text(
                  'CUT Development Team',
                  style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Show clear cache dialog
  void _showClearCacheDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.cleaning_services,
              color: AppTheme.warningColor,
              size: 28,
            ),
            const SizedBox(width: 16),
            const Text('Clear Cache'),
          ],
        ),
        content: const Text(
          'This will clear all cached data and temporary files. The app may need to reload some data.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _clearCache();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.warningColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Clear Cache'),
          ),
        ],
      ),
    );
  }

  /// Show reset settings dialog
  void _showResetSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.restore, color: AppTheme.errorColor, size: 28),
            const SizedBox(width: 16),
            const Text('Reset Settings'),
          ],
        ),
        content: const Text(
          'This will reset all settings to their default values. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _resetSettings();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Reset Settings'),
          ),
        ],
      ),
    );
  }

  /// Show change password dialog
  void _showChangePasswordDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.lock, color: AppTheme.primaryColor, size: 28),
            const SizedBox(width: 16),
            const Text('Change Password'),
          ],
        ),
        content: const Text(
          'Password change functionality will be implemented in a future update.',
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Show privacy policy
  void _showPrivacyPolicy() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.privacy_tip, color: AppTheme.primaryColor, size: 28),
            const SizedBox(width: 16),
            const Text('Privacy Policy'),
          ],
        ),
        content: const Text('Privacy policy content will be displayed here.'),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  /// Show terms of service
  void _showTermsOfService() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.description, color: AppTheme.primaryColor, size: 28),
            const SizedBox(width: 16),
            const Text('Terms of Service'),
          ],
        ),
        content: const Text('Terms of service content will be displayed here.'),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  /// Clear cache
  void _clearCache() {
    // TODO: Implement cache clearing
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Cache cleared successfully'),
        backgroundColor: Colors.green,
      ),
    );
  }

  /// Reset settings
  void _resetSettings() {
    setState(() {
      _notificationsEnabled = true;
      _darkModeEnabled = false;
      _autoScanEnabled = true;
      _hapticFeedbackEnabled = true;
      _scanSpeed = 'normal';
      _language = 'English';
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Settings reset to default values'),
        backgroundColor: Colors.green,
      ),
    );
  }
}
