import 'package:flutter/material.dart';

import '../../core/github/github_errors.dart';
import '../../features/exchange/providers/vault_state.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

/// Service for handling and displaying errors to users.
class ErrorHandlerService {
  /// Shows an error dialog for GitHub errors.
  static Future<ErrorAction?> showGitHubError(
    BuildContext context,
    GitHubError error,
  ) async {
    return switch (error) {
      AuthenticationFailed() => _showAuthError(context),
      RateLimitExceeded(:final resetAt) => _showRateLimitError(context, resetAt),
      ConflictError() => _showConflictError(context),
      ServerError(:final statusCode) => _showServerError(context, statusCode),
      NetworkError(:final details) => _showNetworkError(context, details),
      NotFound() => _showNotFoundError(context),
      AccessForbidden() => _showAccessForbiddenError(context),
      UnknownGitHubError(:final details) => _showGenericError(context, details),
    };
  }

  /// Shows an error dialog for vault errors.
  static Future<ErrorAction?> showVaultError(
    BuildContext context,
    VaultError error,
  ) async {
    return switch (error) {
      VaultNetworkError(:final details) => _showNetworkError(context, details),
      VaultGitHubError(:final details) => _showGenericError(context, details),
      VaultDecryptionError() => _showDecryptionError(context),
      VaultConflictError() => _showConflictError(context),
      VaultRateLimitError(:final retryAfter) => _showRateLimitError(
          context,
          retryAfter != null ? DateTime.now().add(retryAfter) : null,
        ),
      VaultNotInitializedError() => _showNotInitializedError(context),
      VaultEntryNotFoundError() => _showNotFoundError(context),
    };
  }

  static Future<ErrorAction?> _showAuthError(BuildContext context) {
    return _showErrorDialog(
      context,
      icon: Icons.key_off_rounded,
      iconColor: AppColors.error,
      title: 'Authentication Failed',
      message:
          'Your GitHub token may have expired or been revoked. Please update your credentials.',
      primaryAction: 'Re-authenticate',
      primaryActionValue: ErrorAction.reauthenticate,
      secondaryAction: 'Cancel',
    );
  }

  static Future<ErrorAction?> _showRateLimitError(
    BuildContext context,
    DateTime? resetAt,
  ) {
    final message = resetAt != null
        ? 'GitHub API rate limit exceeded. Please wait until ${_formatTime(resetAt)} to try again.'
        : 'GitHub API rate limit exceeded. Please wait a few minutes before trying again.';

    return _showErrorDialog(
      context,
      icon: Icons.timer_outlined,
      iconColor: AppColors.warning,
      title: 'Rate Limit Exceeded',
      message: message,
      primaryAction: 'OK',
      primaryActionValue: ErrorAction.dismiss,
      showCountdown: resetAt,
    );
  }

  static Future<ErrorAction?> _showConflictError(BuildContext context) {
    return _showErrorDialog(
      context,
      icon: Icons.sync_problem_rounded,
      iconColor: AppColors.warning,
      title: 'Sync Conflict',
      message:
          'Your vault was modified on another device. Would you like to sync and merge changes?',
      primaryAction: 'Sync & Merge',
      primaryActionValue: ErrorAction.retry,
      secondaryAction: 'Cancel',
    );
  }

  static Future<ErrorAction?> _showServerError(
    BuildContext context,
    int statusCode,
  ) {
    return _showErrorDialog(
      context,
      icon: Icons.cloud_off_rounded,
      iconColor: AppColors.error,
      title: 'GitHub Unavailable',
      message:
          'GitHub is experiencing issues (Error $statusCode). Please try again later.',
      primaryAction: 'Retry',
      primaryActionValue: ErrorAction.retry,
      secondaryAction: 'Cancel',
    );
  }

  static Future<ErrorAction?> _showNetworkError(
    BuildContext context,
    String details,
  ) {
    return _showErrorDialog(
      context,
      icon: Icons.wifi_off_rounded,
      iconColor: AppColors.error,
      title: 'Connection Failed',
      message: 'Unable to connect to GitHub. Check your internet connection.',
      primaryAction: 'Retry',
      primaryActionValue: ErrorAction.retry,
      secondaryAction: 'Work Offline',
      secondaryActionValue: ErrorAction.workOffline,
    );
  }

  static Future<ErrorAction?> _showNotFoundError(BuildContext context) {
    return _showErrorDialog(
      context,
      icon: Icons.search_off_rounded,
      iconColor: AppColors.warning,
      title: 'Not Found',
      message: 'The requested resource could not be found.',
      primaryAction: 'OK',
      primaryActionValue: ErrorAction.dismiss,
    );
  }

  static Future<ErrorAction?> _showAccessForbiddenError(BuildContext context) {
    return _showErrorDialog(
      context,
      icon: Icons.block_rounded,
      iconColor: AppColors.error,
      title: 'Access Denied',
      message:
          'You don\'t have permission to access this repository. Check your token permissions.',
      primaryAction: 'Update Token',
      primaryActionValue: ErrorAction.reauthenticate,
      secondaryAction: 'Cancel',
    );
  }

