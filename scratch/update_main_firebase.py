import re

file_path = r"c:\Users\Bubai Das\Desktop\programming\Project\CropDect_AI\cropdect\lib\main.dart"

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Add imports
imports = """import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';"""
content = content.replace("import 'package:flutter/material.dart';\nimport 'package:provider/provider.dart';\nimport 'package:shared_preferences/shared_preferences.dart';", imports)


# 2. Add background message handler and global notification variables before main()
bg_handler = """

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print("Handling a background message: ${message.messageId}");
}

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

void main() async {"""
content = content.replace("void main() async {", bg_handler)


# 3. Add Firebase setup inside main()
main_setup = """  WidgetsFlutterBinding.ensureInitialized();

  // Firebase Setup (requires google-services.json to compile)
  try {
    await Firebase.initializeApp();
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
    
    const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings = InitializationSettings(android: initializationSettingsAndroid);
    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
  } catch (e) {
    print("Firebase init failed (missing google-services.json?): $e");
  }"""
content = content.replace("  WidgetsFlutterBinding.ensureInitialized();", main_setup)

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)

print("Injected Firebase into main.dart")
