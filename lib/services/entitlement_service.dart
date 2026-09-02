import 'dart:async';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/bdapps/data/bd_apps_api_client.dart';
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

  // Cumulative lifetime usage for unsubscribed trial tracking
  int _aiMessagesTotal = 0;
  int _prescriptionScansTotal = 0;
  int _priceLookupsTotal = 0;

  bool _isLoading = false;
  DateTime? _lastVerifiedAt;
  StreamSubscription<User?>? _authSubscription;

  static const String _prefAiTotal = 'meditrack_free_ai_messages_total';
  static const String _prefScansTotal = 'meditrack_free_scans_total';
  static const String _prefLookupsTotal = 'meditrack_free_lookups_total';

  /// Cache freshness duration before forcing a carrier re-verification.
  static const Duration freshnessWindow = Duration(hours: 12);

  EntitlementService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    BdAppsApiClient? apiClient,
    BdAppsApiClient? bdAppsApiClient,
  })  : _customFirestore = firestore,
        _customAuth = auth,
        _apiClient = apiClient ?? bdAppsApiClient {
    _loadLocalUsage();
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

  Future<void> _loadLocalUsage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _aiMessagesTotal = prefs.getInt(_prefAiTotal) ?? 0;
      _prescriptionScansTotal = prefs.getInt(_prefScansTotal) ?? 0;
      _priceLookupsTotal = prefs.getInt(_prefLookupsTotal) ?? 0;
      notifyListeners();
    } catch (_) {}
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  bool get isSubscribed => _isSubscribed;
  int get aiMessagesToday => _aiMessagesToday;
  int get prescriptionScansToday => _prescriptionScansToday;
  int get aiMessagesTotal => _aiMessagesTotal;
  int get prescriptionScansTotal => _prescriptionScansTotal;
  int get priceLookupsTotal => _priceLookupsTotal;

  int get freePrescriptionScansRemaining =>
      math.max(0, EntitlementGuard.freePrescriptionScansTotal - _prescriptionScansTotal);
  int get freeAiMessagesRemaining =>
      math.max(0, EntitlementGuard.freeAiMessagesTotal - _aiMessagesTotal);
  int get freePriceLookupsRemaining =>
      math.max(0, EntitlementGuard.freePriceLookupsTotal - _priceLookupsTotal);

  bool get canDoPrescriptionScan => _isSubscribed || freePrescriptionScansRemaining > 0;
  bool get canDoAiMessage => _isSubscribed || freeAiMessagesRemaining > 0;
  bool get canDoPriceLookup => _isSubscribed || freePriceLookupsRemaining > 0;

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
              if (newStatus.toUpperCase() == 'UNKNOWN' ||
                  (!response.isSuccess && response.statusCode != 'S1000')) {
                // BD Apps server error / timeout: retain existing cached Firestore status
                _isSubscribed = status == 'REGISTERED';
                _lastVerifiedAt = verifiedDate;
              } else {
                _isSubscribed = response.isAlreadyActive;
                _lastVerifiedAt = DateTime.now();

                // Persist fresh verification timestamp and status to Firestore
                await _firestore
                    .collection('users')
                    .doc(user.uid)
                    .collection('profile')
                    .doc('main')
                    .set({
                  'subscriptionStatus':
                      _isSubscribed ? 'REGISTERED' : 'UNREGISTERED',
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

      // 3. Read cumulative trial usage doc
      try {
        final summaryDoc = await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('usage')
            .doc('summary')
            .get();
        if (summaryDoc.exists) {
          final sData = summaryDoc.data() ?? {};
          final firestoreAi = (sData['aiMessagesTotal'] as num?)?.toInt() ?? 0;
          final firestoreScans =
              (sData['prescriptionScansTotal'] as num?)?.toInt() ?? 0;
          final firestoreLookups =
              (sData['priceLookupsTotal'] as num?)?.toInt() ?? 0;

          _aiMessagesTotal = math.max(_aiMessagesTotal, firestoreAi);
          _prescriptionScansTotal =
              math.max(_prescriptionScansTotal, firestoreScans);
          _priceLookupsTotal = math.max(_priceLookupsTotal, firestoreLookups);

          final prefs = await SharedPreferences.getInstance();
          await prefs.setInt(_prefAiTotal, _aiMessagesTotal);
          await prefs.setInt(_prefScansTotal, _prescriptionScansTotal);
          await prefs.setInt(_prefLookupsTotal, _priceLookupsTotal);
        }
      } catch (e) {
        debugPrint('Usage summary read notice: $e');
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

    // Check if within free trial allowances
    final quota = checkQuota(feature);
    if (quota.isAllowed) {
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
      _isSubscribed = true;
      _lastVerifiedAt = DateTime.now();
      notifyListeners();
      return true;
    }

    return _isSubscribed;
  }

  QuotaEvaluation checkQuota(EntitlementFeature feature) {
    return EntitlementGuard.evaluate(
      isSubscribed: _isSubscribed,
      aiMessagesToday: _aiMessagesToday,
      prescriptionScansToday: _prescriptionScansToday,
      aiMessagesTotal: _aiMessagesTotal,
      prescriptionScansTotal: _prescriptionScansTotal,
      priceLookupsTotal: _priceLookupsTotal,
      feature: feature,
    );
  }

  QuotaEvaluation checkAiQuota() =>
      checkQuota(EntitlementFeature.aiAssistant);

  QuotaEvaluation checkPrescriptionQuota() =>
      checkQuota(EntitlementFeature.prescriptionOcr);

  QuotaEvaluation checkPriceLookupQuota() =>
      checkQuota(EntitlementFeature.priceLookup);

  /// Increments AI chat counter (both daily and cumulative trial)
  Future<void> recordAiUsage() async {
    _aiMessagesToday++;
    _aiMessagesTotal++;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_prefAiTotal, _aiMessagesTotal);
    } catch (_) {}

    final user = _currentUser();
    if (user != null && !user.isAnonymous) {
      final todayKey = _getTodayKey();
      try {
        final batch = _firestore.batch();
        final dailyDoc = _firestore
            .collection('users')
            .doc(user.uid)
            .collection('usage')
            .doc(todayKey);
        final summaryDoc = _firestore
            .collection('users')
            .doc(user.uid)
            .collection('usage')
            .doc('summary');

        batch.set(dailyDoc, {
          'aiMessagesCount': FieldValue.increment(1),
          'lastUpdated': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        batch.set(summaryDoc, {
          'aiMessagesTotal': FieldValue.increment(1),
          'lastUpdated': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        await batch.commit();
      } catch (e) {
        debugPrint('Usage tracking error: $e');
      }
    }
  }

  /// Increments Prescription OCR scan counter (both daily and cumulative trial)
  Future<void> recordPrescriptionScanUsage() async {
    _prescriptionScansToday++;
    _prescriptionScansTotal++;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_prefScansTotal, _prescriptionScansTotal);
    } catch (_) {}

    final user = _currentUser();
    if (user != null && !user.isAnonymous) {
      final todayKey = _getTodayKey();
      try {
        final batch = _firestore.batch();
        final dailyDoc = _firestore
            .collection('users')
            .doc(user.uid)
            .collection('usage')
            .doc(todayKey);
        final summaryDoc = _firestore
            .collection('users')
            .doc(user.uid)
            .collection('usage')
            .doc('summary');

        batch.set(dailyDoc, {
          'prescriptionScansCount': FieldValue.increment(1),
          'lastUpdated': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        batch.set(summaryDoc, {
          'prescriptionScansTotal': FieldValue.increment(1),
          'lastUpdated': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        await batch.commit();
      } catch (e) {
        debugPrint('Scan usage tracking error: $e');
      }
    }
  }

  /// Increments Generic Medicine Price Lookup counter for trial tracking
  Future<void> recordPriceLookupUsage() async {
    _priceLookupsTotal++;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_prefLookupsTotal, _priceLookupsTotal);
    } catch (_) {}

    final user = _currentUser();
    if (user != null && !user.isAnonymous) {
      try {
        await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('usage')
            .doc('summary')
            .set({
          'priceLookupsTotal': FieldValue.increment(1),
          'lastUpdated': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (e) {
        debugPrint('Price lookup tracking error: $e');
      }
    }
  }

  /// Manually update cached subscription flag
  void updateSubscribedState(bool subscribed) {
    _isSubscribed = subscribed;
    _lastVerifiedAt = DateTime.now();
    notifyListeners();
  }

  /// Persists unsubscription state to Firestore and updates in-memory flags
  Future<void> recordUnsubscribed({String? userId}) async {
    final uid = userId ?? _auth.currentUser?.uid;
    _isSubscribed = false;
    _lastVerifiedAt = DateTime.now();
    notifyListeners();

    if (uid != null && uid.isNotEmpty) {
      try {
        await _firestore
            .collection('users')
            .doc(uid)
            .collection('profile')
            .doc('main')
            .set({
          'subscriptionStatus': 'UNREGISTERED',
          'subscriptionVerifiedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (e) {
        debugPrint('Entitlement cancel notice: $e');
      }
    }
  }
}
