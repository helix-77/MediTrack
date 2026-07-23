import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'theme/app_theme.dart';
import 'theme/colors.dart';
import 'services/notification_service.dart';
import 'screens/main_navigation_shell.dart';
import 'screens/welcome_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Dotenv
  try {
    await dotenv.load(fileName: '.env');
  } catch (e) {
    debugPrint('Dotenv init notice: $e');
  }

  // Initialize Firebase
  try {
    await Firebase.initializeApp();
  } catch (e) {
    debugPrint('Firebase init notice: $e');
  }

  // Initialize Local Notifications
  try {
    await NotificationService().init();
  } catch (e) {
    debugPrint('Notification init notice: $e');
  }

  runApp(const MediTrackApp());
}

class MediTrackApp extends StatelessWidget {
  const MediTrackApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MediTrack',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(
              body: Center(
                child: CircularProgressIndicator(color: AppColors.primaryGreen),
              ),
            );
          }

          if (snapshot.hasData && snapshot.data != null) {
            return const MainNavigationShell();
          }

          return const WelcomeScreen();
        },
      ),
    );
  }
}
