import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../logic/bd_mobile_validator.dart';
import 'data/bd_apps_api_client.dart';
import 'data/models/check_subscription_response.dart';
import 'data/models/send_otp_response.dart';
import 'data/models/send_sms_response.dart';
import 'data/models/subscribe_response.dart';
import 'data/models/unsubscribe_response.dart';
import 'data/models/verify_otp_response.dart';
import 'data/sms_api_client.dart';

enum SubscriptionState { idle, requesting, pending, registered, failed }

/// Result of checking a mobile number's BD Apps status before starting the
/// OTP flow (see [BdAppsService.checkNumberBeforeOtp]).
enum BdNumberCheckResult {
  /// The number is already an active BD Apps subscriber — no OTP is
  /// needed, and [BdAppsService] has already applied the registered state.
  alreadyActive,

  /// The number isn't registered yet (or status couldn't be confirmed) —
  /// the caller should proceed with the normal [BdAppsService.sendOtp] flow.
  notRegistered,

  /// The number failed local validation (not a valid Robi/Airtel number).
  /// [BdAppsService.errorMessage] holds the user-facing reason.
  invalidNumber,
}

/// Holds the BD Apps side of the Profile tab and Subscription Offer screens.
class BdAppsService extends ChangeNotifier {
  BdAppsService({
    required BdAppsApiClient apiClient,
    SmsApiClient? smsApiClient,
    String? initialBdMobile,
  }) : _bdMobile = initialBdMobile {
    _apiClient = apiClient;
    _smsApiClient = smsApiClient;
  }

  late final BdAppsApiClient _apiClient;
  late final SmsApiClient? _smsApiClient;

  String? _bdMobile;
  String? get bdMobile => _bdMobile;

  /// Pending OTP reference number received from BD Apps after requesting OTP.
  String? pendingReferenceNo;

  /// Most recent server responses.
  SendOtpResponse? lastSendOtpResponse;
  VerifyOtpResponse? lastVerifyOtpResponse;
  SubscribeResponse? lastSubscribeResponse;
  SendSmsResponse? lastSendSmsResponse;
  CheckSubscriptionResponse? lastCheckSubscriptionResponse;
  UnsubscribeResponse? lastUnsubscribeResponse;

  /// Current subscription state machine status.
  SubscriptionState subscriptionState = SubscriptionState.idle;

  /// Last-known subscription lifecycle state (e.g. `"REGISTERED"` / `"UNREGISTERED"` / `"PENDING"`).
  String? subscriptionStatus;

  bool isSendingOtp = false;
  bool isVerifyingOtp = false;
  bool isRequestingSubscription = false;
  bool isSendingSms = false;
  bool isCheckingSubscription = false;
  bool isUnsubscribing = false;

  /// Remaining seconds in active polling loop (for UI countdown).
  int pollingSecondsRemaining = 0;

  String? errorMessage;

  /// Mirrors a Firestore-side `bdMobile` update into in-memory state.
  void updateBdMobile(String? value) {
    final normalised = (value == null || value.isEmpty) ? null : value;
    if (normalised == _bdMobile) return;
    _bdMobile = normalised;
    notifyListeners();
  }

  /// Convenience: `true` when a BD mobile is linked.
  bool get hasBdMobile => _bdMobile != null && _bdMobile!.isNotEmpty;

  /// Convenience: `true` when subscription is confirmed registered.
  bool get isRegistered =>
      subscriptionStatus?.toUpperCase() == 'REGISTERED' ||
      subscriptionState == SubscriptionState.registered;

  /// Resets all in-memory user-specific BD Apps state upon sign out or account deletion.
  void reset() {
    _bdMobile = null;
    subscriptionState = SubscriptionState.idle;
    subscriptionStatus = null;
    pendingReferenceNo = null;
    lastSendOtpResponse = null;
    lastVerifyOtpResponse = null;
    lastSubscribeResponse = null;
    lastSendSmsResponse = null;
    lastCheckSubscriptionResponse = null;
    lastUnsubscribeResponse = null;
    errorMessage = null;
    pollingSecondsRemaining = 0;
    notifyListeners();
  }

