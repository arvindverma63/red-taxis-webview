/// Typed failure surfaced to the application layer. Repositories catch dio
/// errors and rethrow these so controllers can render a clear message.
class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode, this.code});

  /// Human-readable message safe to show the user.
  final String message;

  /// HTTP status, when the failure came from a response.
  final int? statusCode;

  /// Optional machine code from the API `errors` envelope.
  final String? code;

  bool get isUnauthorized => statusCode == 401;
  bool get isNotFound => statusCode == 404;
  bool get isNetwork => statusCode == null;

  @override
  String toString() => 'ApiException($statusCode, $code): $message';
}
