import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../features/bdapps/data/bd_apps_api_client.dart';
import '../logic/auth_guard.dart';
import '../logic/entitlement_guard.dart';
import '../screens/account_upgrade_screen.dart';
import '../screens/subscription_offer_screen.dart';

class EntitlementService extends ChangeNotifier {
  final FirebaseFirestore? _customFirestore;
  final FirebaseAuth? _customAuth;
  final BdAppsApiClient? _apiClient;

  FirebaseFirestore get _firestore => _customFirestore ?? FirebaseFirestore.instance;
  FirebaseAuth get _auth => _customAuth ?? FirebaseAuth.instance;

  bool _isSubscribed = false;
  int _aiMessagesToday = 0;
  int _prescriptionScansToday = 0;
  bool _isLoading = false;
  DateTime? _lastVerifiedAt;
  StreamSubscription<User?>? _authSubscription;

  /// Cache freshness duration before forcing a carrier re-verification.
  static const Duration freshnessWindow = Duration(minutes: 5);

  EntitlementService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    BdAppsApiClient? apiClient,
    BdAppsApiClient? bdAppsApiClient,
  })  : _customFirestore = firestore,
        _customAuth = auth,
        _apiClient = apiClient ?? bdAppsApiClient {
    try {
      _authSubscription = _auth.authStateChanges().listen((user) {
        if (user == null || user.isAnonymous) {
          _isSubscribed = false;
          _aiMessagesToday = 0;
          _prescriptionScansToday = 0;
          _lastVerifiedAt = null;
          notifyListeners();
        } else {
          refreshEntitlement();
        }
      });
    } catch (_) {
      // Ignored in unit test environments without Firebase initialized
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  bool get isSubscribed => _isSubscribed;
  int get aiMessagesToday => _aiMessagesToday;
  int get prescriptionScansToday => _prescriptionScansToday;
  bool get isLoading => _isLoading;
  DateTime? get lastVerifiedAt => _lastVerifiedAt;

  String _getTodayKey() => DateFormat('yyyy-MM-dd').format(DateTime.now());

  User? _currentUser() => _auth.currentUser;

  /// Loads or refreshes the subscription status from Firestore / BD Apps and daily usage counters.
  Future<bool> refreshEntitlement({
    bool forceCarrierCheck = false,
    BdAppsApiClient? apiClient,
  }) async {
    final user = _currentUser();
    if (user == null || user.isAnonymous) {
      _isSubscribed = false;
      _aiMessagesToday = 0;
      _prescriptionScansToday = 0;
      _lastVerifiedAt = null;
      notifyListeners();
      return false;
    }

    _isLoading = true;
    notifyListeners();

    final client = apiClient ?? _apiClient;

    try {
      // 1. Read user profile from users/{uid}/profile/main
      final profileDoc = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('profile')
          .doc('main')
          .get();

      if (!profileDoc.exists) {
        _isSubscribed = false;
        _lastVerifiedAt = null;
      } else {
        final data = profileDoc.data() ?? {};
        final bdMobile = data['bdMobile'] as String?;
        final status = (data['subscriptionStatus'] as String?)?.toUpperCase();
        final verifiedTimestamp = data['subscriptionVerifiedAt'] as Timestamp?;
        final verifiedDate = verifiedTimestamp?.toDate();

        if (bdMobile == null || bdMobile.isEmpty) {
          // No linked BD mobile => not entitled
          _isSubscribed = false;
          _lastVerifiedAt = verifiedDate;
        } else {
          final isFresh = !forceCarrierCheck &&
              verifiedDate != null &&
              DateTime.now().difference(verifiedDate) < freshnessWindow;

          if (isFresh && status != null) {
            _isSubscribed = status == 'REGISTERED';
            _lastVerifiedAt = verifiedDate;
          } else if (client != null) {
            // Stale or forced check => query BD Apps
            try {
              final response =
                  await client.checkSubscription(userMobile: bdMobile);
              final newStatus = response.subscriptionStatus ?? 'UNREGISTERED';
              if (newStatus.toUpperCase() == 'UNKNOWN') {
                // BD Apps server error / timeout: retain existing cached Firestore status
                _isSubscribed = status == 'REGISTERED';
                _lastVerifiedAt = verifiedDate;
              } else {
                _isSubscribed = (newStatus.toUpperCase() == 'REGISTERED');
                _lastVerifiedAt = DateTime.now();

                // Persist fresh verification timestamp and status to Firestore
                await _firestore
                    .collection('users')
                    .doc(user.uid)
                    .collection('profile')
                    .doc('main')
                    .set({
                  'subscriptionStatus': newStatus,
                  'subscriptionVerifiedAt': FieldValue.serverTimestamp(),
                }, SetOptions(merge: true));
              }
            } catch (e) {
              debugPrint('Carrier verification error: $e');
              // Fall back to cached status if network failed
              _isSubscribed = status == 'REGISTERED';
              _lastVerifiedAt = verifiedDate;
            }
          } else {
            _isSubscribed = status == 'REGISTERED';
            _lastVerifiedAt = verifiedDate;
          }
        }
      }

      // 2. Read non-content usage doc for today
      final todayKey = _getTodayKey();
      final usageDoc = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('usage')
          .doc(todayKey)
          .get();

      if (usageDoc.exists) {
        final data = usageDoc.data() ?? {};
        _aiMessagesToday = (data['aiMessagesCount'] as num?)?.toInt() ?? 0;
        _prescriptionScansToday =
            (data['prescriptionScansCount'] as num?)?.toInt() ?? 0;
      } else {
        _aiMessagesToday = 0;
        _prescriptionScansToday = 0;
      }
    } catch (e) {
      debugPrint('Entitlement refresh notice: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }

    return _isSubscribed;
  }

  /// Reusable gate helper: checks entitlement and presents the upgrade/offer screen if not active.
  /// Returns `true` if the user is entitled to proceed with the requested feature.
  Future<bool> requirePremium(
    BuildContext context, {
    required EntitlementFeature feature,
  }) async {
    // Quick refresh if status might be stale
    if (_lastVerifiedAt == null ||
        DateTime.now().difference(_lastVerifiedAt!) >= freshnessWindow) {
      await refreshEntitlement();
    }

    if (_isSubscribed) {
      final quota = checkQuota(feature);
      if (!quota.isAllowed && quota.isSoftCapReached) {
        if (context.mounted) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Daily Limit Reached'),
              content: Text(quota.statusMessage),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
        return false;
      }
      return true;
    }

    if (!context.mounted) return false;

    final user = _currentUser();
    if (user == null || user.isAnonymous) {
      // Prompt user to upgrade to a permanent account first
      final upgraded = await Navigator.push<bool>(
        context,
        MaterialPageRoute(builder: (_) => const AccountUpgradeScreen()),
      );
      if (!context.mounted) return false;
      if (upgraded != true && (_auth.currentUser?.isAnonymous ?? true)) {
        return false;
      }
      await refreshEntitlement();
      if (_isSubscribed) return true;
    }

    if (!context.mounted) return false;

    // Show commercial offer screen
    final subscribed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => const SubscriptionOfferScreen(),
      ),
    );

    if (subscribed == true) {
      await refreshEntitlement(forceCarrierCheck: true);
      return _isSubscribed;
    }

    return _isSubscribed;
  }

  QuotaEvaluation checkQuota(EntitlementFeature feature) {
    return EntitlementGuard.evaluate(
      isSubscribed: _isSubscribed,
      aiMessagesToday: _aiMessagesToday,
      prescriptionScansToday: _prescriptionScansToday,
      feature: feature,
    );
  }

  QuotaEvaluation checkAiQuota() =>
      checkQuota(EntitlementFeature.aiAssistant);

  QuotaEvaluation checkPrescriptionQuota() =>
      checkQuota(EntitlementFeature.prescriptionOcr);

  /// Increments daily AI chat counter without logging any message content
  Future<void> recordAiUsage() async {
    final user = requireAuthenticatedUser(_auth);
    final todayKey = _getTodayKey();

    _aiMessagesToday++;
    notifyListeners();

    try {
      final docRef = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('usage')
          .doc(todayKey);

      await docRef.set({
        'aiMessagesCount': FieldValue.increment(1),
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Usage tracking error: $e');
    }
  }

  /// Increments daily Prescription OCR scan counter without logging any image/text
  Future<void> recordPrescriptionScanUsage() async {
    final user = requireAuthenticatedUser(_auth);
    final todayKey = _getTodayKey();

    _prescriptionScansToday++;
    notifyListeners();

    try {
      final docRef = _firestore
          .collection('users')
          .doc(user.uid)
          .collection('usage')
          .doc(todayKey);

      await docRef.set({
        'prescriptionScansCount': FieldValue.increment(1),
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Usage tracking error: $e');
    }
  }

  /// Manually update cached subscription flag
  void updateSubscribedState(bool subscribed) {
    _isSubscribed = subscribed;
    _lastVerifiedAt = DateTime.now();
    notifyListeners();
  }
}
