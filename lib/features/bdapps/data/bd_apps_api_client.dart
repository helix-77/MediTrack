import 'apps_pro_api_client.dart';

/// Client for MediTrack's subscription & carrier billing backend.
///
/// Backed by MediTrack's authenticated Firebase proxy, which integrates with
/// AppsPro and BDApps without exposing the AppsPro bearer secret to Flutter.
class BdAppsApiClient extends AppsProApiClient {
  BdAppsApiClient(super.dio, {super.idTokenProvider});
}
