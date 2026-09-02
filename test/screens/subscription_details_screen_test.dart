import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meditrack/core/network/dio_client.dart';
import 'package:meditrack/features/bdapps/bd_apps_service.dart';
import 'package:meditrack/features/bdapps/data/bd_apps_api_client.dart';
import 'package:meditrack/models/user_profile.dart';
import 'package:meditrack/screens/subscription_details_screen.dart';
import 'package:meditrack/services/entitlement_service.dart';
import 'package:meditrack/theme/app_theme.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('subscription details screen renders active subscription, privileges and all 3 cancellation methods',
      (tester) async {
    final dio = DioClient.create(baseUrl: 'https://example.com');
    final bdApiClient = BdAppsApiClient(dio);
    final bdAppsService = BdAppsService(apiClient: bdApiClient);
    final entitlementService = EntitlementService(bdAppsApiClient: bdApiClient);

    // Set subscribed state
    entitlementService.updateSubscribedState(true);

    final profile = UserProfile(
      uid: 'user_123',
      displayName: 'Rahi Hasan',
      email: 'rahi@example.com',
      bdMobile: '01812345678',
      subscriptionStatus: 'REGISTERED',
      subscriptionVerifiedAt: DateTime.now(),
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<BdAppsService>.value(value: bdAppsService),
          ChangeNotifierProvider<EntitlementService>.value(value: entitlementService),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: SubscriptionDetailsScreen(profile: profile),
        ),
      ),
    );

    // App bar title
    expect(find.text('Subscription Details'), findsOneWidget);

    // Active status card
    expect(find.text('MediTrack Premium'), findsOneWidget);
    expect(find.text('ACTIVE'), findsOneWidget);
    expect(find.text('৳2.99 / day'), findsOneWidget);
    expect(find.textContaining('018'), findsWidgets);

    // Daily Quota section
    expect(find.text("Today's AI Quota & Usage"), findsOneWidget);
    expect(find.text('AI Assistant Messages'), findsOneWidget);
    expect(find.text('Prescription Scans'), findsOneWidget);

    // 4 Privileges
    expect(find.text('AI Prescription OCR'), findsOneWidget);
    expect(find.text('Smart Assistant'), findsOneWidget);
    expect(find.text('Price & Generics'), findsOneWidget);
    expect(find.text('Nearby Pharmacies'), findsOneWidget);

    // Cancellation Section Header & 3 Methods
    expect(find.text('Cancel Subscription'), findsOneWidget);
    expect(find.text('Method 1: Instant In-App Cancel'), findsOneWidget);
    expect(find.text('Cancel Subscription in App'), findsOneWidget);
    expect(find.text('Method 2: Cancel via Telco SMS'), findsOneWidget);
    expect(find.text('Method 3: Cancel via USSD Menu'), findsOneWidget);
  });

  testWidgets('subscription details screen renders inactive banner when not subscribed',
      (tester) async {
    final dio = DioClient.create(baseUrl: 'https://example.com');
    final bdApiClient = BdAppsApiClient(dio);
    final bdAppsService = BdAppsService(apiClient: bdApiClient);
    final entitlementService = EntitlementService(bdAppsApiClient: bdApiClient);

    // Not subscribed
    entitlementService.updateSubscribedState(false);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<BdAppsService>.value(value: bdAppsService),
          ChangeNotifierProvider<EntitlementService>.value(value: entitlementService),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const SubscriptionDetailsScreen(),
        ),
      ),
    );

    expect(find.text('Free Tier (Inactive)'), findsOneWidget);
    expect(find.text('INACTIVE'), findsOneWidget);
    expect(find.text('Your Subscription is Currently Inactive'), findsOneWidget);
    expect(find.text('Upgrade to Premium'), findsOneWidget);
  });
}
