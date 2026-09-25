import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'theme.dart';
import 'screens/login_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/role_dispatcher_screen.dart';



@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print("Handling a background message: ${message.messageId}");
}

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

/// Notification channel for Android
const AndroidNotificationChannel _weatherChannel = AndroidNotificationChannel(
  'weather_alerts_channel',
  'Weather Alerts',
  description: 'Severe weather and irrigation alerts for your farm',
  importance: Importance.max,
  playSound: true,
);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase Setup
  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Create high-importance Android notification channel
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_weatherChannel);

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);
    await flutterLocalNotificationsPlugin.initialize(settings: initializationSettings);

    // Request permissions (Android 13+)
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    // IMPORTANT: Show notifications when app is in the FOREGROUND
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final notification = message.notification;
      final android = message.notification?.android;
      if (notification != null && android != null) {
        flutterLocalNotificationsPlugin.show(
          id: notification.hashCode,
          title: notification.title,
          body: notification.body,
          notificationDetails: NotificationDetails(
            android: AndroidNotificationDetails(
              _weatherChannel.id,
              _weatherChannel.name,
              channelDescription: _weatherChannel.description,
              importance: Importance.max,
              priority: Priority.high,
              // White silhouette for status bar (Android requirement)
              icon: '@drawable/ic_notification',
              // Full-color app logo shown in notification card
              largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
              // Brand color for the notification accent
              color: const Color(0xFF046938),
            ),
          ),
        );
      }
    });

    // Get and print the FCM Token for testing
    final fcmToken = await FirebaseMessaging.instance.getToken();
    print('=============================================');
    print('FCM TOKEN: $fcmToken');
    print('=============================================');
  } catch (e) {
    print('Firebase init failed: $e');
  }
  final prefs = await SharedPreferences.getInstance();
  final hasToken = prefs.getString('auth_token') != null;
  final hasSeenOnboarding = prefs.getBool('has_seen_onboarding') ?? false;
  final langCode = prefs.getString('app_language') ?? 'en';

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthState(hasToken)),
        ChangeNotifierProvider(create: (_) => LanguageState(langCode)),
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

class LanguageState extends ChangeNotifier {
  String _currentLanguage;

  LanguageState(this._currentLanguage);

  String get currentLanguage => _currentLanguage;

  Future<void> changeLanguage(String langCode) async {
    if (_currentLanguage == langCode) return;
    _currentLanguage = langCode;
    notifyListeners();
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('app_language', langCode);
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

