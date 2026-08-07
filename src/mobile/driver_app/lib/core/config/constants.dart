class AppConfig {
  // Toggle to false for production release
  static const bool useDevUrl = true;

  // 10.0.2.2 points to localhost of the host machine from the Android emulator.
  // Use http://localhost:4200 if compiling for physical device on the same local server.
  static const String devBaseUrl = 'https://red-taxis-webview.vercel.app';
  static const String prodBaseUrl = 'https://red-taxis-webview.vercel.app';

  static String get webviewBaseUrl => useDevUrl ? devBaseUrl : prodBaseUrl;

  static String get bookingsUrl => '$webviewBaseUrl/bookings';
  static String get profileUrl => '$webviewBaseUrl/profile';
  static String get availabilityUrl => '$webviewBaseUrl/availability';
}
