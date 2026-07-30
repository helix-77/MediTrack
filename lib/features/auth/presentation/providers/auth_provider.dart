import 'package:flutter/foundation.dart';

import '../../data/auth_repository.dart';
import '../../data/models/send_otp_response.dart';
import '../../data/models/unsubscribe_response.dart';
import '../../data/models/verify_otp_response.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

/// Which card the login screen shows. Deliberately separate from
/// [AuthStatus] — the router only ever branches on [AuthStatus], so adding
/// an in-between "awaiting code" value there would mean touching redirect
/// logic for no benefit.
enum LoginStep { enterPhone, enterCode }

/// Holds auth state for the whole app. `status` starts as [AuthStatus.unknown]
/// while the persisted flag is being restored; the router's redirect logic
/// waits on that before deciding where to send the user.
class AuthProvider extends ChangeNotifier {
  AuthProvider(this._repository) {
    _restore();
  }

  final AuthRepository _repository;

  AuthStatus status = AuthStatus.unknown;
  LoginStep loginStep = LoginStep.enterPhone;

  /// The verified, persisted number — only set once `verifyOtp` succeeds.
  String? phoneNumber;

  /// The number an OTP was just sent to, held in memory only until verified.
  String? pendingPhoneNumber;

  /// The reference number returned by the last successful `sendOtp`. The
  /// user must echo this back when verifying the OTP, so it lives on the
  /// provider (not storage) until verification succeeds or the user backs
  /// out of the OTP screen.
  String? pendingReferenceNo;

  /// The last-known subscription lifecycle state (e.g. `"REGISTERED"`),
  /// restored from local storage on cold start.
  String? subscriptionStatus;

  bool isSubmitting = false;
  String? errorMessage;

  /// The most recent server response for a `sendOtp` call. Populated on
  /// every attempt regardless of branch, so the UI can read
  /// `statusCode` (e.g. `E1853`), `statusDetail`, and `subscriberId`.
  SendOtpResponse? lastSendOtpResponse;

  /// The most recent server response for a `verifyOtp` call. Populated on
  /// every attempt regardless of branch, so the UI can read `statusCode`
  /// (`"S1000"` for success), `statusDetail`, `subscriptionStatus`, and
  /// `subscriberId`.
  VerifyOtpResponse? lastVerifyOtpResponse;

  /// The most recent server response for an `unsubscribe` call (fired
  /// during logout). `null` until the user logs out for the first time,
  /// or if the backend was unreachable — in which case local logout still
  /// succeeds (see [AuthRepository.unsubscribe]).
  UnsubscribeResponse? lastUnsubscribeResponse;

  Future<void> _restore() async {
    final authenticated = await _repository.isAuthenticated();
    phoneNumber = await _repository.getPhoneNumber();
    subscriptionStatus = await _repository.getSubscriptionStatus();
    status = authenticated
        ? AuthStatus.authenticated
        : AuthStatus.unauthenticated;
    notifyListeners();
  }

  Future<void> sendOtp(String phoneNumber) async {
    isSubmitting = true;
    errorMessage = null;
    notifyListeners();

    try {
      final result = await _repository.sendOtp(phoneNumber);
      lastSendOtpResponse = result.response;
      switch (result) {
        case SendOtpSuccess():
          pendingPhoneNumber = phoneNumber;
          pendingReferenceNo = result.referenceNo;
          loginStep = LoginStep.enterCode;
        case SendOtpFailure():
          pendingReferenceNo = null;
          errorMessage = result.response.message ?? 'Failed to send code.';
      }
    } on AuthFailure catch (e) {
      lastSendOtpResponse = null;
      pendingReferenceNo = null;
      errorMessage = e.message;
    } catch (_) {
      lastSendOtpResponse = null;
      pendingReferenceNo = null;
      errorMessage = 'Something went wrong. Please try again.';
    } finally {
      isSubmitting = false;
      notifyListeners();
    }
  }

  Future<void> resendOtp() async {
    final phone = pendingPhoneNumber;
    if (phone == null) return;
    await sendOtp(phone);
  }

  Future<void> verifyOtp(String code) async {
    final referenceNo = pendingReferenceNo;
    final phone = pendingPhoneNumber;
    if (referenceNo == null || phone == null) return;

    isSubmitting = true;
    errorMessage = null;
    notifyListeners();

    try {
      final result = await _repository.verifyOtp(
        referenceNo: referenceNo,
        code: code,
        phoneNumber: phone,
      );
      lastVerifyOtpResponse = result.response;
      switch (result) {
        case VerifyOtpSuccess():
          // The repository already persisted via LocalStorageService; mirror
          // that into in-memory state so the router picks up the change.
          phoneNumber = phone;
          pendingPhoneNumber = null;
          pendingReferenceNo = null;
          subscriptionStatus = result.response.subscriptionStatus;
          status = AuthStatus.authenticated;
        case VerifyOtpFailure():
          errorMessage =
              result.response.statusDetail ?? 'Invalid code. Please try again.';
      }
    } on AuthFailure catch (e) {
      lastVerifyOtpResponse = null;
      errorMessage = e.message;
    } catch (_) {
      lastVerifyOtpResponse = null;
      errorMessage = 'Something went wrong. Please try again.';
    } finally {
      isSubmitting = false;
      notifyListeners();
    }
  }

  void backToPhoneEntry() {
    loginStep = LoginStep.enterPhone;
    pendingPhoneNumber = null;
    errorMessage = null;
    notifyListeners();
  }

  Future<void> logout() async {
    // Tell the backend to unregister this number before clearing local
    // state. The repository treats this as best-effort: a network failure
    // returns null and local logout still completes, so the user is never
    // stranded by a flaky connection.
    final unsubscribeResult =
        await _repository.unsubscribe(phoneNumber: phoneNumber ?? '');
    lastUnsubscribeResponse = unsubscribeResult;

    await _repository.logout();

    phoneNumber = null;
    pendingPhoneNumber = null;
    subscriptionStatus = null;
    loginStep = LoginStep.enterPhone;
    status = AuthStatus.unauthenticated;
    notifyListeners();
  }
}