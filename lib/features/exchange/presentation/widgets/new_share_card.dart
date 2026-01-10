import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/theme/app_typography.dart';
import '../../domain/vault_entry.dart';
import '../../providers/vault_provider.dart';
import 'retention_selector.dart';

/// Card for creating new shared content (text or image).
class NewShareCard extends ConsumerStatefulWidget {
  const NewShareCard({super.key});

  @override
  ConsumerState<NewShareCard> createState() => _NewShareCardState();
}

class _NewShareCardState extends ConsumerState<NewShareCard>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _textController = TextEditingController();
  final _labelController = TextEditingController();
  XFile? _selectedImage;
  Uint8List? _imageBytes;
  bool _isSharing = false;
  RetentionPeriod _retentionPeriod = RetentionPeriod.defaultPeriod;

  static const int _maxTextLength = 100000; // 100KB text limit

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _textController.dispose();
    _labelController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    debugPrint('[NewShareCard] _pickImage called with source: $source');
    try {
      final picker = ImagePicker();
      debugPrint('[NewShareCard] Calling picker.pickImage...');
      final image = await picker.pickImage(
        source: source,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 85,
      );

      debugPrint('[NewShareCard] picker.pickImage returned: ${image?.path ?? 'null'}');

      if (image != null) {
        debugPrint('[NewShareCard] Reading image bytes from: ${image.path}');
        final bytes = await image.readAsBytes();
        debugPrint('[NewShareCard] Image bytes read: ${bytes.length} bytes');
        if (!mounted) {
          debugPrint('[NewShareCard] Widget disposed while reading image, ignoring');
          return;
        }
        setState(() {
          _selectedImage = image;
          _imageBytes = bytes;
        });
        debugPrint('[NewShareCard] Image state updated successfully');
      } else {
        debugPrint('[NewShareCard] Image picker returned null (user cancelled or permission denied)');
      }
    } catch (e, stack) {
      debugPrint('[NewShareCard] ERROR in _pickImage: $e');
      debugPrint('[NewShareCard] Stack trace: $stack');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to pick image: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _clearImage() {
    setState(() {
      _selectedImage = null;
      _imageBytes = null;
    });
  }

  Future<void> _shareText() async {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    final label = _labelController.text.trim().isEmpty
        ? 'Text note'
        : _labelController.text.trim();

    setState(() => _isSharing = true);

    try {
      await ref.read(vaultNotifierProvider.notifier).shareText(
            label: label,
            content: text,
            retentionPeriod: _retentionPeriod,
          );

      if (!mounted) return;

      _textController.clear();
      _labelController.clear();
      setState(() => _retentionPeriod = RetentionPeriod.defaultPeriod);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Text shared and encrypted'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to share: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSharing = false);
      }
    }
  }

  Future<void> _shareImage() async {
    debugPrint('[NewShareCard] _shareImage called');
    debugPrint('[NewShareCard] _imageBytes is ${_imageBytes == null ? 'null' : '${_imageBytes!.length} bytes'}');
    debugPrint('[NewShareCard] _selectedImage is ${_selectedImage == null ? 'null' : _selectedImage!.path}');

    if (_imageBytes == null || _selectedImage == null) {
      debugPrint('[NewShareCard] _shareImage aborted: imageBytes or selectedImage is null');
      return;
    }

    final label = _labelController.text.trim().isEmpty
        ? 'Image'
        : _labelController.text.trim();

    // Determine MIME type from extension
    final ext = _selectedImage!.path.split('.').last.toLowerCase();
    final mimeType = switch (ext) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'gif' => 'image/gif',
      'webp' => 'image/webp',
      _ => 'image/jpeg',
    };

    debugPrint('[NewShareCard] Sharing image: label="$label", size=${_imageBytes!.length}, mimeType=$mimeType');

    setState(() => _isSharing = true);

    try {
      debugPrint('[NewShareCard] Calling vaultNotifierProvider.shareImage...');
      await ref.read(vaultNotifierProvider.notifier).shareImage(
            label: label,
            imageData: _imageBytes!,
            mimeType: mimeType,
            retentionPeriod: _retentionPeriod,
          );
      debugPrint('[NewShareCard] shareImage completed successfully');

      if (!mounted) return;

      _clearImage();
      _labelController.clear();
      setState(() => _retentionPeriod = RetentionPeriod.defaultPeriod);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Image shared and encrypted'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e, stack) {
      debugPrint('[NewShareCard] ERROR in _shareImage: $e');
      debugPrint('[NewShareCard] Stack trace: $stack');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to share: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isSharing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with tabs
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.add_circle_outline,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'New Share',
                  style: AppTypography.titleMedium,
                ),
              ],
            ),
          ),

          // Tab bar
          TabBar(
            controller: _tabController,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.primary,
            indicatorSize: TabBarIndicatorSize.label,
            dividerColor: AppColors.borderSubtle,
            tabs: const [
              Tab(
                icon: Icon(Icons.text_fields_rounded, size: 20),
                text: 'Text',
              ),
              Tab(
                icon: Icon(Icons.image_outlined, size: 20),
                text: 'Image',
              ),
            ],
          ),

          // Tab content
          SizedBox(
            height: 280,
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildTextTab(),
                _buildImageTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextTab() {
    final charCount = _textController.text.length;
    final isOverLimit = charCount > _maxTextLength;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Label input
          TextField(
            controller: _labelController,
            decoration: const InputDecoration(
              hintText: 'Label (optional)',
              prefixIcon: Icon(Icons.label_outline, size: 20),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 12),

          // Text input
          Expanded(
            child: TextField(
              controller: _textController,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Enter text to share securely...',
                contentPadding: const EdgeInsets.all(12),
                errorText: isOverLimit ? 'Text exceeds limit' : null,
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Retention selector and share button
          Row(
            children: [
              RetentionSelector(
                selected: _retentionPeriod,
                onChanged: (period) => setState(() => _retentionPeriod = period),
                compact: true,
              ),
              const Spacer(),
              ElevatedButton.icon(
                onPressed: _isSharing ||
                        _textController.text.trim().isEmpty ||
                        isOverLimit
                    ? null
                    : _shareText,
                icon: _isSharing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.lock_outline, size: 18),
                label: Text(_isSharing ? 'Encrypting...' : 'Share'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildImageTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Label and retention selector row
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _labelController,
                  decoration: const InputDecoration(
                    hintText: 'Label (optional)',
                    prefixIcon: Icon(Icons.label_outline, size: 20),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              RetentionSelector(
                selected: _retentionPeriod,
                onChanged: (period) => setState(() => _retentionPeriod = period),
                compact: true,
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Image preview or picker
          Expanded(
            child: _selectedImage != null
                ? _buildImagePreview()
                : _buildImagePicker(),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePicker() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.backgroundInput,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.borderSubtle,
          style: BorderStyle.solid,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.add_photo_alternate_outlined,
            size: 48,
            color: AppColors.textTertiary,
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: () => _pickImage(ImageSource.camera),
                icon: const Icon(Icons.camera_alt_outlined, size: 18),
                label: const Text('Camera'),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                onPressed: () => _pickImage(ImageSource.gallery),
                icon: const Icon(Icons.photo_library_outlined, size: 18),
                label: const Text('Gallery'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildImagePreview() {
    return Stack(
      children: [
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            image: DecorationImage(
              image: MemoryImage(_imageBytes!),
              fit: BoxFit.cover,
            ),
          ),
        ),

        // Size badge
        Positioned(
          left: 8,
          bottom: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.overlay,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              _formatBytes(_imageBytes!.length),
              style: AppTypography.labelSmall.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ),

        // Clear button
        Positioned(
          right: 8,
          top: 8,
          child: IconButton(
            onPressed: _clearImage,
            icon: const Icon(Icons.close_rounded),
            style: IconButton.styleFrom(
              backgroundColor: AppColors.overlay,
              foregroundColor: AppColors.textPrimary,
            ),
          ),
        ),

        // Share button
        Positioned(
          right: 8,
          bottom: 8,
          child: ElevatedButton.icon(
            onPressed: _isSharing ? null : _shareImage,
            icon: _isSharing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.lock_outline, size: 18),
            label: Text(_isSharing ? 'Encrypting...' : 'Share'),
          ),
        ),
      ],
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
