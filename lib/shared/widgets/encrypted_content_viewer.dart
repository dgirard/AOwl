import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:super_clipboard/super_clipboard.dart';

import '../../domain/models/vault_entry.dart';
import '../../features/exchange/presentation/widgets/retention_selector.dart';
import '../../features/exchange/providers/vault_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Viewer for encrypted vault content (text or image).
class EncryptedContentViewer extends ConsumerStatefulWidget {
  const EncryptedContentViewer({
    super.key,
    required this.entry,
  });

  final VaultEntry entry;

  /// Show the viewer as a modal bottom sheet.
  static Future<void> show({
    required BuildContext context,
    required VaultEntry entry,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: AppColors.backgroundCard,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: EncryptedContentViewer(entry: entry),
        ),
      ),
    );
  }

  @override
  ConsumerState<EncryptedContentViewer> createState() =>
      _EncryptedContentViewerState();
}

class _EncryptedContentViewerState
    extends ConsumerState<EncryptedContentViewer> {
  bool _isLoading = true;
  String? _error;
  Uint8List? _decryptedContent;
  String? _textContent;
  Timer? _clipboardClearTimer;
  bool _copiedToClipboard = false;

  static const Duration _clipboardClearDuration = Duration(seconds: 30);

  @override
  void initState() {
    super.initState();
    _loadContent();
  }

  @override
  void dispose() {
    _clipboardClearTimer?.cancel();
    // Clear clipboard if content was copied
    if (_copiedToClipboard) {
      Clipboard.setData(const ClipboardData(text: ''));
    }
    super.dispose();
  }

  Future<void> _loadContent() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final content = await ref
          .read(vaultNotifierProvider.notifier)
          .getEntryContent(widget.entry.id);

      if (!mounted) return;

      if (content == null) {
        setState(() {
          _error = 'Failed to decrypt content';
          _isLoading = false;
        });
        return;
      }

      setState(() {
        _decryptedContent = content;
        if (widget.entry.isText) {
          _textContent = utf8.decode(content);
        }
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _copyToClipboard() async {
    if (_textContent == null) return;

    await Clipboard.setData(ClipboardData(text: _textContent!));

    setState(() => _copiedToClipboard = true);

    // Auto-clear clipboard after duration
    _clipboardClearTimer?.cancel();
    _clipboardClearTimer = Timer(_clipboardClearDuration, () {
      Clipboard.setData(const ClipboardData(text: ''));
      if (mounted) {
        setState(() => _copiedToClipboard = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Clipboard cleared for security'),
            backgroundColor: AppColors.info,
          ),
        );
      }
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Copied! Will clear in ${_clipboardClearDuration.inSeconds}s',
        ),
        backgroundColor: AppColors.success,
      ),
    );
  }

  Future<void> _copyImageToClipboard() async {
    if (_decryptedContent == null || !widget.entry.isImage) return;

    final clipboard = SystemClipboard.instance;
    if (clipboard == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Clipboard not available on this platform'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }

    try {
      final item = DataWriterItem();

      // Determine format based on mime type
      final mimeType = widget.entry.mimeType ?? 'image/png';
      if (mimeType.contains('png')) {
        item.add(Formats.png(_decryptedContent!));
      } else if (mimeType.contains('jpeg') || mimeType.contains('jpg')) {
        item.add(Formats.jpeg(_decryptedContent!));
      } else {
        // Default to PNG
        item.add(Formats.png(_decryptedContent!));
      }

      await clipboard.write([item]);

      setState(() => _copiedToClipboard = true);

      // Auto-clear clipboard after duration
      _clipboardClearTimer?.cancel();
      _clipboardClearTimer = Timer(_clipboardClearDuration, () async {
        try {
          await clipboard.write([]); // Clear clipboard
        } catch (e) {
          debugPrint('[EncryptedContentViewer] Failed to clear clipboard: $e');
        }
        if (mounted) {
          setState(() => _copiedToClipboard = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Clipboard cleared for security'),
              backgroundColor: AppColors.info,
            ),
          );
        }
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Image copied! Will clear in ${_clipboardClearDuration.inSeconds}s',
          ),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      debugPrint('[EncryptedContentViewer] Failed to copy image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to copy image: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _showChangeRetentionDialog() async {
    final currentPeriod = widget.entry.retentionPeriod ?? RetentionPeriod.oneDay;

    final result = await showModalBottomSheet<RetentionPeriod>(
      context: context,
      backgroundColor: AppColors.backgroundCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _RetentionPickerSheet(selected: currentPeriod),
    );

    if (result != null && result != currentPeriod) {
      await ref.read(vaultNotifierProvider.notifier).changeRetention(
            widget.entry.id,
            result,
          );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Retention changed to ${result.label}'),
          backgroundColor: AppColors.success,
        ),
      );

      // Close the viewer and refresh
      Navigator.pop(context);
    }
  }

  Future<void> _shareContent() async {
    if (_decryptedContent == null) return;

    if (widget.entry.isText && _textContent != null) {
      await Share.share(
        _textContent!,
        subject: widget.entry.label,
      );
    } else if (widget.entry.isImage) {
      final xFile = XFile.fromData(
        _decryptedContent!,
        mimeType: widget.entry.mimeType ?? 'image/jpeg',
        name: '${widget.entry.label}.jpg',
      );
      await Share.shareXFiles([xFile], subject: widget.entry.label);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Handle
        Center(
          child: Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.borderSubtle,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),

        // Header
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              _EntryTypeIcon(type: widget.entry.type),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.entry.label,
                      style: AppTypography.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          '${widget.entry.formattedSize} • ${_formatDate(widget.entry.updatedAt)}',
                          style: AppTypography.bodySmall,
                        ),
                        if (widget.entry.retentionPeriod != null) ...[
                          const SizedBox(width: 8),
                          InkWell(
                            onTap: _showChangeRetentionDialog,
                            borderRadius: BorderRadius.circular(4),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: RetentionSelector.colorFor(widget.entry.retentionPeriod!)
                                    .withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.timer_outlined,
                                    size: 10,
                                    color: RetentionSelector.colorFor(
                                        widget.entry.retentionPeriod!),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    widget.entry.formattedTimeRemaining ??
                                        widget.entry.retentionPeriod!.label,
                                    style: AppTypography.labelSmall.copyWith(
                                      color: RetentionSelector.colorFor(
                                          widget.entry.retentionPeriod!),
                                      fontSize: 10,
                                    ),
                                  ),
                                  const SizedBox(width: 2),
                                  Icon(
                                    Icons.edit,
                                    size: 8,
                                    color: RetentionSelector.colorFor(
                                        widget.entry.retentionPeriod!),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded),
              ),
            ],
          ),
        ),

        const Divider(height: 1),

        // Content
        Expanded(
          child: _buildContent(),
        ),

        // Actions
        if (!_isLoading && _error == null)
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Copy button for text
                  if (widget.entry.isText) ...[
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _copyToClipboard,
                        icon: Icon(
                          _copiedToClipboard
                              ? Icons.check_rounded
                              : Icons.copy_rounded,
                          size: 18,
                        ),
                        label: Text(_copiedToClipboard ? 'Copied!' : 'Copy'),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  // Copy button for images
                  if (widget.entry.isImage) ...[
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _copyImageToClipboard,
                        icon: Icon(
                          _copiedToClipboard
                              ? Icons.check_rounded
                              : Icons.copy_rounded,
                          size: 18,
                        ),
                        label: Text(_copiedToClipboard ? 'Copied!' : 'Copy'),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _shareContent,
                      icon: const Icon(Icons.share_rounded, size: 18),
                      label: const Text('Share'),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Decrypting...'),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                size: 48,
                color: AppColors.error,
              ),
              const SizedBox(height: 16),
              Text(
                'Failed to decrypt',
                style: AppTypography.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                style: AppTypography.bodySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loadContent,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (widget.entry.isText && _textContent != null) {
      return _TextContentView(text: _textContent!);
    }

    if (widget.entry.isImage && _decryptedContent != null) {
      return _ImageContentView(imageBytes: _decryptedContent!);
    }

    return const Center(
      child: Text('Unknown content type'),
    );
  }

  String _formatDate(DateTime time) {
    return '${time.month}/${time.day}/${time.year} ${time.hour}:${time.minute.toString().padLeft(2, '0')}';
  }
}

