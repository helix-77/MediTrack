import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meditrack/core/network/dio_client.dart';
import 'package:meditrack/features/bdapps/bd_apps_service.dart';
import 'package:meditrack/features/bdapps/data/bd_apps_api_client.dart';
import 'package:meditrack/features/bdapps/data/sms_api_client.dart';
import 'package:meditrack/features/bdapps/subscription_offer_config.dart';
import 'package:meditrack/screens/subscription_offer_screen.dart';
import 'package:meditrack/services/entitlement_service.dart';
import 'package:meditrack/theme/app_theme.dart';
import 'package:provider/provider.dart';

void main() {
  testWidgets('subscription offer screen renders all commercial disclosures and features',
      (tester) async {
    final dio = DioClient.create(baseUrl: 'https://example.com');
    final bdApiClient = BdAppsApiClient(dio);
    final smsApiClient = SmsApiClient(dio);
    final bdAppsService = BdAppsService(apiClient: bdApiClient, smsApiClient: smsApiClient);
    final entitlementService = EntitlementService(bdAppsApiClient: bdApiClient);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<BdAppsService>.value(value: bdAppsService),
          ChangeNotifierProvider<EntitlementService>.value(value: entitlementService),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const SubscriptionOfferScreen(),
        ),
      ),
    );

    // Headline & Price
    expect(find.text(SubscriptionOfferConfig.headline), findsOneWidget);
    expect(find.text('৳2.00'), findsOneWidget);
    expect(find.textContaining('VAT+SD+SC'), findsWidgets);

    // Carrier Badges
    expect(find.text('Robi (018)'), findsOneWidget);
    expect(find.text('Airtel (016)'), findsOneWidget);

    // 4 Features
    for (final feature in SubscriptionOfferConfig.features) {
      expect(find.text(feature['title']!), findsOneWidget);
    }

    // Consent Checkbox
    expect(find.byType(Checkbox), findsOneWidget);
    expect(find.textContaining('I agree to subscribe to MediTrack Premium at ৳2.00/day'), findsOneWidget);
    expect(find.text('Terms & Conditions'), findsOneWidget);
    expect(find.text('Privacy Policy'), findsOneWidget);
  });
}