  /// Requests direct carrier subscription for Robi/Airtel numbers, followed by
  /// a 5-second polling loop up to 60 seconds.
  Future<bool> requestSubscription({
    required String mobileNumber,
    Duration pollInterval = const Duration(seconds: 5),
    Duration maxPollDuration = const Duration(seconds: 60),
  }) async {
    final validationError = BdMobileValidator.validateRobiAirtel(mobileNumber);
    if (validationError != null) {
      errorMessage = validationError;
      subscriptionState = SubscriptionState.failed;
      notifyListeners();
      return false;
    }

    final normalized = BdMobileValidator.normalize(mobileNumber);
    _bdMobile = normalized;
    isRequestingSubscription = true;
    subscriptionState = SubscriptionState.requesting;
    errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiClient.subscribe(userMobile: normalized);
      lastSubscribeResponse = response;

      if (response.isRegistered || response.isAlreadyRegistered) {
        subscriptionStatus = 'REGISTERED';
        subscriptionState = SubscriptionState.registered;
        isRequestingSubscription = false;
        notifyListeners();
        return true;
      }

      if (response.isPending || response.isRequestAccepted) {
        subscriptionState = SubscriptionState.pending;
        subscriptionStatus = 'PENDING';
        notifyListeners();

        // Start carrier status polling
        final totalSeconds = maxPollDuration.inSeconds;
        final intervalSeconds = pollInterval.inSeconds.clamp(1, 60);
        final maxAttempts = (totalSeconds / intervalSeconds).ceil();

        for (var attempt = 1; attempt <= maxAttempts; attempt++) {
          pollingSecondsRemaining =
              totalSeconds - ((attempt - 1) * intervalSeconds);
          notifyListeners();

          await Future<void>.delayed(pollInterval);

          // Query carrier status
          await refreshSubscriptionStatus();

          if (subscriptionStatus?.toUpperCase() == 'REGISTERED') {
            subscriptionState = SubscriptionState.registered;
            isRequestingSubscription = false;
            pollingSecondsRemaining = 0;
            notifyListeners();
            return true;
          }

          if (subscriptionStatus?.toUpperCase() == 'UNREGISTERED' &&
              attempt > 1) {
            // Explicit rejection
            subscriptionState = SubscriptionState.failed;
            errorMessage = 'Subscription was cancelled or declined by carrier.';
            isRequestingSubscription = false;
            pollingSecondsRemaining = 0;
            notifyListeners();
            return false;
          }
        }

        // Timed out polling
        subscriptionState = SubscriptionState.failed;
        errorMessage =
            'Confirmation timed out. If you confirmed the carrier prompt, tap Refresh Status.';
        return false;
      }

      subscriptionState = SubscriptionState.failed;
      errorMessage =
          response.statusDetail ??
          response.error ??
          'Failed to initiate subscription.';
      return false;
    } on DioException catch (e) {
      subscriptionState = SubscriptionState.failed;
      errorMessage = _messageForDioException(e);
      return false;
    } catch (e) {
      subscriptionState = SubscriptionState.failed;
      errorMessage = 'Something went wrong: $e';
      return false;
    } finally {
      isRequestingSubscription = false;
      pollingSecondsRemaining = 0;
      notifyListeners();
    }
  }

  /// Checks whether [mobileNumber] is already an active BD Apps subscriber
  /// *before* an OTP is requested, so the app can skip the OTP round-trip
  /// entirely for numbers that are already paying subscribers (of this or a
  /// prior MediTrack account) and give the user accurate messaging instead
  /// of silently sending an SMS they don't need.
  ///
  /// On [BdNumberCheckResult.alreadyActive], the registered/bdMobile state
  /// is already applied — callers just need to refresh entitlement and stop.
  /// On [BdNumberCheckResult.notRegistered] (including a failed status
  /// lookup, which shouldn't block the flow), callers should proceed to
  /// [sendOtp] as normal; `sendOtp`/`send_otp.php` re-validates regardless.
  Future<BdNumberCheckResult> checkNumberBeforeOtp({
    required String mobileNumber,
  }) async {
    final validationError = BdMobileValidator.validateRobiAirtel(mobileNumber);
    if (validationError != null) {
      errorMessage = validationError;
      notifyListeners();
      return BdNumberCheckResult.invalidNumber;
    }

    final normalized = BdMobileValidator.normalize(mobileNumber);
    isCheckingSubscription = true;
    errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiClient.checkSubscription(
        userMobile: normalized,
      );
      lastCheckSubscriptionResponse = response;

      if (response.isAlreadyActive) {
        _bdMobile = normalized;
        subscriptionStatus = 'REGISTERED';
        subscriptionState = SubscriptionState.registered;
        return BdNumberCheckResult.alreadyActive;
      }

      return BdNumberCheckResult.notRegistered;
    } catch (e) {
      // A failed status lookup shouldn't block subscribing — fall through
      // to the normal OTP flow, which will surface a real error if the
      // number itself is unreachable.
      debugPrint('BD Apps pre-check notice: $e');
      return BdNumberCheckResult.notRegistered;
    } finally {
      isCheckingSubscription = false;
      notifyListeners();
    }
  }

  /// Requests a subscription OTP from BD Apps for the target mobile number.
  Future<bool> sendOtp({required String mobileNumber}) async {
    isSendingOtp = true;
    errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiClient.sendOtp(userMobile: mobileNumber);
      lastSendOtpResponse = response;
      if (response.isAlreadyRegistered) {
        _bdMobile = mobileNumber;
        subscriptionStatus = 'REGISTERED';
        subscriptionState = SubscriptionState.registered;
        return true;
      }
      if (response.isSuccess && response.referenceNo != null) {
        pendingReferenceNo = response.referenceNo;
        _bdMobile = mobileNumber;
        return true;
      }
      if (response.statusCode == 'E1342' ||
          (response.statusDetail ?? '').toLowerCase().contains('blacklisted')) {
        errorMessage =
            'This number is not whitelisted in BD Apps. Please add it to "Test Numbers" in developer.bdapps.com.';
        return false;
      }
      errorMessage =
          response.statusDetail ??
          response.error ??
          'Failed to send subscription OTP.';
      return false;
    } on DioException catch (e) {
      errorMessage = _messageForDioException(e);
      return false;
    } catch (_) {
      errorMessage = 'Something went wrong. Please try again.';
      return false;
    } finally {
      isSendingOtp = false;
      notifyListeners();
    }
  }

  /// Verifies the OTP code for subscription.
  Future<bool> verifyOtp({required String otp}) async {
    final refNo = pendingReferenceNo;
    if (refNo == null || refNo.isEmpty) {
      errorMessage = 'No pending OTP session found. Please request OTP again.';
      notifyListeners();
      return false;
    }

    isVerifyingOtp = true;
    errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiClient.verifyOtp(referenceNo: refNo, otp: otp);
      lastVerifyOtpResponse = response;
      if (response.isSuccess || response.isSubscribed) {
        subscriptionStatus = 'REGISTERED';
        subscriptionState = SubscriptionState.registered;
        pendingReferenceNo = null;
        return true;
      }
      errorMessage =
          response.statusDetail ?? response.error ?? 'Failed to verify OTP.';
      return false;
    } on DioException catch (e) {
      errorMessage = _messageForDioException(e);
      return false;
    } catch (_) {
      errorMessage = 'Something went wrong. Please try again.';
      return false;
    } finally {
      isVerifyingOtp = false;
      notifyListeners();
    }
  }

  /// Re-fetches the backend's view of the linked mobile's subscription status.
  Future<void> refreshSubscriptionStatus() async {
    final mobile = _bdMobile;
    if (mobile == null || mobile.isEmpty) return;

    isCheckingSubscription = true;
    errorMessage = null;
    notifyListeners();

    try {
      final subId = lastVerifyOtpResponse?.subscriberId ??
          lastCheckSubscriptionResponse?.subscriberId ??
          lastSendOtpResponse?.subscriberId;

      final CheckSubscriptionResponse response;
      if (subId != null && subId.isNotEmpty) {
        response = await _apiClient.verifySubscriber(subscriberId: subId);
      } else {
        response = await _apiClient.checkSubscription(userMobile: mobile);
      }
      lastCheckSubscriptionResponse = response;

      if (response.isAlreadyActive) {
        subscriptionStatus = 'REGISTERED';
        subscriptionState = SubscriptionState.registered;
      } else if (response.subscriptionStatus?.toUpperCase() == 'UNREGISTERED' &&
          response.statusCode != 'E1951') {
        subscriptionStatus = 'UNREGISTERED';
        subscriptionState = SubscriptionState.idle;
      }
    } on DioException catch (e) {
      errorMessage = _messageForDioException(e);
    } catch (_) {
      errorMessage = 'Something went wrong. Please try again.';
    } finally {
      isCheckingSubscription = false;
      notifyListeners();
    }
  }

  /// Manually unregisters the linked mobile. Returns `true` if BD Apps confirms cancellation.
  Future<bool> unsubscribe() async {
    final mobile = _bdMobile;
    if (mobile == null || mobile.isEmpty) {
      errorMessage = 'No linked BD mobile number found.';
      notifyListeners();
      return false;
    }

    isUnsubscribing = true;
    errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiClient.unsubscribe(
        userMobile: mobile,
        subscriberId:
            lastSendOtpResponse?.subscriberId ??
            lastCheckSubscriptionResponse?.subscriberId,
        referenceNo: pendingReferenceNo ?? lastSendOtpResponse?.referenceNo,
      );
      lastUnsubscribeResponse = response;
      if (response.isSuccess) {
        subscriptionStatus = response.subscriptionStatus ?? 'UNREGISTERED';
        subscriptionState = SubscriptionState.idle;
        return true;
      }
      errorMessage =
          response.error ??
          response.statusDetail ??
          'Failed to cancel subscription via BD Apps (status: ${response.statusCode ?? 'unknown'}).';
      return false;
    } on DioException catch (e) {
      errorMessage = _messageForDioException(e);
      return false;
    } catch (_) {
      errorMessage = 'Something went wrong. Please try again.';
      return false;
    } finally {
      isUnsubscribing = false;
      notifyListeners();
    }
  }

  /// Sends a single outbound SMS via the BD Apps gateway.
  Future<bool> sendSms({required String message}) async {
    final mobile = _bdMobile;
    if (mobile == null || mobile.isEmpty) return false;

    isSendingSms = true;
    errorMessage = null;
    notifyListeners();

    try {
      if (_smsApiClient == null) {
        // In AppsPro integration, outbound SMS notifications are handled by the
        // carrier platform. Verify connectivity against AppsPro status instead.
        final response = await _apiClient.checkSubscription(userMobile: mobile);
        lastCheckSubscriptionResponse = response;
        lastSendSmsResponse = SendSmsResponse(
          success: true,
          address: mobile,
          message: message,
          statusCode: 'S1000',
          statusDetail: 'AppsPro verified connection for $mobile',
        );
        return true;
      }

      final response = await _smsApiClient.sendSms(
        phoneNumber: mobile,
        message: message,
      );
      lastSendSmsResponse = response;
      if (response.isSuccess) return true;
      errorMessage =
          response.statusDetail ?? response.error ?? 'Failed to send SMS.';
      return false;
    } on DioException catch (e) {
      final parsed = _tryParseSmsError(e);
      if (parsed != null) {
        lastSendSmsResponse = parsed;
        errorMessage =
            parsed.statusDetail ?? parsed.error ?? 'Failed to send SMS.';
      } else {
        errorMessage = _messageForDioException(e);
      }
      return false;
    } catch (_) {
      errorMessage = 'Something went wrong. Please try again.';
      return false;
    } finally {
      isSendingSms = false;
      notifyListeners();
    }
  }

  String _messageForDioException(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
      case DioExceptionType.connectionError:
        return "Couldn't reach the server. Check your connection.";
      case DioExceptionType.badResponse:
        final status = e.response?.statusCode;
        return status != null
            ? 'Server returned HTTP $status.'
            : 'Server returned an error.';
      case DioExceptionType.cancel:
        return 'Request cancelled.';
      case DioExceptionType.badCertificate:
        return 'Server certificate could not be verified.';
      case DioExceptionType.unknown:
        return 'Network error. Please try again.';
    }
  }

  SendSmsResponse? _tryParseSmsError(DioException e) {
    final body = e.response?.data;
    if (body is! Map<String, dynamic>) return null;
    try {
      return SendSmsResponse.fromJson(body);
    } catch (_) {
      return null;
    }
  }
}
