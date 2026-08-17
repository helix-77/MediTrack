import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Builds the shared [Dio] instance used by all feature API clients.
///
/// All MediTrack API clients (auth, prayer-times, etc.) take a [Dio] built
/// here so timeouts and the optional debug interceptor stay consistent.
class DioClient {
  DioClient._();

  static Dio create({required String baseUrl}) {
    final dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 35),
      ),
    );

    if (kDebugMode) {
      dio.interceptors.add(
        LogInterceptor(requestBody: false, responseBody: false),
      );
    }

    return dio;
  }
}
