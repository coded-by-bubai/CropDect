import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme.dart';
import '../api_client.dart';
import 'dashboard_screen.dart';
import 'expert_home_screen.dart';
import 'admin_dashboard_screen.dart';
import '../widgets/translated_text.dart';

class RoleDispatcherScreen extends StatefulWidget {
  const RoleDispatcherScreen({super.key});

  @override
  State<RoleDispatcherScreen> createState() => _RoleDispatcherScreenState();
}

class _RoleDispatcherScreenState extends State<RoleDispatcherScreen> {
  @override
  void initState() {
    super.initState();
    _dispatch();
  }

  Future<void> _dispatch() async {
    final prefs = await SharedPreferences.getInstance();
    String? role = prefs.getString('user_role');

    // If role not cached locally, query /users/me
    if (role == null) {
      try {
        final res = await apiClient.get('/users/me');
        if (res.data is Map<String, dynamic>) {
          role = res.data['role'];
          if (role != null) {
            await prefs.setString('user_role', role);
          }
        }
      } catch (_) {}
    }

    if (!mounted) return;

    if (role == 'ADMIN') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const AdminDashboardScreen()),
      );
    } else if (role == 'EXPERT' || role == 'EXTENSION_WORKER') {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const ExpertHomeScreen()),
      );
    } else {
      // Default to Farmer perspective
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const DashboardScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.asset('assets/app_logo.jpg', width: 64, height: 64, fit: BoxFit.cover),
            ),
            const SizedBox(height: 20),
            const CircularProgressIndicator(color: AppTheme.primary),
            const SizedBox(height: 12),
            const TranslatedText(
              'Loading your workspace...',
              style: TextStyle(color: AppTheme.onSurfaceVariant, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}
