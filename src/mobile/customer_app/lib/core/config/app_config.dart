/// Tenant / brand configuration.
///
/// The app is tenant-config-driven with static defaults for Red Taxi / Ace Taxis.
/// Secrets and per-environment values can also come from `--dart-define` at build time.
class AppConfig {
  const AppConfig({
    required this.tenantOrgId,
    required this.tenantKey,
    required this.brandName,
    required this.supportPhone,
    required this.apiBaseUrl,
    required this.pusherKey,
    required this.pusherCluster,
    required this.openingHour,
    required this.closingHour,
  });

  /// The static default tenant identifier.
  static const String defaultTenantOrgId = 'org_ace_taxis';

  /// The static public tenant key required for registration and public APIs.
  static const String defaultTenantKey =
      'rtk_pub_47b2f6dc71b5dd024f7f6d23bdeb9fe2782c3ed4a46d15b7';

  /// The static default base API URL.
  static const String defaultApiBaseUrl = 'https://staging-api.redtaxi.co.uk';

  /// The static default brand name.
  static const String defaultBrandName = 'Red Taxi';

  final String tenantOrgId;
  final String tenantKey;
  final String brandName;

  /// Office / dispatch phone number in dial-able form (e.g. `+441747850888`).
  final String supportPhone;

  final String apiBaseUrl;
  final String pusherKey;
  final String pusherCluster;

  /// Operating-hours window used for out-of-hours expectation copy.
  final int openingHour;
  final int closingHour;

  /// True when [hour] (0-23, local) falls outside the configured operating window.
  bool isOutsideOperatingHours(int hour) {
    if (closingHour > openingHour) {
      return hour < openingHour || hour >= closingHour;
    }
    // Overnight window, e.g. open 06:00 → close 02:00.
    return hour >= closingHour && hour < openingHour;
  }

  /// When true, repositories fall back to local demo data on a failed API call.
  static const bool previewMocks =
      bool.fromEnvironment('PREVIEW_MOCKS', defaultValue: false);

  /// When true, map-bearing screens render a real GoogleMap.
  static const bool mapsEnabled =
      bool.fromEnvironment('MAPS_ENABLED', defaultValue: false);

  /// Sentry DSN for crash / error monitoring.
  static const String sentryDsn =
      String.fromEnvironment('SENTRY_DSN', defaultValue: '');

  /// Deployment environment tag reported to Sentry.
  static const String environment =
      String.fromEnvironment('APP_ENV', defaultValue: 'development');

  /// Resolved from `--dart-define`s with static defaults.
  factory AppConfig.fromEnvironment() {
    return const AppConfig(
      tenantOrgId: String.fromEnvironment('TENANT_ORG_ID',
          defaultValue: defaultTenantOrgId),
      tenantKey: String.fromEnvironment('TENANT_KEY',
          defaultValue: defaultTenantKey),
      brandName: String.fromEnvironment('BRAND_NAME',
          defaultValue: defaultBrandName),
      supportPhone:
          String.fromEnvironment('SUPPORT_PHONE', defaultValue: ''),
      apiBaseUrl: String.fromEnvironment('API_BASE_URL',
          defaultValue: defaultApiBaseUrl),
      pusherKey: String.fromEnvironment('PUSHER_KEY',
          defaultValue: '72a68ffd46f37a9d649a'),
      pusherCluster:
          String.fromEnvironment('PUSHER_CLUSTER', defaultValue: 'eu'),
      openingHour: int.fromEnvironment('OPENING_HOUR', defaultValue: 7),
      closingHour: int.fromEnvironment('CLOSING_HOUR', defaultValue: 22),
    );
  }
}
