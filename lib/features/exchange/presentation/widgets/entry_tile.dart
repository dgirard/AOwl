import 'package:flutter/material.dart';

import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/theme/app_typography.dart';
import '../../../../domain/models/vault_entry.dart';
import 'retention_selector.dart';

/// Tile widget displaying a vault entry.
class EntryTile extends StatelessWidget {
  const EntryTile({
    super.key,
    required this.entry,
    required this.onTap,
    this.onLongPress,
    this.onDelete,
    this.showSha = false,
  });

  final VaultEntry entry;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onDelete;
  final bool showSha;

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(entry.id),
      direction: onDelete != null
          ? DismissDirection.endToStart
          : DismissDirection.none,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppColors.error.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(
          Icons.delete_outline_rounded,
          color: AppColors.error,
        ),
      ),
      confirmDismiss: (_) async {
        return await _showDeleteConfirmation(context);
      },
      onDismissed: (_) => onDelete?.call(),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.backgroundCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.borderSubtle),
            ),
            child: Row(
              children: [
                // Type icon
                _EntryIcon(type: entry.type),
                const SizedBox(width: 12),

                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Label
                      Text(
                        entry.label,
                        style: AppTypography.titleSmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),

                      // Custom ID (if set)
                      if (entry.customId != null) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Icon(
                              Icons.tag,
                              size: 12,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                entry.customId!,
                                style: AppTypography.labelSmall.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 4),

                      // Metadata row
                      Row(
                        children: [
                          // Timestamp
                          Icon(
                            Icons.access_time_rounded,
                            size: 12,
                            color: AppColors.textTertiary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _formatTimestamp(entry.updatedAt),
                            style: AppTypography.labelSmall,
                          ),
                          const SizedBox(width: 12),

                          // Size
                          Icon(
                            Icons.data_usage_rounded,
                            size: 12,
                            color: AppColors.textTertiary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            entry.formattedSize,
                            style: AppTypography.labelSmall,
                          ),

                          // SHA preview
                          if (showSha && entry.sha != null) ...[
                            const SizedBox(width: 12),
                            Icon(
                              Icons.tag_rounded,
                              size: 12,
                              color: AppColors.textTertiary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              entry.sha!.substring(0, 7),
                              style: AppTypography.codeSmall.copyWith(
                                color: AppColors.textTertiary,
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ],
                      ),

                      // Retention badge (if set)
                      if (entry.retentionPeriod != null) ...[
                        const SizedBox(height: 4),
                        _RetentionBadge(entry: entry),
                      ],
                    ],
                  ),
                ),

                // Encrypted badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.encrypted.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.lock_rounded,
                        size: 12,
                        color: AppColors.encrypted,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'E2E',
                        style: AppTypography.labelSmall.copyWith(
                          color: AppColors.encrypted,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textTertiary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<bool> _showDeleteConfirmation(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete Entry?'),
            content: Text(
              'This will permanently delete "${entry.label}" from your vault.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                ),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;
  }

  String _formatTimestamp(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inMinutes < 1) {
      return 'Just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else {
      return '${time.month}/${time.day}/${time.year}';
    }
  }
}

class _EntryIcon extends StatelessWidget {
  const _EntryIcon({required this.type});

  final EntryType type;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (type) {
      EntryType.text => (Icons.text_snippet_outlined, AppColors.info),
      EntryType.image => (Icons.image_outlined, AppColors.secondary),
    };

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, color: color, size: 24),
    );
  }
}

/// Compact entry tile for lists.
class EntryListTile extends StatelessWidget {
  const EntryListTile({
    super.key,
    required this.entry,
    required this.onTap,
    this.trailing,
  });

  final VaultEntry entry;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: _EntryIcon(type: entry.type),
      title: Text(
        entry.label,
        style: AppTypography.titleSmall,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        entry.customId != null
            ? '${entry.customId} • ${entry.formattedSize}'
            : '${entry.formattedSize} • ${_formatDate(entry.updatedAt)}',
        style: AppTypography.bodySmall,
      ),
      trailing: trailing ??
          const Icon(
            Icons.chevron_right_rounded,
            color: AppColors.textTertiary,
          ),
    );
  }

  String _formatDate(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inHours < 24) {
      return 'Today';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays} days ago';
    } else {
      return '${time.month}/${time.day}';
    }
  }
}

/// Badge showing retention period and time remaining.
class _RetentionBadge extends StatelessWidget {
  const _RetentionBadge({required this.entry});

  final VaultEntry entry;

  @override
  Widget build(BuildContext context) {
    final period = entry.retentionPeriod;
    if (period == null) return const SizedBox.shrink();

    final remaining = entry.timeRemaining;
    final formattedRemaining = entry.formattedTimeRemaining;
    final color = _getColor(remaining);
    final icon = RetentionSelector.iconFor(period);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 4),
          Text(
            formattedRemaining ?? period.label,
            style: AppTypography.labelSmall.copyWith(
              color: color,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Color _getColor(Duration? remaining) {
    if (remaining == null) return AppColors.textTertiary;
    if (remaining == Duration.zero) return AppColors.error;
    if (remaining.inHours < 1) return AppColors.error;
    if (remaining.inHours < 24) return AppColors.warning;
    if (remaining.inDays < 7) return AppColors.info;
    return AppColors.textTertiary;
  }
}
