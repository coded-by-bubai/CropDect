import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../theme.dart';
import '../api_client.dart';
import 'login_screen.dart';
import '../widgets/translated_text.dart';

class AdminSetupScreen extends StatefulWidget {
  const AdminSetupScreen({super.key});

  @override
  State<AdminSetupScreen> createState() => _AdminSetupScreenState();
}

class _AdminSetupScreenState extends State<AdminSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _secretController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _obscureSecret = true;
  String _errorMessage = '';
  String _successMessage = '';

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _secretController.dispose();
    super.dispose();
  }

  Future<void> _registerAdmin() async {
    if (!_formKey.currentState!.validate()) return;
    if (_passwordController.text != _confirmPasswordController.text) {
      setState(() => _errorMessage = 'Passwords do not match.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
      _successMessage = '';
    });

    try {
      await apiClient.post(
        '/auth/register-admin',
        data: {
          'phone': _phoneController.text.trim(),
          'password': _passwordController.text,
          if (_nameController.text.trim().isNotEmpty)
            'name': _nameController.text.trim(),
          if (_emailController.text.trim().isNotEmpty)
            'email': _emailController.text.trim(),
          'admin_secret': _secretController.text,
        },
      );

      if (mounted) {
        setState(() =>
            _successMessage = 'Admin account created! Please log in.');
        // Clear fields
        _nameController.clear();
        _phoneController.clear();
        _emailController.clear();
        _passwordController.clear();
        _confirmPasswordController.clear();
        _secretController.clear();

        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const LoginScreen()),
            );
          }
        });
      }
    } on DioException catch (e) {
      setState(() {
        _errorMessage =
            e.response?.data['detail'] ?? 'Registration failed. Check your admin secret key.';
      });
    } catch (_) {
      setState(() => _errorMessage = 'An unexpected error occurred.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: AppTheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: const TranslatedText(
          'Admin Setup',
          style: TextStyle(
            color: AppTheme.onSurface,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 440),
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: AppTheme.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFF1B381A).withValues(alpha: 0.3)),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1B381A).withValues(alpha: 0.08),
                    blurRadius: 32,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1B381A),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.admin_panel_settings_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const TranslatedText(
                      'Create Admin Account',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1B381A),
                      ),
                    ),
                    const SizedBox(height: 6),
                    const TranslatedText(
                      'Requires the system admin secret key.\nContact your system administrator if you don\'t have it.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.onSurfaceVariant,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Error / Success banners
                    if (_errorMessage.isNotEmpty)
                      _buildBanner(_errorMessage, isError: true),
                    if (_successMessage.isNotEmpty)
                      _buildBanner(_successMessage, isError: false),

                    // Admin Secret Key (first — makes intent clear)
                    _buildField(
                      controller: _secretController,
                      label: 'Admin Secret Key *',
                      icon: Icons.key_rounded,
                      obscure: _obscureSecret,
                      toggleObscure: () =>
                          setState(() => _obscureSecret = !_obscureSecret),
                      validator: (v) =>
                          (v == null || v.isEmpty) ? 'Secret key is required' : null,
                    ),
                    const SizedBox(height: 16),

                    const Divider(height: 1),
                    const SizedBox(height: 16),

                    // Name
                    _buildField(
                      controller: _nameController,
                      label: 'Full Name',
                      icon: Icons.badge_rounded,
                      hint: 'e.g. System Admin',
                    ),
                    const SizedBox(height: 14),

                    // Phone
                    _buildField(
                      controller: _phoneController,
                      label: 'Phone Number *',
                      icon: Icons.phone_rounded,
                      keyboardType: TextInputType.phone,
                      validator: (v) =>
                          (v == null || v.isEmpty) ? 'Phone is required' : null,
                    ),
                    const SizedBox(height: 14),

                    // Email (optional)
                    _buildField(
                      controller: _emailController,
                      label: 'Email (optional)',
                      icon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 14),

                    // Password
                    _buildField(
                      controller: _passwordController,
                      label: 'Password *',
                      icon: Icons.lock_outline_rounded,
                      obscure: _obscurePassword,
                      toggleObscure: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                      validator: (v) => (v == null || v.length < 6)
                          ? 'Password must be at least 6 characters'
                          : null,
                    ),
                    const SizedBox(height: 14),

                    // Confirm Password
                    _buildField(
                      controller: _confirmPasswordController,
                      label: 'Confirm Password *',
                      icon: Icons.lock_rounded,
                      obscure: _obscureConfirm,
                      toggleObscure: () =>
                          setState(() => _obscureConfirm = !_obscureConfirm),
                      validator: (v) =>
                          (v == null || v.isEmpty) ? 'Please confirm your password' : null,
                    ),
                    const SizedBox(height: 24),

                    // Submit button
                    SizedBox(
                      height: 54,
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _registerAdmin,
                        icon: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.verified_user_rounded,
                                color: Colors.white),
                        label: TranslatedText(
                          _isLoading ? 'Creating Account…' : 'Create Admin Account',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1B381A),
                          disabledBackgroundColor:
                              const Color(0xFF1B381A).withValues(alpha: 0.5),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 2,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const TranslatedText(
                        'Back to Login',
                        style: TextStyle(color: AppTheme.primary),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBanner(String msg, {required bool isError}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isError ? AppTheme.errorContainer : const Color(0xFFE8F5E9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isError
              ? AppTheme.error.withValues(alpha: 0.4)
              : const Color(0xFF276C00).withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
            color: isError ? AppTheme.error : const Color(0xFF276C00),
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TranslatedText(
              msg,
              style: TextStyle(
                color: isError ? AppTheme.onErrorContainer : const Color(0xFF1B4332),
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    bool obscure = false,
    VoidCallback? toggleObscure,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        prefixIcon: Icon(icon, color: AppTheme.outline, size: 20),
        suffixIcon: toggleObscure != null
            ? IconButton(
                icon: Icon(
                  obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  color: AppTheme.outline,
                  size: 20,
                ),
                onPressed: toggleObscure,
              )
            : null,
        filled: true,
        fillColor: AppTheme.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.surfaceVariant, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.surfaceVariant, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF1B381A), width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppTheme.error, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }
}
