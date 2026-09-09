import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'theme.dart';
import 'screens/login_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/role_dispatcher_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final hasToken = prefs.getString('auth_token') != null;
  final hasSeenOnboarding = prefs.getBool('has_seen_onboarding') ?? false;

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthState(hasToken)),
      ],
      child: CropDectApp(hasSeenOnboarding: hasSeenOnboarding),
    ),
  );
}

class AuthState extends ChangeNotifier {
  bool _isAuthenticated;

  AuthState(this._isAuthenticated);

  bool get isAuthenticated => _isAuthenticated;

  Future<void> login(String token, [String? role]) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
    if (role != null) {
      await prefs.setString('user_role', role);
    }
    _isAuthenticated = true;
    notifyListeners();
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('user_role');
    _isAuthenticated = false;
    notifyListeners();
  }
}

class CropDectApp extends StatelessWidget {
  final bool hasSeenOnboarding;

  const CropDectApp({super.key, required this.hasSeenOnboarding});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'cropdect',
      theme: AppTheme.lightTheme,
      home: Consumer<AuthState>(
        builder: (context, authState, child) {
          if (!hasSeenOnboarding) {
            return const OnboardingScreen();
          }
          if (authState.isAuthenticated) {
            return const RoleDispatcherScreen();
          }
          return const LoginScreen();
        },
      ),
    );
  }
}

