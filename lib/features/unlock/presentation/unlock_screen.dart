import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_typography.dart';
import '../../../shared/widgets/error_dialog.dart';
import '../../setup/presentation/widgets/pin_input.dart';
import '../providers/auth_provider.dart';
import '../providers/auth_state.dart';

/// Unlock screen with PIN pad.
class UnlockScreen extends ConsumerStatefulWidget {
  const UnlockScreen({super.key});

  @override
  ConsumerState<UnlockScreen> createState() => _UnlockScreenState();
}

class _UnlockScreenState extends ConsumerState<UnlockScreen> {
  final _pinInputKey = GlobalKey<PinInputState>();
  String _pin = '';
  bool _isLoading = false;
  bool _hasError = false;
  Timer? _lockoutTimer;
  Duration? _remainingLockout;

  @override
  void dispose() {
    _lockoutTimer?.cancel();
    super.dispose();
  }

  void _startLockoutTimer(Duration remaining) {
    _lockoutTimer?.cancel();
    _remainingLockout = remaining;

    _lockoutTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      setState(() {
        if (_remainingLockout != null &&
            _remainingLockout!.inSeconds > 0) {
          _remainingLockout = Duration(
            seconds: _remainingLockout!.inSeconds - 1,
          );
        } else {
          _remainingLockout = null;
          timer.cancel();
          // Re-check auth state
          ref.invalidate(authNotifierProvider);
        }
      });
    });
  }

  Future<void> _handlePinComplete(String pin) async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      await ref.read(authNotifierProvider.notifier).unlockWithPin(pin);

      final asyncState = ref.read(authNotifierProvider);
      final state = asyncState.valueOrNull;

      if (state is AuthStateError) {
        if (!mounted) return;

        setState(() => _hasError = true);

        final error = state.error;
        if (error is LockedOutError) {
          _startLockoutTimer(error.duration);
        } else if (error is WrongPinError) {
          // Shake animation could be added here
          _pinInputKey.currentState?.clear();
        }

        await ErrorDialog.showSimple(
          context: context,
          title: 'Authentication Failed',
          message: error.message,
        );
      }
      // If successful, router will handle navigation
    } catch (e) {
      if (!mounted) return;
      await ErrorDialog.showSimple(
        context: context,
        title: 'Error',
        message: 'An unexpected error occurred.',
        details: e.toString(),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _handleDigit(String digit) {
    if (_pin.length < 6 && _remainingLockout == null) {
      setState(() {
        _pin += digit;
        _hasError = false;
      });

      if (_pin.length == 6) {
        _handlePinComplete(_pin);
      }
    }
  }

  void _handleBackspace() {
    if (_pin.isNotEmpty) {
      setState(() {
        _pin = _pin.substring(0, _pin.length - 1);
        _hasError = false;
      });
    }
  }

  void _handleClear() {
    setState(() {
      _pin = '';
      _hasError = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final asyncAuthState = ref.watch(authNotifierProvider);
    final authState = asyncAuthState.valueOrNull;

    // Handle lockout state
    int failedAttempts = 0;
    if (authState is AuthStateLocked) {
      failedAttempts = authState.failedAttempts;
      if (authState.isLockedOut && _remainingLockout == null) {
        final remaining = authState.remainingLockout;
        if (remaining != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _startLockoutTimer(remaining);
          });
        }
      }
    }

    final isLockedOut = _remainingLockout != null;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 2),

            // App icon and title
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.shield_outlined,
                size: 40,
                color: AppColors.background,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'AShare',
              style: AppTypography.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              isLockedOut ? 'Account Locked' : 'Enter your PIN',
              style: AppTypography.bodyMedium.copyWith(
                color: isLockedOut ? AppColors.error : AppColors.textSecondary,
              ),
            ),

            const SizedBox(height: 40),

            // PIN dots display
            _PinDotsDisplay(
              filledCount: _pin.length,
              hasError: _hasError,
              isLoading: _isLoading,
            ),

            // Lockout timer or failed attempts
            if (isLockedOut) ...[
              const SizedBox(height: 24),
              _LockoutTimer(remaining: _remainingLockout!),
            ] else if (failedAttempts > 0) ...[
              const SizedBox(height: 16),
              Text(
                '${5 - failedAttempts} attempts remaining',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.warning,
                ),
              ),
            ],

            const Spacer(flex: 1),

            // PIN pad
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: PinPad(
                onDigit: _handleDigit,
                onBackspace: _handleBackspace,
                onClear: _pin.isNotEmpty ? _handleClear : null,
                isEnabled: !_isLoading && !isLockedOut,
              ),
            ),

            const Spacer(flex: 2),

            // Forgot PIN link
            TextButton.icon(
              onPressed: isLockedOut ? null : _showResetOptions,
              icon: const Icon(Icons.help_outline, size: 18),
              label: const Text('Forgot PIN?'),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  void _showResetOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.backgroundCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Reset Options',
                style: AppTypography.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'If you forgot your PIN, you can reset using your master password.',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 24),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.password_outlined,
                    color: AppColors.primary,
                  ),
                ),
                title: const Text('Unlock with Password'),
                subtitle: const Text('Use your master password'),
                onTap: () {
                  Navigator.pop(context);
                  _showPasswordDialog();
                },
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.delete_forever_outlined,
                    color: AppColors.error,
                  ),
                ),
                title: const Text('Reset Vault'),
                subtitle: const Text('Erase all local data'),
                onTap: () {
                  Navigator.pop(context);
                  _confirmReset();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPasswordDialog() {
    final controller = TextEditingController();
    bool obscure = true;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Enter Password'),
          content: TextField(
            controller: controller,
            obscureText: obscure,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'Master password',
              suffixIcon: IconButton(
                icon: Icon(
                  obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                ),
                onPressed: () => setState(() => obscure = !obscure),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                await _unlockWithPassword(controller.text);
              },
              child: const Text('Unlock'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _unlockWithPassword(String password) async {
    setState(() => _isLoading = true);

    try {
      await ref.read(authNotifierProvider.notifier).unlockWithPassword(password);

      final asyncState = ref.read(authNotifierProvider);
      final state = asyncState.valueOrNull;
      if (state is AuthStateError) {
        if (!mounted) return;
        await ErrorDialog.showSimple(
          context: context,
          title: 'Invalid Password',
          message: state.error.message,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _confirmReset() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Vault?'),
        content: const Text(
          'This will erase all local data including your encryption keys. '
          'Your encrypted files on GitHub will remain but become inaccessible '
          'without the original password.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await ref.read(authNotifierProvider.notifier).resetVault();
              // Router will redirect to setup
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

class _PinDotsDisplay extends StatelessWidget {
  const _PinDotsDisplay({
    required this.filledCount,
    required this.hasError,
    required this.isLoading,
  });

  final int filledCount;
  final bool hasError;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(6, (index) {
        final isFilled = index < filledCount;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 8),
          width: isFilled ? 20 : 16,
          height: isFilled ? 20 : 16,
          decoration: BoxDecoration(
            color: hasError
                ? AppColors.error
                : isFilled
                    ? AppColors.primary
                    : Colors.transparent,
            shape: BoxShape.circle,
            border: Border.all(
              color: hasError
                  ? AppColors.error
                  : isFilled
                      ? AppColors.primary
                      : AppColors.border,
              width: 2,
            ),
          ),
          child: isLoading && index == filledCount - 1
              ? const Padding(
                  padding: EdgeInsets.all(2),
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primary,
                  ),
                )
              : null,
        );
      }),
    );
  }
}

class _LockoutTimer extends StatelessWidget {
  const _LockoutTimer({required this.remaining});

  final Duration remaining;

  @override
  Widget build(BuildContext context) {
    final minutes = remaining.inMinutes;
    final seconds = remaining.inSeconds % 60;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.error.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.timer_outlined,
            color: AppColors.error,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            'Try again in $minutes:${seconds.toString().padLeft(2, '0')}',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.error,
            ),
          ),
        ],
      ),
    );
  }
}
