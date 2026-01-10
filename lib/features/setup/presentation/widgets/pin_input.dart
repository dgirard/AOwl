import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../shared/theme/app_colors.dart';
import '../../../../shared/theme/app_typography.dart';

/// A 6-digit PIN input with individual digit boxes.
class PinInput extends StatefulWidget {
  const PinInput({
    super.key,
    required this.onCompleted,
    this.onChanged,
    this.isEnabled = true,
    this.isError = false,
    this.errorText,
    this.autoFocus = false,
  });

  /// Called when all 6 digits have been entered.
  final ValueChanged<String> onCompleted;

  /// Called whenever the PIN value changes.
  final ValueChanged<String>? onChanged;

  /// Whether input is enabled.
  final bool isEnabled;

  /// Whether to show error state.
  final bool isError;

  /// Error message to display below the input.
  final String? errorText;

  /// Whether to auto-focus the first input on mount.
  final bool autoFocus;

  @override
  State<PinInput> createState() => PinInputState();
}

class PinInputState extends State<PinInput> {
  static const int _pinLength = 6;
  final List<TextEditingController> _controllers = [];
  final List<FocusNode> _focusNodes = [];

  String get pin => _controllers.map((c) => c.text).join();

  @override
  void initState() {
    super.initState();
    for (var i = 0; i < _pinLength; i++) {
      _controllers.add(TextEditingController());
      _focusNodes.add(FocusNode());
    }

    if (widget.autoFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _focusNodes[0].requestFocus();
      });
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    for (final node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  /// Clear all inputs and focus the first one.
  void clear() {
    for (final controller in _controllers) {
      controller.clear();
    }
    _focusNodes[0].requestFocus();
  }

  /// Focus the first input.
  void focus() {
    _focusNodes[0].requestFocus();
  }

  void _onChanged(int index, String value) {
    // Handle paste of full PIN
    if (value.length > 1) {
      final digits = value.replaceAll(RegExp(r'\D'), '');
      _handlePaste(digits);
      return;
    }

    // Notify parent of change
    widget.onChanged?.call(pin);

    // Auto-advance to next field
    if (value.isNotEmpty && index < _pinLength - 1) {
      _focusNodes[index + 1].requestFocus();
    }

    // Check if complete
    if (pin.length == _pinLength) {
      widget.onCompleted(pin);
    }
  }

  void _handlePaste(String digits) {
    for (var i = 0; i < _pinLength && i < digits.length; i++) {
      _controllers[i].text = digits[i];
    }
    widget.onChanged?.call(pin);

    if (pin.length == _pinLength) {
      widget.onCompleted(pin);
    } else {
      // Focus the next empty field
      final nextEmpty = _controllers.indexWhere((c) => c.text.isEmpty);
      if (nextEmpty != -1) {
        _focusNodes[nextEmpty].requestFocus();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: List.generate(_pinLength, (index) {
            return Padding(
              padding: EdgeInsets.only(
                left: index == 0 ? 0 : 4,
                right: index == _pinLength - 1 ? 0 : 4,
              ),
              child: _PinDigitBox(
                controller: _controllers[index],
                focusNode: _focusNodes[index],
                isEnabled: widget.isEnabled,
                isError: widget.isError,
                isFilled: _controllers[index].text.isNotEmpty,
                onChanged: (value) => _onChanged(index, value),
              ),
            );
          }),
        ),
        if (widget.errorText != null) ...[
          const SizedBox(height: 12),
          Text(
            widget.errorText!,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.error,
            ),
          ),
        ],
      ],
    );
  }
}

class _PinDigitBox extends StatelessWidget {
  const _PinDigitBox({
    required this.controller,
    required this.focusNode,
    required this.isEnabled,
    required this.isError,
    required this.isFilled,
    required this.onChanged,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isEnabled;
  final bool isError;
  final bool isFilled;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 40,
      height: 48,
      decoration: BoxDecoration(
        color: isEnabled ? AppColors.backgroundInput : AppColors.backgroundCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isError
              ? AppColors.error
              : focusNode.hasFocus
                  ? AppColors.primary
                  : isFilled
                      ? AppColors.primary.withValues(alpha: 0.5)
                      : AppColors.borderSubtle,
          width: focusNode.hasFocus || isError ? 2 : 1,
        ),
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        enabled: isEnabled,
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        maxLength: 1,
        obscureText: true,
        obscuringCharacter: '\u2022', // Bullet character
        style: AppTypography.pinDigit,
        decoration: const InputDecoration(
          counterText: '',
          border: InputBorder.none,
          contentPadding: EdgeInsets.zero,
        ),
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
        ],
        onChanged: onChanged,
      ),
    );
  }
}

/// A numeric PIN pad for entering digits.
class PinPad extends StatelessWidget {
  const PinPad({
    super.key,
    required this.onDigit,
    required this.onBackspace,
    this.onClear,
    this.isEnabled = true,
  });

  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final VoidCallback? onClear;
  final bool isEnabled;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildRow(['1', '2', '3']),
        const SizedBox(height: 16),
        _buildRow(['4', '5', '6']),
        const SizedBox(height: 16),
        _buildRow(['7', '8', '9']),
        const SizedBox(height: 16),
        _buildRow([
          onClear != null ? 'C' : '',
          '0',
          '\u232B', // Backspace symbol
        ]),
      ],
    );
  }

  Widget _buildRow(List<String> keys) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: keys.map((key) {
        if (key.isEmpty) {
          return const SizedBox(width: 80);
        }
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: _PinPadKey(
            label: key,
            isEnabled: isEnabled,
            onPressed: () {
              if (key == '\u232B') {
                onBackspace();
              } else if (key == 'C') {
                onClear?.call();
              } else {
                onDigit(key);
              }
            },
          ),
        );
      }).toList(),
    );
  }
}

class _PinPadKey extends StatelessWidget {
  const _PinPadKey({
    required this.label,
    required this.isEnabled,
    required this.onPressed,
  });

  final String label;
  final bool isEnabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final isSpecial = label == '\u232B' || label == 'C';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isEnabled ? onPressed : null,
        borderRadius: BorderRadius.circular(40),
        child: Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: isSpecial
                ? AppColors.backgroundInput
                : AppColors.backgroundCard,
            shape: BoxShape.circle,
            border: Border.all(
              color: AppColors.borderSubtle,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: isSpecial
                  ? AppTypography.titleLarge.copyWith(
                      color: isEnabled
                          ? AppColors.textSecondary
                          : AppColors.textDisabled,
                    )
                  : AppTypography.headlineMedium.copyWith(
                      color: isEnabled
                          ? AppColors.textPrimary
                          : AppColors.textDisabled,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
