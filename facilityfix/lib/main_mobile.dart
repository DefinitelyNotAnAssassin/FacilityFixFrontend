// Mobile
import 'package:facilityfix/landingpage/login_or_signup.dart';
import 'package:facilityfix/landingpage/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:facilityfix/services/chat_helper.dart';
import 'package:facilityfix/services/firebase_config.dart';
import 'firebase_options.dart';
import 'debug/firebase_debug.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Initialize Firebase with proper options
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('[FacilityFix] Firebase initialized successfully');

    // Configure Firestore settings
    FirebaseConfig.configureFirestore();

    // Test Firebase connection
    final isConnected = await FirebaseConfig.testConnection();
    if (isConnected) {
      print('[FacilityFix] Firebase connection verified');

      // Initialize chat collections only if Firebase is working
      await ChatHelper.initializeChat();
      print('[FacilityFix] Chat initialized successfully');
    } else {
      print('[FacilityFix] Firebase connection failed');
      print('[FacilityFix] Chat features will be disabled');

      // Run detailed diagnostics when connection fails
      print('[FacilityFix] Running Firebase diagnostics...');
      final diagnostics = await FirebaseDebugUtils.runDiagnostics();
      FirebaseDebugUtils.printDiagnostics(diagnostics);
    }
  } catch (e) {
    print('[FacilityFix] Initialization error: $e');
  }

  runApp(const MyApp());
}

// Global navigator key for navigation
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey, // Add the navigator key here
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: const Color(0xFF005CE8),
        hintColor: const Color(0xFFF4F5FF),
        iconButtonTheme: IconButtonThemeData(
          style: ButtonStyle(
            backgroundColor: WidgetStateProperty.all<Color>(
              const Color(0xFFF4F5FF),
            ),
            foregroundColor: WidgetStateProperty.all<Color>(
              const Color(0xFF005CE8),
            ),
          ),
        ),
        fontFamily: 'Inter',
      ),
      // animated splash widget
      home: SplashScreen(
        onDone: () {
          navigatorKey.currentState?.pushReplacement(
            MaterialPageRoute(builder: (_) => const LoginOrSignup(role: '')),
          );
        },
      ),
    );
  }
}
