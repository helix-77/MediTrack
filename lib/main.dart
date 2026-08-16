import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';

import 'config/api_config.dart';
import 'core/network/dio_client.dart';
import 'features/bdapps/bd_apps_service.dart';
import 'features/bdapps/data/bd_apps_api_client.dart';
import 'features/bdapps/data/sms_api_client.dart';
import 'logic/auth_guard.dart';
import 'theme/app_theme.dart';
import 'theme/colors.dart';
import 'theme/theme_notifier.dart';
import 'l10n/locale_notifier.dart';
import 'services/auth_service.dart';
import 'services/entitlement_service.dart';
import 'services/notification_service.dart';
import 'screens/account_upgrade_screen.dart';
import 'screens/main_navigation_shell.dart';
import 'screens/medicine_detail_screen.dart';
import 'screens/welcome_screen.dart';
import 'firebase_options.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

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
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Firebase init notice: $e');
  }

  // Initialize Firebase App Check
  try {
    await FirebaseAppCheck.instance.activate(
      androidProvider: kDebugMode
          ? AndroidProvider.debug
          : AndroidProvider.playIntegrity,
      appleProvider: kDebugMode
          ? AppleProvider.debug
          : AppleProvider.deviceCheck,
    );
  } catch (e) {
    debugPrint('App Check init notice: $e');
  }

  try {
    final notificationService = NotificationService();
    notificationService.onNotificationTap = (response) {
      final payload = response.payload;
      if (payload == null) return;
      final separator = payload.indexOf(':');
      if (separator <= 0 || separator == payload.length - 1) return;
      final medicineId = payload.substring(separator + 1);
      appNavigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (_) => MedicineDetailScreen(medicineId: medicineId),
        ),
      );
    };
    await notificationService.init();
  } catch (e) {
    debugPrint('Notification init notice: $e');
  }

  runApp(const MediTrackApp());
}

class MediTrackApp extends StatelessWidget {
  const MediTrackApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Single Dio instance shared by all BD Apps feature clients so the
    // base URL / timeouts stay consistent. The Provider scope is the
    // whole app so the Profile tab can read subscription state.
    final dio = DioClient.create(baseUrl: ApiConfig.bdappsBaseUrl);
    final bdAppsApiClient = BdAppsApiClient(dio);
    final smsApiClient = SmsApiClient(dio);
    final authService = AuthService();

    return MultiProvider(
      providers: [
        Provider<AuthService>.value(value: authService),
        ChangeNotifierProvider<ThemeNotifier>(
          create: (_) => ThemeNotifier(),
        ),
        ChangeNotifierProvider<LocaleNotifier>(
          create: (_) => LocaleNotifier(),
        ),
        ChangeNotifierProvider<EntitlementService>(
          create: (_) => EntitlementService()..refreshEntitlement(),
        ),
        ChangeNotifierProvider<BdAppsService>(
          create: (_) => BdAppsService(
            apiClient: bdAppsApiClient,
            smsApiClient: smsApiClient,
          ),
        ),
      ],
      child: Builder(
        builder: (context) {
          final themeNotifier = context.watch<ThemeNotifier>();
          return MaterialApp(
            navigatorKey: appNavigatorKey,
            title: 'MediTrack',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeNotifier.themeMode,
            home: StreamBuilder(
          stream: authService.authStateChanges,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(
                  child: CircularProgressIndicator(
                    color: AppColors.primaryGreen,
                  ),
                ),
              );
            }

            return switch (authRouteFor(snapshot.data)) {
              AuthRoute.welcome => const WelcomeScreen(),
              AuthRoute.accountUpgrade => const AccountUpgradeScreen(),
              AuthRoute.app => const MainNavigationShell(),
            };
          },
        ),
      );
    },
  ),
);
  }
}
