import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../features/exchange/domain/vault_entry.dart';
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
          _textContent = String.fromCharCodes(content);
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
                    Text(
                      '${widget.entry.formattedSize} • ${_formatDate(widget.entry.updatedAt)}',
                      style: AppTypography.bodySmall,
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
