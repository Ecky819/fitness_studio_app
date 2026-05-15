import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/app_providers.dart';
import '../../core/api_service.dart';
import '../../core/services/biometric_service.dart';
import '../../design_system/design_system.dart';
import 'forgot_password_screen.dart';

// ── Role toggle ────────────────────────────────────────────────────────────────

enum _UserRole { member, operator }

// ── Root screen ────────────────────────────────────────────────────────────────

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  _UserRole _role = _UserRole.member;
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.xl,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Logo ────────────────────────────────────────────────────
                Center(
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusLg),
                    ),
                    child: const Icon(
                      Icons.fitness_center_rounded,
                      size: 36,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'NextGen Gym OS',
                  style: AppTextStyles.h1,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: AppSpacing.xl),

                // ── Role toggle ──────────────────────────────────────────────
                _RoleToggle(
                  selected: _role,
                  onChanged: (r) => setState(() {
                    _role = r;
                    // Operators only have Sign In — snap to that tab.
                    if (r == _UserRole.operator) {
                      _tabController.animateTo(0);
                    }
                  }),
                ),
                const SizedBox(height: AppSpacing.lg),

                // ── Tab bar (member mode only shows Register tab) ────────────
                if (_role == _UserRole.member) ...[
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius:
                          BorderRadius.circular(AppSpacing.radiusMd),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      indicatorSize: TabBarIndicatorSize.tab,
                      indicator: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.15),
                        borderRadius:
                            BorderRadius.circular(AppSpacing.radiusMd - 1),
                        border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.4)),
                      ),
                      labelColor: AppColors.primary,
                      unselectedLabelColor: AppColors.textSecondary,
                      labelStyle:
                          AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
                      unselectedLabelStyle: AppTextStyles.body,
                      dividerColor: Colors.transparent,
                      tabs: const [
                        Tab(text: 'Sign In'),
                        Tab(text: 'Create Account'),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  // AnimatedSwitcher lets the form size itself naturally —
                  // no hardcoded height needed; SingleChildScrollView above
                  // handles any content that exceeds the screen.
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: _tabController.index == 0
                        ? _SignInForm(
                            key: const ValueKey('signin'),
                            role: _role,
                          )
                        : const _RegisterForm(key: ValueKey('register')),
                  ),
                ] else ...[
                  // Operator — sign-in only
                  _SignInForm(role: _role),
                  const SizedBox(height: AppSpacing.xl),
                  _OperatorNote(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Role Toggle ────────────────────────────────────────────────────────────────

class _RoleToggle extends StatelessWidget {
  final _UserRole selected;
  final ValueChanged<_UserRole> onChanged;

  const _RoleToggle({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          _RoleOption(
            label: 'Gym Member',
            icon: Icons.fitness_center_rounded,
            isSelected: selected == _UserRole.member,
            onTap: () => onChanged(_UserRole.member),
          ),
          _RoleOption(
            label: 'Gym Operator',
            icon: Icons.admin_panel_settings_rounded,
            isSelected: selected == _UserRole.operator,
            onTap: () => onChanged(_UserRole.operator),
          ),
        ],
      ),
    );
  }
}

