class AppConfig {
  static const String appName = 'Red Taxi';
  static const String apiBaseUrl = 'https://staging-api.redtaxi.co.uk';
  static const String webviewBaseUrl = 'https://red-taxis-webview-kktx.vercel.app';
  static const String defaultTenantId = 'org_ace_taxis';
  static const String defaultTenantKey = 'demo_key';

  // Webview Sub-Routes
  static const String webviewBookRoute = '/#/book';
  static const String webviewActivityRoute = '/#/activity';
  static const String webviewActiveRideRoute = '/#/active-ride';
  static const String webviewProfileRoute = '/#/profile';
  static const String webviewSavedPlacesRoute = '/#/saved-places';

  // API Endpoints
  static const String loginEndpoint = '/api/v2/customer-auth/login';
  static const String legacyLoginEndpoint = '/api/UserProfile/Login';
  static const String registerCustomerEndpoint = '/api/v2/customer-auth/register-customer';
  static const String tenantInfoEndpoint = '/api/v2/public/tenant-info';
  static const String quoteEndpoint = '/api/v2/pricing/quote';
  static const String searchAddressEndpoint = '/api/v2/address/search';
  static const String myBookingsEndpoint = '/api/v2/customers/me/bookings';
  static const String createBookingEndpoint = '/api/DriverApp/CreateBooking';

  // Storage Keys
  static const String keyAuthToken = 'cust_auth_token';
  static const String keyRefreshToken = 'cust_refresh_token';
  static const String keyTenantId = 'cust_tenant_id';
  static const String keyTenantKey = 'cust_tenant_key';
  static const String keyTenantBranding = 'cust_tenant_branding';
  static const String keyThemeMode = 'cust_theme_mode';
  static const String keyUserEmail = 'cust_user_email';
  static const String keyUserName = 'cust_user_name';
  static const String keyUserPhone = 'cust_user_phone';
}
