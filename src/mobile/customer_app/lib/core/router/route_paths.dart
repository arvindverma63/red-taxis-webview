/// Central route paths + names. Features reference these constants so screens
/// can navigate to each other without importing each other's code, and the
/// router assembles each feature's `List<RouteBase>` against the same paths.
abstract final class Routes {
  // Auth / onboarding
  static const splash = '/';
  static const onboarding = '/onboarding';
  static const signIn = '/sign-in';
  static const signUp = '/sign-up';
  static const forgotPassword = '/forgot-password';
  static const resetPassword = '/reset-password'; // deep link ?email=&token=
  static const verifyEmail = '/verify-email'; // deep link ?email=&token=

  // Main shell tabs
  static const home = '/home';
  static const activity = '/activity';
  static const profile = '/profile';

  // Booking flow
  static const addressSearch = '/booking/address';
  static const bookingReview = '/booking/review'; // vehicle + quote + schedule
  static const paymentMethod = '/booking/payment-method';
  static const bookingConfirm = '/booking/confirm';

  // Tracking
  static const tracking = '/tracking'; // /tracking/:bookingId

  // Activity detail
  static const bookingDetail = '/activity'; // /activity/:bookingId

  // Profile sub-pages
  static const savedAddresses = '/profile/addresses';
  static const paymentMethods = '/profile/payment-methods';
  static const settings = '/profile/settings';
  static const notifications = '/profile/notifications';
}
