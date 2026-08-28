import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';
import '../widgets/app_logo.dart';
import '../widgets/soft_button.dart';
import '../widgets/soft_surface.dart';
import '../widgets/soft_text_field.dart';

class AccountUpgradeScreen extends StatefulWidget {
  const AccountUpgradeScreen({super.key});

  @override
  State<AccountUpgradeScreen> createState() => _AccountUpgradeScreenState();
}

class _AccountUpgradeScreenState extends State<AccountUpgradeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final AuthService _authService = AuthService();

  bool _isPasswordVisible = false;
  bool _isEmailLoading = false;
  bool _isGoogleLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleEmailUpgrade() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isEmailLoading = true);

    try {
      await _authService.linkAnonymousWithEmail(
        email: _emailController.text,
        password: _passwordController.text,
        displayName: _nameController.text,
      );
      if (!mounted) return;
      Navigator.popUntil(context, (route) => route.isFirst);
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackBar(e.toString());
    } finally {
      if (mounted) setState(() => _isEmailLoading = false);
    }
  }

  Future<void> _handleGoogleUpgrade() async {
    setState(() => _isGoogleLoading = true);

    try {
      final credential = await _authService.linkAnonymousWithGoogle();
      if (credential != null && mounted) {
        Navigator.popUntil(context, (route) => route.isFirst);
      }
    } catch (e) {
      if (!mounted) return;
      _showErrorSnackBar(e.toString());
    } finally {
      if (mounted) setState(() => _isGoogleLoading = false);
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message.replaceFirst('Exception: ', '')),
        backgroundColor: AppColors.danger,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isBusy = _isEmailLoading || _isGoogleLoading;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: isDark ? AppColors.darkCanvas : AppColors.canvas,
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const AppLogo(size: 64),
                  const SizedBox(height: 20),
                  Text(
                    'Secure Your Account',
                    style: AppTypography.displayLarge.copyWith(
                      color: isDark ? AppColors.darkTextPrimary : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'MediTrack requires an account. Create credentials for your profile to keep your medicines, reminders, and prescriptions securely synced.',
                    style: AppTypography.bodyMedium.copyWith(
                      color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 28),

                  SoftTextField(
                    controller: _nameController,
                    labelText: 'Full Name',
                    hintText: 'e.g. John Doe',
                    textCapitalization: TextCapitalization.words,
                    prefixIcon: const Icon(Icons.person_outline, color: AppColors.primaryBlue, size: 20),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Please enter your full name'
                        : null,
                  ),
                  const SizedBox(height: 16),

                  SoftTextField(
                    controller: _emailController,
                    labelText: 'Email Address',
                    hintText: 'name@example.com',
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    prefixIcon: const Icon(Icons.email_outlined, color: AppColors.primaryBlue, size: 20),
                    validator: (value) {
                      final email = value?.trim() ?? '';
                      if (email.isEmpty) {
                        return 'Please enter your email address';
                      }
                      if (!RegExp(r'^[\w-.]+@([\w-]+\.)+[\w-]{2,}$').hasMatch(email)) {
                        return 'Please enter a valid email address';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  SoftTextField(
                    controller: _passwordController,
                    labelText: 'Password',
                    hintText: 'At least 6 characters',
                    obscureText: !_isPasswordVisible,
                    autofillHints: const [AutofillHints.newPassword],
                    prefixIcon: const Icon(Icons.lock_outline, color: AppColors.primaryBlue, size: 20),
                    suffixIcon: IconButton(
                      tooltip: _isPasswordVisible ? 'Hide password' : 'Show password',
                      onPressed: () => setState(
                        () => _isPasswordVisible = !_isPasswordVisible,
                      ),
                      icon: Icon(
                        _isPasswordVisible
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                        size: 20,
                      ),
                    ),
                    validator: (value) => value == null || value.length < 6
                        ? 'Password must be at least 6 characters long'
                        : null,
                  ),
                  const SizedBox(height: 24),

                  SoftPrimaryButton(
                    label: 'Create Account and Keep Data',
                    isLoading: _isEmailLoading,
                    onPressed: isBusy ? null : _handleEmailUpgrade,
                  ),
                  const SizedBox(height: 20),

                  Row(
                    children: [
                      Expanded(
                        child: Divider(color: isDark ? AppColors.darkDivider : AppColors.divider),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text('OR', style: AppTypography.caption),
                      ),
                      Expanded(
                        child: Divider(color: isDark ? AppColors.darkDivider : AppColors.divider),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  SoftSecondaryButton(
                    label: 'Link Google Account',
                    icon: Icons.g_mobiledata_rounded,
                    onPressed: isBusy ? null : _handleGoogleUpgrade,
                  ),
                  const SizedBox(height: 18),

                  SoftSurface(
                    padding: const EdgeInsets.all(12),
                    color: isDark ? AppColors.darkSurface : AppColors.surface,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.info_outline, color: AppColors.primaryBlue, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Your existing medication data and prescriptions will remain safely attached to your new profile.',
                            style: AppTypography.bodySmall.copyWith(
                              fontSize: 11.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
