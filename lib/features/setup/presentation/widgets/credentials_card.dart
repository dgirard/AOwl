import 'package:flutter/material.dart';

import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/theme/app_typography.dart';
import 'pin_input.dart';

/// Card for setting up security credentials (password and PIN).
class CredentialsCard extends StatefulWidget {
  const CredentialsCard({
    super.key,
    required this.onCredentialsChanged,
  });

  final void Function(String password, String pin, bool isValid)
      onCredentialsChanged;

  @override
  State<CredentialsCard> createState() => _CredentialsCardState();
}

class _CredentialsCardState extends State<CredentialsCard> {
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  String _pin = '';
  String _confirmPin = '';
  bool _showPinConfirm = false;

  final _pinInputKey = GlobalKey<PinInputState>();
  final _confirmPinInputKey = GlobalKey<PinInputState>();

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _notifyChange() {
    final password = _passwordController.text;
    final confirm = _confirmController.text;

    final isPasswordValid =
        password.length >= 12 && password == confirm && confirm.isNotEmpty;
    final isPinValid =
        _pin.length == 6 && _confirmPin.length == 6 && _pin == _confirmPin;

    widget.onCredentialsChanged(
      password,
      _pin,
      isPasswordValid && isPinValid,
    );
  }

  String? _getPasswordError() {
    final password = _passwordController.text;
    if (password.isEmpty) return null;
    if (password.length < 12) {
      return 'Password must be at least 12 characters';
    }
    return null;
  }

  String? _getConfirmError() {
    final password = _passwordController.text;
    final confirm = _confirmController.text;
    if (confirm.isEmpty) return null;
    if (confirm != password) {
      return 'Passwords do not match';
    }
    return null;
  }

  _PasswordStrength _getPasswordStrength() {
    final password = _passwordController.text;
    if (password.isEmpty) return _PasswordStrength.none;
    if (password.length < 8) return _PasswordStrength.weak;
    if (password.length < 12) return _PasswordStrength.fair;

    var score = 0;
    if (password.contains(RegExp(r'[a-z]'))) score++;
    if (password.contains(RegExp(r'[A-Z]'))) score++;
    if (password.contains(RegExp(r'[0-9]'))) score++;
    if (password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) score++;

    if (score >= 4 && password.length >= 16) return _PasswordStrength.strong;
    if (score >= 3) return _PasswordStrength.good;
    return _PasswordStrength.fair;
  }

  void _onPinEntered(String pin) {
    _pin = pin;
    if (!_showPinConfirm) {
      setState(() => _showPinConfirm = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _confirmPinInputKey.currentState?.focus();
      });
    }
    _notifyChange();
  }

  void _onConfirmPinEntered(String pin) {
    _confirmPin = pin;
    _notifyChange();
  }

  @override
  Widget build(BuildContext context) {
    final strength = _getPasswordStrength();

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
                    color: AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.lock_outline,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Security Credentials',
                  style: AppTypography.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Create a strong password and quick unlock PIN.',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 20),

            // Password section
            Text(
              'Master Password',
              style: AppTypography.labelLarge,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _passwordController,
              onChanged: (_) {
                setState(() {});
                _notifyChange();
              },
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                hintText: 'Enter a strong password',
                prefixIcon: const Icon(Icons.password_outlined),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                  onPressed: () {
                    setState(() => _obscurePassword = !_obscurePassword);
                  },
                ),
                errorText: _getPasswordError(),
              ),
              textInputAction: TextInputAction.next,
            ),
            if (strength != _PasswordStrength.none) ...[
              const SizedBox(height: 8),
              _PasswordStrengthIndicator(strength: strength),
            ],
            const SizedBox(height: 16),

            // Confirm password
            TextField(
              controller: _confirmController,
              onChanged: (_) {
                setState(() {});
                _notifyChange();
              },
              obscureText: _obscureConfirm,
              decoration: InputDecoration(
                hintText: 'Confirm password',
                prefixIcon: const Icon(Icons.password_outlined),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureConfirm
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                  onPressed: () {
                    setState(() => _obscureConfirm = !_obscureConfirm);
                  },
                ),
                errorText: _getConfirmError(),
              ),
              textInputAction: TextInputAction.done,
            ),
            const SizedBox(height: 24),

            // Divider
            const Divider(),
            const SizedBox(height: 24),

            // PIN section
            Text(
              'Quick Unlock PIN',
              style: AppTypography.labelLarge,
            ),
            const SizedBox(height: 4),
            Text(
              '6-digit PIN for quick access',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),

            // PIN input
            Center(
              child: PinInput(
                key: _pinInputKey,
                onCompleted: _onPinEntered,
                onChanged: (pin) {
                  _pin = pin;
                  _notifyChange();
                },
              ),
            ),

            if (_showPinConfirm) ...[
              const SizedBox(height: 24),
              Text(
                'Confirm PIN',
                style: AppTypography.labelLarge,
              ),
              const SizedBox(height: 16),
              Center(
                child: PinInput(
                  key: _confirmPinInputKey,
                  onCompleted: _onConfirmPinEntered,
                  onChanged: (pin) {
                    _confirmPin = pin;
                    _notifyChange();
                  },
                  isError: _confirmPin.length == 6 && _confirmPin != _pin,
                  errorText: _confirmPin.length == 6 && _confirmPin != _pin
                      ? 'PINs do not match'
                      : null,
                ),
              ),
            ],

            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppColors.warning.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    color: AppColors.warning,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Your password cannot be recovered. Store it safely.',
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.warning,
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

enum _PasswordStrength { none, weak, fair, good, strong }

class _PasswordStrengthIndicator extends StatelessWidget {
  const _PasswordStrengthIndicator({required this.strength});

  final _PasswordStrength strength;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Row(
            children: List.generate(4, (index) {
              final isActive = index < _getActiveSegments();
              return Expanded(
                child: Container(
                  height: 4,
                  margin: EdgeInsets.only(right: index < 3 ? 4 : 0),
                  decoration: BoxDecoration(
                    color: isActive ? _getColor() : AppColors.backgroundInput,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              );
            }),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          _getLabel(),
          style: AppTypography.labelSmall.copyWith(
            color: _getColor(),
          ),
        ),
      ],
    );
  }

  int _getActiveSegments() {
    return switch (strength) {
      _PasswordStrength.none => 0,
      _PasswordStrength.weak => 1,
      _PasswordStrength.fair => 2,
      _PasswordStrength.good => 3,
      _PasswordStrength.strong => 4,
    };
  }

  Color _getColor() {
    return switch (strength) {
      _PasswordStrength.none => AppColors.textDisabled,
      _PasswordStrength.weak => AppColors.error,
      _PasswordStrength.fair => AppColors.warning,
      _PasswordStrength.good => AppColors.info,
      _PasswordStrength.strong => AppColors.success,
    };
  }

  String _getLabel() {
    return switch (strength) {
      _PasswordStrength.none => '',
      _PasswordStrength.weak => 'Weak',
      _PasswordStrength.fair => 'Fair',
      _PasswordStrength.good => 'Good',
      _PasswordStrength.strong => 'Strong',
    };
  }
}
