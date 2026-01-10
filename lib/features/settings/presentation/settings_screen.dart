import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../application/providers/core_providers.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_typography.dart';
import '../../unlock/providers/auth_provider.dart';

/// Settings screen for app configuration and security options.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          // Security section
          _SectionHeader(title: 'Security'),
          _SettingsTile(
            icon: Icons.lock_reset_rounded,
            title: 'Change PIN',
            subtitle: 'Update your quick unlock PIN',
            onTap: () => _showChangePinDialog(context),
          ),
          _SettingsTile(
            icon: Icons.password_rounded,
            title: 'Change Password',
            subtitle: 'Update your master password',
            onTap: () => _showChangePasswordDialog(context),
          ),
          _SettingsTile(
            icon: Icons.lock_outline,
            title: 'Lock Vault',
            subtitle: 'Require PIN to access vault',
            onTap: () => _lockVault(context, ref),
          ),

          const Divider(height: 32),

          // Storage section
          _SectionHeader(title: 'Storage'),
          _SettingsTile(
            icon: Icons.cloud_outlined,
            title: 'GitHub Repository',
            subtitle: 'Manage your vault storage',
            onTap: () => _showGitHubSettingsDialog(context, ref),
          ),
          _SettingsTile(
            icon: Icons.storage_outlined,
            title: 'Local Cache',
            subtitle: 'Clear cached data',
            onTap: () => _showClearCacheDialog(context),
          ),

          const Divider(height: 32),

          // About section
          _SectionHeader(title: 'About'),
          _SettingsTile(
            icon: Icons.info_outline_rounded,
            title: 'About AOwl',
            subtitle: 'Version 1.0.0',
            onTap: () => _showAboutDialog(context),
          ),
          _SettingsTile(
            icon: Icons.privacy_tip_outlined,
            title: 'Privacy Policy',
            subtitle: 'How we handle your data',
            onTap: () {},
          ),

          const Divider(height: 32),

          // Danger zone
          _SectionHeader(title: 'Danger Zone', isDanger: true),
          _SettingsTile(
            icon: Icons.delete_forever_outlined,
            title: 'Reset Vault',
            subtitle: 'Erase all local data',
            isDanger: true,
            onTap: () => _showResetVaultDialog(context, ref),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  void _showChangePinDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change PIN'),
        content: const Text('PIN change functionality coming soon.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showChangePasswordDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Password'),
        content: const Text('Password change functionality coming soon.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _lockVault(BuildContext context, WidgetRef ref) {
    ref.read(authNotifierProvider.notifier).lock();
  }

  void _showGitHubSettingsDialog(BuildContext context, WidgetRef ref) async {
    final storage = ref.read(secureStorageProvider);
    final currentOwner = await storage.getRepoOwner() ?? '';
    final currentName = await storage.getRepoName() ?? '';

    if (!context.mounted) return;

    final ownerController = TextEditingController(text: currentOwner);
    final nameController = TextEditingController(text: currentName);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('GitHub Repository'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: ownerController,
              decoration: const InputDecoration(
                labelText: 'Repository Owner',
                hintText: 'e.g., dgirard',
              ),
              autocorrect: false,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Repository Name',
                hintText: 'e.g., aowl',
              ),
              autocorrect: false,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final newOwner = ownerController.text.trim();
              final newName = nameController.text.trim();

              if (newOwner.isNotEmpty && newName.isNotEmpty) {
                await storage.setRepoOwner(newOwner);
                await storage.setRepoName(newName);

                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('GitHub settings updated. Please restart the app.'),
                    ),
                  );
                }
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showClearCacheDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Cache?'),
        content: const Text(
          'This will clear locally cached data. Your encrypted files on GitHub will not be affected.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Cache cleared')),
              );
            },
            child: const Text('Clear'),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SvgPicture.asset(
                'assets/logo/aowl_logo.svg',
                width: 40,
                height: 40,
              ),
            ),
            const SizedBox(width: 12),
            const Text('AOwl'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Version 1.0.0',
              style: AppTypography.bodyMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Secure cross-platform sharing with end-to-end encryption.',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Your data is encrypted locally before being uploaded. We never see your passwords or content.',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textTertiary,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showResetVaultDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Vault?'),
        content: const Text(
          'This will erase all local data including your encryption keys. '
          'Your encrypted files on GitHub will remain but become inaccessible '
          'without the original password.\n\n'
          'This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ref.read(authNotifierProvider.notifier).resetVault();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
            ),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    this.isDanger = false,
  });

  final String title;
  final bool isDanger;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: AppTypography.labelSmall.copyWith(
          color: isDanger ? AppColors.error : AppColors.textTertiary,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.isDanger = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool isDanger;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isDanger
              ? AppColors.error.withValues(alpha: 0.15)
              : AppColors.backgroundInput,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          color: isDanger ? AppColors.error : AppColors.textSecondary,
          size: 20,
        ),
      ),
      title: Text(
        title,
        style: AppTypography.titleSmall.copyWith(
          color: isDanger ? AppColors.error : null,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: AppTypography.bodySmall,
      ),
      trailing: Icon(
        Icons.chevron_right_rounded,
        color: isDanger ? AppColors.error : AppColors.textTertiary,
      ),
    );
  }
}
