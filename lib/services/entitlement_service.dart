import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../logic/auth_guard.dart';
import '../logic/entitlement_guard.dart';

class EntitlementService extends ChangeNotifier {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  bool _isSubscribed = false;
  int _aiMessagesToday = 0;
  int _prescriptionScansToday = 0;
  bool _isLoading = false;

  EntitlementService({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  bool get isSubscribed => _isSubscribed;
  int get aiMessagesToday => _aiMessagesToday;
  int get prescriptionScansToday => _prescriptionScansToday;
  bool get isLoading => _isLoading;

  String _getTodayKey() => DateFormat('yyyy-MM-dd').format(DateTime.now());

  User? _currentUser() => _auth.currentUser;

  /// Loads or refreshes the cached subscription status and daily usage counters
  Future<void> refreshEntitlement() async {
    final user = _currentUser();
    if (user == null || user.isAnonymous) {
      _isSubscribed = false;
      _aiMessagesToday = 0;
      _prescriptionScansToday = 0;
      notifyListeners();
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      // 1. Check user profile for subscription status
      final profileDoc =
          await _firestore.collection('users').doc(user.uid).get();
      if (profileDoc.exists) {
        final status = (profileDoc.data()?['subscriptionStatus'] as String?)?.toUpperCase();
        _isSubscribed = status == 'REGISTERED' || status == 'ACTIVE' || status == 'SUBSCRIBED';
      } else {
        _isSubscribed = false;
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
  }

  QuotaEvaluation checkAiQuota() {
    return EntitlementGuard.evaluate(
      isSubscribed: _isSubscribed,
      aiMessagesToday: _aiMessagesToday,
      prescriptionScansToday: _prescriptionScansToday,
      feature: EntitlementFeature.aiAssistant,
    );
  }

  QuotaEvaluation checkPrescriptionQuota() {
    return EntitlementGuard.evaluate(
      isSubscribed: _isSubscribed,
      aiMessagesToday: _aiMessagesToday,
      prescriptionScansToday: _prescriptionScansToday,
      feature: EntitlementFeature.prescriptionOcr,
    );
  }

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

  /// Manually update cached subscription flag (e.g. after successful OTP verification)
  void updateSubscribedState(bool subscribed) {
    _isSubscribed = subscribed;
    notifyListeners();
  }
}
