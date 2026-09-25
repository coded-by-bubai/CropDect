import 'package:flutter/material.dart';
import '../theme.dart';
import 'package:dio/dio.dart';
import '../api_client.dart';
import '../widgets/translated_text.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  String _selectedRole = 'FARMER';
  bool _isLoading = false;
  String _errorMessage = '';

  Future<void> _signup() async {
    if (_passwordController.text != _confirmPasswordController.text) {
      setState(() {
        _errorMessage = 'Passwords do not match';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final response = await apiClient.post(
        '/auth/register',
        data: {
          'phone': _phoneController.text.trim(),
          'password': _passwordController.text,
          if (_nameController.text.trim().isNotEmpty) 'name': _nameController.text.trim(),
          'role': _selectedRole,
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: TranslatedText('Registration successful! Please login.')),
          );
          Navigator.pop(context);
        }
      }
    } on DioException catch (e) {
      setState(() {
        final detail = e.response?.data['detail'];
        if (detail is List && detail.isNotEmpty) {
          _errorMessage = detail[0]['msg'] ?? 'Validation error';
        } else if (detail is String) {
          _errorMessage = detail;
        } else {
          _errorMessage = 'Registration failed';
        }
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'An unexpected error occurred';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          color: AppTheme.background,
          // Organic pattern gradient
          gradient: RadialGradient(
            center: const Alignment(1.0, 1.0),
            radius: 1.5,
            colors: [
              const Color(0xFF81FF45).withValues(alpha: 0.05),
              Colors.transparent,
            ],
            stops: const [0.0, 0.5],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxWidth: 400),
                  padding: const EdgeInsets.all(32.0),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppTheme.surfaceVariant),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 32,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header
                      Center(
                        child: Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: AppTheme.primaryFixedDim, width: 2),
                            image: const DecorationImage(
                              image: AssetImage('assets/app_logo.jpg'),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      TranslatedText(
                        'Create Account',
                        style: Theme.of(context).textTheme.displayLarge?.copyWith(
                              color: AppTheme.primary,
                              fontSize: 28,
                            ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      TranslatedText(
                        'Join to monitor your fields.',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: AppTheme.onSurfaceVariant,
                            ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),

                      // Error message
                      if (_errorMessage.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: AppTheme.errorContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: TranslatedText(
                            _errorMessage,
                            style: TextStyle(color: AppTheme.onErrorContainer),
                            textAlign: TextAlign.center,
                          ),
                        ),

                      // Role Selector
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const TranslatedText(
                            'SELECT ACCOUNT ROLE',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                              color: AppTheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              _buildRoleCard(
                                role: 'FARMER',
                                title: 'Farmer',
                                icon: Icons.agriculture_rounded,
                              ),
                              const SizedBox(width: 8),
                              _buildRoleCard(
                                role: 'EXPERT',
                                title: 'Agronomist',
                                icon: Icons.biotech_rounded,
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      TextField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          labelText: 'Full Name / Title',
                          hintText: _selectedRole == 'EXPERT'
                              ? 'e.g. Dr. Rajesh Sharma'
                              : _selectedRole == 'ADMIN'
                                  ? 'e.g. System Admin'
                                  : 'e.g. Ramesh Kumar',
                          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),

                          prefixIcon: const Icon(Icons.person_outline_rounded, color: AppTheme.outline),
                          filled: true,
                          fillColor: AppTheme.surface,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AppTheme.surfaceVariant, width: 2),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AppTheme.surfaceVariant, width: 2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      TextField(
                        controller: _phoneController,
                        decoration: InputDecoration(
                          labelText: 'Phone Number',
                          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                          prefixIcon: const Icon(Icons.phone, color: AppTheme.outline),
                          filled: true,
                          fillColor: AppTheme.surface,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AppTheme.surfaceVariant, width: 2),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AppTheme.surfaceVariant, width: 2),
                          ),
                        ),
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 16),
                      
                      TextField(
                        controller: _passwordController,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: 'Password',
                          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                          prefixIcon: const Icon(Icons.lock, color: AppTheme.outline),
                          filled: true,
                          fillColor: AppTheme.surface,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AppTheme.surfaceVariant, width: 2),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AppTheme.surfaceVariant, width: 2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      TextField(
                        controller: _confirmPasswordController,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: 'Confirm Password',
                          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                          prefixIcon: const Icon(Icons.lock, color: AppTheme.outline),
                          filled: true,
                          fillColor: AppTheme.surface,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AppTheme.surfaceVariant, width: 2),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AppTheme.surfaceVariant, width: 2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Sign Up Button
                      SizedBox(
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _signup,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.secondaryContainer,
                            foregroundColor: AppTheme.onSecondaryContainer,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 1,
                          ),
                          child: _isLoading
                              ? const CircularProgressIndicator(color: AppTheme.onSecondaryContainer)
                              : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    TranslatedText(
                                      'Sign Up',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    SizedBox(width: 8),
                                    Icon(Icons.person_add),
                                  ],
                                ),
                        ),
                      ),
                      
                      const SizedBox(height: 32),
                      
                      // Sign In Link
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const TranslatedText(
                            "Already have an account? ",
                            style: TextStyle(color: AppTheme.onSurfaceVariant),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.pop(context);
                            },
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const TranslatedText(
                              'Sign In',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppTheme.primary,
                                decoration: TextDecoration.underline,
                                decorationColor: AppTheme.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoleCard({
    required String role,
    required String title,
    required IconData icon,
  }) {
    final isSelected = _selectedRole == role;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() => _selectedRole = role);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.secondaryContainer : AppTheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? AppTheme.secondary : AppTheme.surfaceVariant,
              width: isSelected ? 2 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppTheme.secondary.withValues(alpha: 0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: isSelected ? AppTheme.primary : AppTheme.onSurfaceVariant,
                size: 24,
              ),
              const SizedBox(height: 6),
              TranslatedText(
                title,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  color: isSelected ? AppTheme.primary : AppTheme.onSurface,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
