import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../theme.dart';
import '../api_client.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'signup_screen.dart';
import 'dashboard_screen.dart';
import 'expert_home_screen.dart';
import 'admin_dashboard_screen.dart';
import 'admin_setup_screen.dart';
import 'package:provider/provider.dart';
import '../api_client.dart';
import '../main.dart';
import '../widgets/translated_text.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String _errorMessage = '';
  String _loginRole = 'FARMER';
  int _logoTapCount = 0; // Hidden 5-tap to open Admin Setup

  Future<void> _login() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final response = await apiClient.post(
        '/auth/login',
        data: FormData.fromMap({
          'username': _phoneController.text.trim(), // OAuth2 expects 'username' (backend maps to phone)
          'password': _passwordController.text,
        }),
      );

      if (response.statusCode == 200) {
        final token = response.data['access_token'];
        if (token == null) {
          setState(() => _errorMessage = 'Login failed: no token received.');
          return;
        }

        // Save token immediately to prefs AND inject into Dio header
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', token);
        apiClient.options.headers['Authorization'] = 'Bearer $token';

        // Fetch actual role from server (now token is definitely attached)
        String? userRole;
        try {
          final userRes = await apiClient.get('/users/me');
          if (userRes.data is Map<String, dynamic>) {
            userRole = userRes.data['role'];
          }
        } catch (_) {}

        final resolvedRole = userRole ?? _loginRole;
        await prefs.setString('user_role', resolvedRole);

        if (mounted) {
          // Notify auth state with role
          Provider.of<AuthState>(context, listen: false).login(token, resolvedRole);

          // Register FCM token with backend for production push notifications
          FirebaseMessaging.instance.getToken().then((fcmToken) {
            if (fcmToken != null) {
              apiClient.post('/users/me/fcm-token', data: {'token': fcmToken})
                  .catchError((_) {}); // Fire-and-forget, don't block navigation
            }
          });

          if (resolvedRole == 'ADMIN') {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const AdminDashboardScreen()),
            );
          } else if (resolvedRole == 'EXPERT' || resolvedRole == 'EXTENSION_WORKER') {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const ExpertHomeScreen()),
            );
          } else {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const DashboardScreen()),
            );
          }
        }
      }
    } on DioException catch (e) {
      setState(() {
        final detail = e.response?.data['detail'];
        if (detail is List && detail.isNotEmpty) {
          _errorMessage = detail[0]['msg'] ?? 'Login failed';
        } else if (detail is String) {
          _errorMessage = detail;
        } else {
          _errorMessage = 'Login failed. Please check credentials.';
        }
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'An unexpected error occurred.';
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
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 420),
              padding: const EdgeInsets.all(32),
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
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 5-tap logo → Admin Setup (hidden access)
                  GestureDetector(
                    onTap: () {
                      setState(() => _logoTapCount++);
                      if (_logoTapCount >= 5) {
                        _logoTapCount = 0;
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const AdminSetupScreen(),
                          ),
                        );
                      }
                    },
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: AppTheme.primary,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.asset(
                          'assets/app_logo.jpg',
                          width: 48,
                          height: 48,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  TranslatedText(
                    _loginRole == 'ADMIN'
                        ? 'System Admin Portal'
                        : _loginRole == 'EXPERT'
                            ? 'Agronomist Portal'
                            : 'Welcome Back Farmer',
                    style: const TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TranslatedText(
                    _loginRole == 'ADMIN'
                        ? 'Sign in to oversee all farmers & experts, review work activity, and audit operations.'
                        : _loginRole == 'EXPERT' 
                            ? 'Sign in to access triage queue, diagnosis reviews & lab dispatch.' 
                            : 'Sign in to monitor your crops and get AI diagnosis.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppTheme.onSurfaceVariant, fontSize: 13),
                  ),
                  const SizedBox(height: 20),

                  // Portal Switcher Tabs (3 Fixed Roles)
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceVariant.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        // Farmer Tab
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _loginRole = 'FARMER';
                                _errorMessage = '';
                              });
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: _loginRole == 'FARMER' ? AppTheme.primary : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: _loginRole == 'FARMER'
                                    ? [
                                        BoxShadow(
                                          color: AppTheme.primary.withValues(alpha: 0.3),
                                          blurRadius: 6,
                                          offset: const Offset(0, 2),
                                        )
                                      ]
                                    : null,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.agriculture_rounded,
                                    size: 15,
                                    color: _loginRole == 'FARMER' ? Colors.white : AppTheme.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: 4),
                                  TranslatedText(
                                    'Farmer',
                                    style: TextStyle(
                                      color: _loginRole == 'FARMER' ? Colors.white : AppTheme.onSurfaceVariant,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        // Expert Tab
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _loginRole = 'EXPERT';
                                _errorMessage = '';
                              });
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: _loginRole == 'EXPERT' ? const Color(0xFF1565C0) : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: _loginRole == 'EXPERT'
                                    ? [
                                        BoxShadow(
                                          color: const Color(0xFF1565C0).withValues(alpha: 0.3),
                                          blurRadius: 6,
                                          offset: const Offset(0, 2),
                                        )
                                      ]
                                    : null,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.biotech_rounded,
                                    size: 15,
                                    color: _loginRole == 'EXPERT' ? Colors.white : AppTheme.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: 4),
                                  TranslatedText(
                                    'Expert',
                                    style: TextStyle(
                                      color: _loginRole == 'EXPERT' ? Colors.white : AppTheme.onSurfaceVariant,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        // Admin Tab
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _loginRole = 'ADMIN';
                                _errorMessage = '';
                              });
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              decoration: BoxDecoration(
                                color: _loginRole == 'ADMIN' ? const Color(0xFF1B381A) : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: _loginRole == 'ADMIN'
                                    ? [
                                        BoxShadow(
                                          color: const Color(0xFF1B381A).withValues(alpha: 0.3),
                                          blurRadius: 6,
                                          offset: const Offset(0, 2),
                                        )
                                      ]
                                    : null,
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.admin_panel_settings_rounded,
                                    size: 15,
                                    color: _loginRole == 'ADMIN' ? Colors.white : AppTheme.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: 4),
                                  TranslatedText(
                                    'Admin',
                                    style: TextStyle(
                                      color: _loginRole == 'ADMIN' ? Colors.white : AppTheme.onSurfaceVariant,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (_errorMessage.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.error.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppTheme.error.withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline_rounded, color: AppTheme.error, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TranslatedText(
                                _errorMessage,
                                style: const TextStyle(color: AppTheme.error, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
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
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _login,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.secondaryContainer,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(color: AppTheme.onSecondaryContainer),
                            )
                          : const TranslatedText(
                              'Sign In',
                              style: TextStyle(
                                color: AppTheme.onSecondaryContainer,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [

                      const TranslatedText(
                        "Don't have an account? ",
                        style: TextStyle(color: AppTheme.onSurfaceVariant),
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const SignupScreen()),
                          );
                        },
                        child: const TranslatedText(
                          'Sign Up',
                          style: TextStyle(
                            color: AppTheme.primary,
                            fontWeight: FontWeight.bold,
                            decoration: TextDecoration.underline,
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
    );
  }
}
