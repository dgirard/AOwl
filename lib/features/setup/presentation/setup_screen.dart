import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/theme/app_colors.dart';
import '../../../shared/theme/app_typography.dart';
import '../../../shared/widgets/error_dialog.dart';
import '../../../shared/widgets/loading_overlay.dart';
import '../../unlock/providers/auth_provider.dart';
import '../../unlock/providers/auth_state.dart';
import 'widgets/credentials_card.dart';
import 'widgets/repo_config_card.dart';

/// Initial setup screen for configuring the vault.
class SetupScreen extends ConsumerStatefulWidget {
  const SetupScreen({super.key});

  @override
  ConsumerState<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends ConsumerState<SetupScreen> {
  String _owner = '';
  String _repo = '';
  String _token = '';
  String _password = '';
  String _pin = '';
  bool _credentialsValid = false;
  bool _isLoading = false;

  bool get _canSubmit =>
      _owner.isNotEmpty &&
      _repo.isNotEmpty &&
      _token.isNotEmpty &&
      _credentialsValid;

  Future<void> _handleSetup() async {
    if (!_canSubmit) return;

    setState(() => _isLoading = true);

    try {
      await ref.read(authNotifierProvider.notifier).setupVault(
            password: _password,
            pin: _pin,
            repoOwner: _owner,
            repoName: _repo,
            githubToken: _token,
          );

      // Check the resulting state
      final asyncState = ref.read(authNotifierProvider);
      final authState = asyncState.valueOrNull;
      if (authState is AuthStateError) {
        if (!mounted) return;
        await ErrorDialog.showSimple(
          context: context,
          title: 'Setup Failed',
          message: authState.error.message,
        );
      }
      // If successful, the router will handle navigation
    } catch (e) {
      if (!mounted) return;
      await ErrorDialog.showSimple(
        context: context,
        title: 'Setup Error',
        message: 'An unexpected error occurred during setup.',
        details: e.toString(),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return LoadingWrapper(
      isLoading: _isLoading,
      message: 'Setting up your vault...',
      child: Scaffold(
        body: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 32),
                      // Header
                      Center(
                        child: Column(
                          children: [
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
                              'Welcome to AShare',
                              style: AppTypography.headlineMedium,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Secure cross-platform sharing',
                              style: AppTypography.bodyMedium.copyWith(
                                color: AppColors.textSecondary,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 40),

                      // Step indicator
                      _StepIndicator(
                        currentStep: _owner.isEmpty ? 0 : (_credentialsValid ? 2 : 1),
                      ),
                      const SizedBox(height: 24),

                      // Repository configuration
                      RepoConfigCard(
                        onConfigChanged: (owner, repo, token) {
                          setState(() {
                            _owner = owner;
                            _repo = repo;
                            _token = token;
                          });
                        },
                      ),
                      const SizedBox(height: 16),

                      // Credentials configuration
                      CredentialsCard(
                        onCredentialsChanged: (password, pin, isValid) {
                          setState(() {
                            _password = password;
                            _pin = pin;
                            _credentialsValid = isValid;
                          });
                        },
                      ),
                      const SizedBox(height: 32),

                      // Submit button
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _canSubmit ? _handleSetup : null,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.check_circle_outline),
                              const SizedBox(width: 8),
                              Text(
                                'Complete Setup',
                                style: AppTypography.button.copyWith(
                                  color: _canSubmit
                                      ? AppColors.background
                                      : AppColors.textDisabled,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Privacy note
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            'Your data is encrypted locally before being uploaded. '
                            'We never see your passwords or content.',
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.textTertiary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.currentStep});

  final int currentStep;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _StepDot(index: 0, currentStep: currentStep, label: 'Repository'),
        Expanded(child: _StepLine(isActive: currentStep >= 1)),
        _StepDot(index: 1, currentStep: currentStep, label: 'Credentials'),
        Expanded(child: _StepLine(isActive: currentStep >= 2)),
        _StepDot(index: 2, currentStep: currentStep, label: 'Complete'),
      ],
    );
  }
}

class _StepDot extends StatelessWidget {
  const _StepDot({
    required this.index,
    required this.currentStep,
    required this.label,
  });

  final int index;
  final int currentStep;
  final String label;

  @override
  Widget build(BuildContext context) {
    final isActive = currentStep >= index;
    final isCurrent = currentStep == index;

    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: isCurrent ? 32 : 24,
          height: isCurrent ? 32 : 24,
          decoration: BoxDecoration(
            color: isActive ? AppColors.primary : AppColors.backgroundInput,
            shape: BoxShape.circle,
            border: Border.all(
              color: isActive ? AppColors.primary : AppColors.border,
              width: 2,
            ),
          ),
          child: Center(
            child: isActive && !isCurrent
                ? const Icon(
                    Icons.check,
                    size: 14,
                    color: AppColors.background,
                  )
                : Text(
                    '${index + 1}',
                    style: AppTypography.labelSmall.copyWith(
                      color:
                          isActive ? AppColors.background : AppColors.textTertiary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: AppTypography.labelSmall.copyWith(
            color: isActive ? AppColors.textPrimary : AppColors.textTertiary,
          ),
        ),
      ],
    );
  }
}

class _StepLine extends StatelessWidget {
  const _StepLine({required this.isActive});

  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 2,
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: isActive ? AppColors.primary : AppColors.borderSubtle,
        borderRadius: BorderRadius.circular(1),
      ),
    );
  }
}