  static Future<ErrorAction?> _showDecryptionError(BuildContext context) {
    return _showErrorDialog(
      context,
      icon: Icons.lock_open_rounded,
      iconColor: AppColors.error,
      title: 'Decryption Failed',
      message:
          'Unable to decrypt the vault. This could happen if you\'re using the wrong password.',
      primaryAction: 'Try Again',
      primaryActionValue: ErrorAction.retry,
      secondaryAction: 'Reset Vault',
      secondaryActionValue: ErrorAction.reset,
    );
  }

  static Future<ErrorAction?> _showNotInitializedError(BuildContext context) {
    return _showErrorDialog(
      context,
      icon: Icons.folder_open_rounded,
      iconColor: AppColors.warning,
      title: 'Vault Not Initialized',
      message: 'Your vault hasn\'t been set up yet. Would you like to set it up now?',
      primaryAction: 'Set Up Vault',
      primaryActionValue: ErrorAction.setup,
      secondaryAction: 'Cancel',
    );
  }

  static Future<ErrorAction?> _showGenericError(
    BuildContext context,
    String details,
  ) {
    return _showErrorDialog(
      context,
      icon: Icons.error_outline_rounded,
      iconColor: AppColors.error,
      title: 'Something Went Wrong',
      message: details,
      primaryAction: 'Retry',
      primaryActionValue: ErrorAction.retry,
      secondaryAction: 'Cancel',
    );
  }

  static Future<ErrorAction?> _showErrorDialog(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String message,
    required String primaryAction,
    required ErrorAction primaryActionValue,
    String? secondaryAction,
    ErrorAction? secondaryActionValue,
    DateTime? showCountdown,
  }) {
    return showDialog<ErrorAction>(
      context: context,
      builder: (context) => _ErrorDialog(
        icon: icon,
        iconColor: iconColor,
        title: title,
        message: message,
        primaryAction: primaryAction,
        primaryActionValue: primaryActionValue,
        secondaryAction: secondaryAction,
        secondaryActionValue: secondaryActionValue,
        countdownUntil: showCountdown,
      ),
    );
  }

  static String _formatTime(DateTime time) {
    return '${time.hour}:${time.minute.toString().padLeft(2, '0')}';
  }
}

/// Actions that can be taken in response to an error.
enum ErrorAction {
  dismiss,
  retry,
  reauthenticate,
  workOffline,
  reset,
  setup,
}

class _ErrorDialog extends StatefulWidget {
  const _ErrorDialog({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.message,
    required this.primaryAction,
    required this.primaryActionValue,
    this.secondaryAction,
    this.secondaryActionValue,
    this.countdownUntil,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String message;
  final String primaryAction;
  final ErrorAction primaryActionValue;
  final String? secondaryAction;
  final ErrorAction? secondaryActionValue;
  final DateTime? countdownUntil;

  @override
  State<_ErrorDialog> createState() => _ErrorDialogState();
}

class _ErrorDialogState extends State<_ErrorDialog> {
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: AppColors.backgroundCard,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: widget.iconColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              widget.icon,
              size: 48,
              color: widget.iconColor,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            widget.title,
            style: AppTypography.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            widget.message,
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          if (widget.countdownUntil != null) ...[
            const SizedBox(height: 16),
            _CountdownTimer(until: widget.countdownUntil!),
          ],
        ],
      ),
      actions: [
        if (widget.secondaryAction != null)
          TextButton(
            onPressed: () =>
                Navigator.pop(context, widget.secondaryActionValue),
            child: Text(widget.secondaryAction!),
          ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, widget.primaryActionValue),
          child: Text(widget.primaryAction),
        ),
      ],
    );
  }
}

class _CountdownTimer extends StatefulWidget {
  const _CountdownTimer({required this.until});

  final DateTime until;

  @override
  State<_CountdownTimer> createState() => _CountdownTimerState();
}

class _CountdownTimerState extends State<_CountdownTimer> {
  late Duration _remaining;

  @override
  void initState() {
    super.initState();
    _updateRemaining();
    _startTimer();
  }

  void _updateRemaining() {
    _remaining = widget.until.difference(DateTime.now());
    if (_remaining.isNegative) {
      _remaining = Duration.zero;
    }
  }

  void _startTimer() {
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() => _updateRemaining());
        if (_remaining > Duration.zero) {
          _startTimer();
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final minutes = _remaining.inMinutes;
    final seconds = _remaining.inSeconds % 60;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.backgroundInput,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.timer_outlined, size: 16, color: AppColors.warning),
          const SizedBox(width: 8),
          Text(
            '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
            style: AppTypography.titleMedium.copyWith(
              fontFamily: 'JetBrainsMono',
            ),
          ),
        ],
      ),
    );
  }
}