class _RoleOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _RoleOption({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.all(3),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd - 2),
            border: isSelected
                ? Border.all(color: AppColors.primary.withValues(alpha: 0.3))
                : null,
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    )
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected
                    ? AppColors.primary
                    : AppColors.textTertiary,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: AppTextStyles.body.copyWith(
                  fontSize: 13,
                  fontWeight:
                      isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected
                      ? AppColors.primary
                      : AppColors.textTertiary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Sign-In Form ───────────────────────────────────────────────────────────────

class _SignInForm extends ConsumerStatefulWidget {
  final _UserRole role;
  const _SignInForm({super.key, required this.role});

  @override
  ConsumerState<_SignInForm> createState() => _SignInFormState();
}

class _SignInFormState extends ConsumerState<_SignInForm> {
  final _formKey = GlobalKey<FormState>();
  final _gymCodeController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _biometricAvailable = false;
  bool _biometricEnabled = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _checkBiometrics();
  }

  @override
  void dispose() {
    _gymCodeController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _checkBiometrics() async {
    final available = await BiometricService.isAvailable();
    final enabled = await BiometricService.isEnabled();
    if (mounted) {
      setState(() {
        _biometricAvailable = available;
        _biometricEnabled = enabled;
      });
      if (enabled) _loginWithBiometrics();
    }
  }

  Future<void> _loginWithBiometrics() async {
    setState(() => _isLoading = true);
    try {
      final creds = await BiometricService.authenticate();
      if (creds == null) {
        setState(() => _isLoading = false);
        return;
      }
      await ApiService.login(creds.email, creds.password);
      if (mounted) {
        await ref.read(appControllerProvider.notifier).onLoginSuccess();
      }
    } on ApiException catch (_) {
      await BiometricService.disable();
      if (mounted) {
        setState(() {
          _biometricEnabled = false;
          _errorMessage = 'Biometric login failed. Please sign in manually.';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await ApiService.setTenantSlug(
          _gymCodeController.text.trim().toLowerCase());
      await ApiService.login(
        _emailController.text.trim(),
        _passwordController.text,
      );

      if (mounted && _biometricAvailable && !_biometricEnabled) {
        _offerBiometricSetup(
          _emailController.text.trim(),
          _passwordController.text,
        );
      }

      if (mounted) {
        await ref.read(appControllerProvider.notifier).onLoginSuccess();
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _errorMessage = e.isUnauthorized
            ? 'Invalid email or password.'
            : e.statusCode == 404
                ? 'Gym code not found. Check with your gym.'
                : 'Login failed. Please try again.');
      }
    } catch (_) {
      if (mounted) {
        setState(() =>
            _errorMessage = 'Cannot reach server. Check your connection.');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _InputLabel('Gym Code'),
          const SizedBox(height: 6),
          AppLightGlassContainer(
            child: TextFormField(
              controller: _gymCodeController,
              textInputAction: TextInputAction.next,
              autocorrect: false,
              style: AppTextStyles.body,
              decoration: _inputDecoration('e.g. iron-palace').copyWith(
                prefixIcon: const Icon(
                  Icons.storefront_rounded,
                  color: AppColors.textTertiary,
                  size: 18,
                ),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Ask your gym for their code';
                }
                return null;
              },
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          const _InputLabel('Email'),
          const SizedBox(height: 6),
          AppLightGlassContainer(
            child: TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autocorrect: false,
              style: AppTextStyles.body,
              decoration: _inputDecoration('you@example.com'),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Email is required';
                if (!v.contains('@') || !v.contains('.')) {
                  return 'Enter a valid email address';
                }
                return null;
              },
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          const _InputLabel('Password'),
          const SizedBox(height: 6),
          AppLightGlassContainer(
            child: TextFormField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
              style: AppTextStyles.body,
              decoration: _inputDecoration('••••••••').copyWith(
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: AppColors.textTertiary,
                    size: 20,
                  ),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Password is required';
                if (v.length < 8) return 'Minimum 8 characters';
                return null;
              },
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (_) => const ForgotPasswordScreen()),
              ),
              style: TextButton.styleFrom(padding: EdgeInsets.zero),
              child: Text(
                'Forgot password?',
                style:
                    AppTextStyles.caption.copyWith(color: AppColors.primary),
              ),
            ),
          ),
          if (_errorMessage != null) ...[
            _ErrorBanner(message: _errorMessage!),
            const SizedBox(height: AppSpacing.md),
          ],
          AppPrimaryButton(
            text: widget.role == _UserRole.operator
                ? 'Sign In to Admin Panel'
                : 'Sign In',
            isLoading: _isLoading,
            onPressed: _submit,
          ),
          if (_biometricAvailable && _biometricEnabled) ...[
            const SizedBox(height: AppSpacing.md),
            _OrDivider(),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton.icon(
              onPressed: _isLoading ? null : _loginWithBiometrics,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.border),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              icon: const Icon(Icons.fingerprint_rounded, size: 22),
              label: const Text('Sign in with Biometrics'),
            ),
          ],
        ],
      ),
    );
  }

  void _offerBiometricSetup(String email, String password) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text('Enable Biometric Login?', style: AppTextStyles.h4),
        content: Text(
          'Use Face ID or Touch ID to sign in faster next time.',
          style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Not now',
                style: AppTextStyles.body
                    .copyWith(color: AppColors.textTertiary)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await BiometricService.enable(email: email, password: password);
              if (mounted) setState(() => _biometricEnabled = true);
            },
            child: Text('Enable',
                style:
                    AppTextStyles.body.copyWith(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }
}

// ── Register Form ──────────────────────────────────────────────────────────────

