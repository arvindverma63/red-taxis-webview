/// Form validators shared across the auth screens. Each returns an error string
/// or null when valid, matching [FormFieldValidator]'s contract.
abstract final class AuthValidators {
  static final _emailRe = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
  static final _phoneRe = RegExp(r'^[0-9+()\s-]{7,}$');

  static String? required(String? v, {String field = 'This field'}) {
    if (v == null || v.trim().isEmpty) return '$field is required.';
    return null;
  }

  static String? email(String? v) {
    final r = required(v, field: 'Email');
    if (r != null) return r;
    if (!_emailRe.hasMatch(v!.trim())) return 'Enter a valid email address.';
    return null;
  }

  /// Sign-in identifier: accepts either an email or a username/account number.
  static String? usernameOrEmail(String? v) =>
      required(v, field: 'Email or username');

  static String? fullName(String? v) {
    final r = required(v, field: 'Full name');
    if (r != null) return r;
    if (v!.trim().length < 2) return 'Enter your full name.';
    return null;
  }

  static String? phone(String? v) {
    final r = required(v, field: 'Phone number');
    if (r != null) return r;
    if (!_phoneRe.hasMatch(v!.trim())) return 'Enter a valid phone number.';
    return null;
  }

  static String? password(String? v) {
    if (v == null || v.isEmpty) return 'Password is required.';
    if (v.length < 8) return 'Password must be at least 8 characters.';
    return null;
  }

  /// Confirm-password validator bound to the source field's current value.
  static String? Function(String?) confirmPassword(String Function() other) =>
      (v) {
        if (v == null || v.isEmpty) return 'Confirm your password.';
        if (v != other()) return 'Passwords do not match.';
        return null;
      };
}
