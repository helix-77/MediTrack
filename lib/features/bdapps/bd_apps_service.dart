import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'data/bd_apps_api_client.dart';
import 'data/models/check_subscription_response.dart';
import 'data/models/send_sms_response.dart';
import 'data/models/unsubscribe_response.dart';
import 'data/sms_api_client.dart';

/// Holds the BD Apps side of the Profile tab's SMS / Subscribe cards.
///
/// Replaces the old `AuthProvider`: the BD Apps OTP login flow has been
/// removed, so this provider no longer carries `AuthStatus` / `LoginStep`
/// / `pendingPhoneNumber` / `pendingReferenceNo`. The provider is fed by
/// Firebase auth + Firestore (the `bdMobile` field on the user profile)
/// and exposes only the actions the profile UI needs.
class BdAppsService extends ChangeNotifier {
  BdAppsService({
    required BdAppsApiClient apiClient,
    required SmsApiClient smsApiClient,
    String? initialBdMobile,
  })  : _bdMobile = initialBdMobile {
    // Field-initialize the API clients via assignment so we can keep the
    // named-parameter `apiClient` / `smsApiClient` ergonomics without
    // triggering prefer_initializing_formals.
    _apiClient = apiClient;
    _smsApiClient = smsApiClient;
  }

  late final BdAppsApiClient _apiClient;
  late final SmsApiClient _smsApiClient;

  /// BD-format mobile number used as the BD Apps `subscriberId`. Mirrors
  /// `UserProfile.bdMobile` so the cards can react to Firestore updates
  /// without holding their own state.
  String? _bdMobile;
  String? get bdMobile => _bdMobile;

  /// Most recent server response for a `sendSms` call. Populated on every
  /// attempt regardless of branch so the UI can read `statusCode` /
  /// `statusDetail` / `error`.
  SendSmsResponse? lastSendSmsResponse;

  /// Most recent server response for a `checkSubscription` call.
  CheckSubscriptionResponse? lastCheckSubscriptionResponse;

  /// Most recent server response for an `unsubscribe` call.
  UnsubscribeResponse? lastUnsubscribeResponse;

  /// Last-known subscription lifecycle state (e.g. `"REGISTERED"` /
  /// `"UNREGISTERED"`). Only updated when a backend call returns a
  /// non-empty value — local `unsubscribe` failures don't overwrite the
  /// last known good state.
  String? subscriptionStatus;

  bool isSendingSms = false;
  bool isCheckingSubscription = false;
  bool isUnsubscribing = false;

  String? errorMessage;

  /// Mirrors a Firestore-side `bdMobile` update into in-memory state so
  /// the cards re-render. Empty string is normalised to `null` (clearing
  /// the link from the profile editor).
  void updateBdMobile(String? value) {
    final normalised = (value == null || value.isEmpty) ? null : value;
    if (normalised == _bdMobile) return;
    _bdMobile = normalised;
    notifyListeners();
  }

  /// Convenience: `true` when a BD mobile is linked.
  bool get hasBdMobile =>
      _bdMobile != null && _bdMobile!.isNotEmpty;

  /// Re-fetches the backend's view of the linked mobile's subscription
  /// status. No-op when no mobile is linked.
  Future<void> refreshSubscriptionStatus() async {
    final mobile = _bdMobile;
    if (mobile == null || mobile.isEmpty) return;

    isCheckingSubscription = true;
    errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiClient.checkSubscription(userMobile: mobile);
      lastCheckSubscriptionResponse = response;
      final status = response.subscriptionStatus;
      if (status != null && status.isNotEmpty) {
        subscriptionStatus = status;
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

  /// Manually unregisters the linked mobile. Mirrors `logout`'s
  /// best-effort semantics from the old AuthProvider: a transport
  /// failure surfaces an `errorMessage` but does not throw, so the UI
  /// can show whatever feedback is available.
  Future<void> unsubscribe() async {
    final mobile = _bdMobile;
    if (mobile == null || mobile.isEmpty) return;

    isUnsubscribing = true;
    errorMessage = null;
    notifyListeners();

    try {
      final response = await _apiClient.unsubscribe(userMobile: mobile);
      lastUnsubscribeResponse = response;
      final status = response.subscriptionStatus;
      if (status != null && status.isNotEmpty) {
        subscriptionStatus = status;
      } else {
        subscriptionStatus = 'UNREGISTERED';
      }
    } on DioException catch (e) {
      errorMessage = _messageForDioException(e);
    } catch (_) {
      errorMessage = 'Something went wrong. Please try again.';
    } finally {
      isUnsubscribing = false;
      notifyListeners();
    }
  }

  /// Sends a single outbound SMS via the BD Apps gateway
  /// (`POST send_sms.php`). Returns `true` when the gateway acknowledged
  /// the send. No-op when no mobile is linked.
  Future<bool> sendSms({required String message}) async {
    final mobile = _bdMobile;
    if (mobile == null || mobile.isEmpty) return false;

    isSendingSms = true;
    errorMessage = null;
    notifyListeners();

    try {
      final response = await _smsApiClient.sendSms(
        phoneNumber: mobile,
        message: message,
      );
      lastSendSmsResponse = response;
      if (response.isSuccess) return true;
      errorMessage = response.statusDetail ??
          response.error ??
          'Failed to send SMS.';
      return false;
    } on DioException catch (e) {
      // Dio throws on non-2xx by default, but the body is still attached
      // via `e.response`. Try to surface the backend's parsed JSON when
      // it looks like a valid SendSmsResponse so the UI banner shows the
      // real reason (e.g. "Invalid mobile number") instead of a generic
      // connection-failed message.
      final parsed = _tryParseSmsError(e);
      if (parsed != null) {
        lastSendSmsResponse = parsed;
        errorMessage = parsed.statusDetail ??
            parsed.error ??
            'Failed to send SMS.';
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

  /// Maps a [DioException] into something the UI can surface. Network /
  /// timeout failures get a connection-lost message; HTTP errors (5xx,
  /// 4xx with a body) include the status code so the user can tell
  /// "server is broken" from "I can't reach the server".
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

  /// Tries to parse the body of a failed Dio request as a
  /// [SendSmsResponse]. Returns `null` if the body isn't a JSON object
  /// (e.g. empty body, HTML error page from a proxy in front of the
  /// backend) so the caller can fall back to a generic message.
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