import 'apps_pro_api_client.dart';

/// Client for MediTrack's subscription & carrier billing backend.
///
/// Backed by AppsPro.dev API (`/api/v1/sdk/*` endpoints) which integrates
/// directly with BDApps.
class BdAppsApiClient extends AppsProApiClient {
  BdAppsApiClient(super.dio);
}