class _EntryTypeIcon extends StatelessWidget {
  const _EntryTypeIcon({required this.type});

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

class _TextContentView extends StatelessWidget {
  const _TextContentView({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.backgroundInput,
          borderRadius: BorderRadius.circular(12),
        ),
        child: SelectableText(
          text,
          style: AppTypography.bodyMedium.copyWith(
            height: 1.6,
          ),
        ),
      ),
    );
  }
}

class _ImageContentView extends StatefulWidget {
  const _ImageContentView({required this.imageBytes});

  final Uint8List imageBytes;

  @override
  State<_ImageContentView> createState() => _ImageContentViewState();
}

class _ImageContentViewState extends State<_ImageContentView> {
  final TransformationController _controller = TransformationController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _resetZoom() {
    _controller.value = Matrix4.identity();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        InteractiveViewer(
          transformationController: _controller,
          minScale: 0.5,
          maxScale: 4.0,
          child: Center(
            child: Image.memory(
              widget.imageBytes,
              fit: BoxFit.contain,
            ),
          ),
        ),

        // Reset zoom button
        Positioned(
          right: 16,
          top: 16,
          child: IconButton(
            onPressed: _resetZoom,
            icon: const Icon(Icons.zoom_out_map_rounded),
            style: IconButton.styleFrom(
              backgroundColor: AppColors.overlay,
              foregroundColor: AppColors.textPrimary,
            ),
          ),
        ),
      ],
    );
  }
}

/// Bottom sheet for selecting a retention period.
class _RetentionPickerSheet extends StatelessWidget {
  const _RetentionPickerSheet({required this.selected});

  final RetentionPeriod selected;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.borderSubtle,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),

            // Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Icon(
                    Icons.timer_outlined,
                    color: AppColors.primary,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Change Retention Period',
                    style: AppTypography.titleMedium,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Select how long to keep this document',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Options
            ...RetentionPeriod.values.map((period) => _buildOption(context, period)),
          ],
        ),
      ),
    );
  }

  Widget _buildOption(BuildContext context, RetentionPeriod period) {
    final isSelected = period == selected;
    final color = RetentionSelector.colorFor(period);
    final icon = RetentionSelector.iconFor(period);

    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: isSelected ? 0.2 : 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(
        period.label,
        style: AppTypography.bodyMedium.copyWith(
          color: isSelected ? color : AppColors.textPrimary,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      trailing: isSelected
          ? Icon(Icons.check_circle, color: color, size: 24)
          : null,
      onTap: () => Navigator.pop(context, period),
    );
  }
}