class _RegisterForm extends ConsumerStatefulWidget {
  const _RegisterForm({super.key});

  @override
  ConsumerState<_RegisterForm> createState() => _RegisterFormState();
}

class _RegisterFormState extends ConsumerState<_RegisterForm> {
  final _formKey = GlobalKey<FormState>();
  final _gymCodeController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _gymCodeController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Connect to the specified gym before registering.
      await ApiService.setTenantSlug(_gymCodeController.text.trim().toLowerCase());
      await ApiService.register(
        _emailController.text.trim(),
        _passwordController.text,
      );

      if (mounted) {
        await ref.read(appControllerProvider.notifier).onLoginSuccess();
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _errorMessage = e.statusCode == 409
            ? 'An account with this email already exists.'
            : e.statusCode == 404
                ? 'Gym code not found. Check with your gym.'
                : 'Registration failed. Please try again.');
      }
    } catch (_) {
      if (mounted) {
        setState(() =>
            _errorMessage = 'Cannot reach server. Check your connection.');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _InputLabel('Gym Code'),
          const SizedBox(height: 6),
          AppLightGlassContainer(
            child: TextFormField(
              controller: _gymCodeController,
              textInputAction: TextInputAction.next,
              autocorrect: false,
              style: AppTextStyles.body,
              decoration: _inputDecoration('e.g. iron-palace').copyWith(
                prefixIcon: const Icon(
                  Icons.storefront_rounded,
                  color: AppColors.textTertiary,
                  size: 18,
                ),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Ask your gym for their code';
                }
                return null;
              },
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Your gym\'s unique identifier — ask reception or check their app.',
            style:
                AppTextStyles.caption.copyWith(color: AppColors.textTertiary),
          ),
          const SizedBox(height: AppSpacing.md),
          const _InputLabel('Email'),
          const SizedBox(height: 6),
          AppLightGlassContainer(
            child: TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autocorrect: false,
              style: AppTextStyles.body,
              decoration: _inputDecoration('you@example.com'),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Email is required';
                if (!v.contains('@') || !v.contains('.')) {
                  return 'Enter a valid email address';
                }
                return null;
              },
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          const _InputLabel('Password'),
          const SizedBox(height: 6),
          AppLightGlassContainer(
            child: TextFormField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.next,
              style: AppTextStyles.body,
              decoration: _inputDecoration('Min. 8 characters').copyWith(
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: AppColors.textTertiary,
                    size: 20,
                  ),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Password is required';
                if (v.length < 8) return 'Minimum 8 characters';
                return null;
              },
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          const _InputLabel('Confirm Password'),
          const SizedBox(height: 6),
          AppLightGlassContainer(
            child: TextFormField(
              controller: _confirmController,
              obscureText: true,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
              style: AppTextStyles.body,
              decoration: _inputDecoration('Repeat password'),
              validator: (v) {
                if (v != _passwordController.text) {
                  return 'Passwords do not match';
                }
                return null;
              },
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          if (_errorMessage != null) ...[
            _ErrorBanner(message: _errorMessage!),
            const SizedBox(height: AppSpacing.md),
          ],
          AppPrimaryButton(
            text: 'Create Account',
            isLoading: _isLoading,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }
}

// ── Operator note ──────────────────────────────────────────────────────────────

class _OperatorNote extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline_rounded,
              color: AppColors.primary, size: 18),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Need an operator account?',
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Gym accounts are created by the NextGen Gym OS team. Contact us or visit the web admin panel to get started.',
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.textSecondary, height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Shared small widgets ───────────────────────────────────────────────────────

class _InputLabel extends StatelessWidget {
  final String text;
  const _InputLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: AppTextStyles.body.copyWith(
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w500,
        ),
      );
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppColors.error, size: 18),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: AppTextStyles.body.copyWith(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }
}

class _OrDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: Divider(color: AppColors.border)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Text(
            'or',
            style: AppTextStyles.caption
                .copyWith(color: AppColors.textTertiary),
          ),
        ),
        const Expanded(child: Divider(color: AppColors.border)),
      ],
    );
  }
}

InputDecoration _inputDecoration(String hint) => InputDecoration(
      hintText: hint,
      hintStyle: AppTextStyles.body.copyWith(color: AppColors.textTertiary),
      border: InputBorder.none,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      errorStyle: AppTextStyles.caption.copyWith(color: AppColors.error),
    );
