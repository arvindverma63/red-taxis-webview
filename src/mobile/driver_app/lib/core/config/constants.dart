class AppConfig {
  // Toggle to false for production release
  static const bool useDevUrl = true;

  // 10.0.2.2 points to localhost of the host machine from the Android emulator.
  // Use http://localhost:4200 if compiling for physical device on the same local server.
  static const String devBaseUrl = 'https://red-taxis-webview.vercel.app';
  static const String prodBaseUrl = 'https://red-taxis-webview.vercel.app';

  static String get webviewBaseUrl => useDevUrl ? devBaseUrl : prodBaseUrl;

  // Default fallback Tenant configuration
  static const String defaultTenantId = 'org_red_taxis';
  static const String defaultTenantKey = 'tk_live_red_taxis_dev';
  static const String defaultFleetName = 'Red Taxis';

  // Secure Storage Keys
  static const String keyTenantId = 'tenant_id';
  static const String keyTenantKey = 'tenant_key';
  static const String keyTenantBranding = 'tenant_branding';
  static const String keyAuthToken = 'auth_token';
  static const String keyAuthEmail = 'auth_email';
  static const String keyAuthUserId = 'auth_user_id';

  // Standard Webview Routes
  static String get bookingsUrl => '$webviewBaseUrl/#/bookings';
  static String get profileUrl => '$webviewBaseUrl/#/profile';
  static String get availabilityUrl => '$webviewBaseUrl/#/availability';
  static String get expensesUrl => '$webviewBaseUrl/#/expenses';
  static String get reportsUrl => '$webviewBaseUrl/#/reports';
  static String get jobOfferUrl => '$webviewBaseUrl/#/job-offer';
  static String get createBookingUrl => '$webviewBaseUrl/#/create-booking';
}
