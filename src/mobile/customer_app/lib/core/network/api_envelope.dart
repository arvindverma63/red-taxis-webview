import 'api_exception.dart';

/// Unwraps the v2 response envelope `{ success, data, errors }`.
///
/// v2 endpoints wrap payloads; v1 endpoints return raw data. Use [unwrapV2] for
/// `/api/v2/*` and pass the raw body straight through for v1.
T unwrapV2<T>(dynamic body, T Function(dynamic data) parse) {
  if (body is Map<String, dynamic>) {
    final success = body['success'];
    if (success == false) {
      final errors = body['errors'];
      final msg = (errors is List && errors.isNotEmpty)
          ? errors.first.toString()
          : 'Request failed.';
      throw ApiException(msg);
    }
    if (body.containsKey('data')) return parse(body['data']);
  }
  // Already-unwrapped or v1 shape.
  return parse(body);
}

List<R> parseList<R>(dynamic data, R Function(Map<String, dynamic>) item) {
  if (data is List) {
    return data
        .whereType<Map<String, dynamic>>()
        .map(item)
        .toList(growable: false);
  }
  return const [];
}
