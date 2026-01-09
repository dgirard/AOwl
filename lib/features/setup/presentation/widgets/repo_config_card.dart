import 'package:flutter/material.dart';

import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/theme/app_typography.dart';

/// Card for configuring GitHub repository settings.
class RepoConfigCard extends StatefulWidget {
  const RepoConfigCard({
    super.key,
    required this.onConfigChanged,
    this.initialOwner,
    this.initialRepo,
    this.initialToken,
  });

  final void Function(String owner, String repo, String token) onConfigChanged;
  final String? initialOwner;
  final String? initialRepo;
  final String? initialToken;

  @override
  State<RepoConfigCard> createState() => _RepoConfigCardState();
}

class _RepoConfigCardState extends State<RepoConfigCard> {
  late final TextEditingController _ownerController;
  late final TextEditingController _repoController;
  late final TextEditingController _tokenController;
  bool _obscureToken = true;

  @override
  void initState() {
    super.initState();
    _ownerController = TextEditingController(text: widget.initialOwner);
    _repoController = TextEditingController(text: widget.initialRepo);
    _tokenController = TextEditingController(text: widget.initialToken);
  }

  @override
  void dispose() {
    _ownerController.dispose();
    _repoController.dispose();
    _tokenController.dispose();
    super.dispose();
  }

  void _notifyChange() {
    widget.onConfigChanged(
      _ownerController.text.trim(),
      _repoController.text.trim(),
      _tokenController.text.trim(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.cloud_outlined,
                    color: AppColors.secondary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'GitHub Repository',
                  style: AppTypography.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Connect to a private GitHub repository to store your encrypted data.',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 20),

            // Owner field
            TextField(
              controller: _ownerController,
              onChanged: (_) => _notifyChange(),
              decoration: const InputDecoration(
                labelText: 'Owner/Organization',
                hintText: 'username or org-name',
                prefixIcon: Icon(Icons.person_outline),
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),

            // Repository field
            TextField(
              controller: _repoController,
              onChanged: (_) => _notifyChange(),
              decoration: const InputDecoration(
                labelText: 'Repository Name',
                hintText: 'my-secure-vault',
                prefixIcon: Icon(Icons.folder_outlined),
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 16),

            // Token field
            TextField(
              controller: _tokenController,
              onChanged: (_) => _notifyChange(),
              obscureText: _obscureToken,
              decoration: InputDecoration(
                labelText: 'Personal Access Token',
                hintText: 'ghp_xxxxxxxxxxxx',
                prefixIcon: const Icon(Icons.key_outlined),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureToken
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                  onPressed: () {
                    setState(() => _obscureToken = !_obscureToken);
                  },
                ),
              ),
              textInputAction: TextInputAction.done,
            ),
            const SizedBox(height: 12),

            // Help text
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.backgroundInput,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline,
                    color: AppColors.info,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Token needs repo scope for private repositories',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
