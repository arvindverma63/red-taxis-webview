import 'dart:developer' as developer;

import 'package:dio/dio.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Structured, greppable logging for every HTTP call the app makes.
///
/// Why this exists: the app previously logged nothing, so any network failure
/// was invisible without a rebuild. Every request/response/error now emits a
/// single tagged line (filter logcat with `RTX-API`) AND a Sentry breadcrumb,
/// and server/unknown failures are captured to Sentry with full request
/// context. One interceptor wires this into the shared [Dio], so it covers
/// every repository (address, auth, booking, quote, profile, tracking).
///
/// Format (stable, parseable):
///   REQ  {METHOD} {path} auth=Y|N
///   RES  {METHOD} {path} -> {status} {ms}ms
///   ERR  {METHOD} {path} -> {status|type} code={CODE} msg="{message}" {ms}ms
class NetworkLog {
  const NetworkLog._();

  static const String tag = 'RTX-API';
  static const String _startKey = 'rtx_start_ms';

  static void markStart(RequestOptions o) {
    o.extra[_startKey] = DateTime.now().millisecondsSinceEpoch;
  }

  static int _elapsedMs(RequestOptions o) {
    final start = o.extra[_startKey];
    if (start is int) return DateTime.now().millisecondsSinceEpoch - start;
    return -1;
  }

  static void request(RequestOptions o) {
    final hasAuth = o.headers['Authorization'] != null;
    developer.log('REQ ${o.method} ${o.uri.path} auth=${hasAuth ? 'Y' : 'N'}',
        name: tag);
    _breadcrumb(SentryLevel.info, {
      'method': o.method,
      'path': o.uri.path,
      'has_auth': hasAuth,
    });
  }

  static void response(Response<dynamic> res) {
    final o = res.requestOptions;
    developer.log(
        'RES ${o.method} ${o.uri.path} -> ${res.statusCode} ${_elapsedMs(o)}ms',
        name: tag);
    _breadcrumb(SentryLevel.info, {
      'method': o.method,
      'path': o.uri.path,
      'status': res.statusCode,
      'ms': _elapsedMs(o),
    });
  }

  /// Logs a failed call. [code]/[message] are the resolved structured values
  /// (post-mapping) so the line matches what the user/app actually saw.
  static void error(DioException err, {String? code, String? message}) {
    final o = err.requestOptions;
    final status = err.response?.statusCode;
    final statusOrType = status?.toString() ?? err.type.name;
    final msg = message ?? err.message ?? err.type.name;
    developer.log(
      'ERR ${o.method} ${o.uri.path} -> $statusOrType code=${code ?? '-'} '
      'msg="$msg" ${_elapsedMs(o)}ms',
      name: tag,
      level: 1000, // SEVERE
      error: err,
    );
    _breadcrumb(SentryLevel.error, {
      'method': o.method,
      'path': o.uri.path,
      'status': status,
      'code': code,
      'msg': msg,
    });

    // Capture only what a human should investigate: server-side faults and
    // genuinely unknown failures. User 4xx and offline/timeout are expected
    // and stay as breadcrumbs (no noise in Sentry issues).
    final isServer = status != null && status >= 500;
    final isUnknown =
        err.response == null && err.type == DioExceptionType.unknown;
    if (isServer || isUnknown) {
      _capture(err, status: status, code: code, path: o.uri.path, method: o.method);
    }
  }

  // ── Sentry plumbing (best-effort; never throws into the request path) ──────

  static void _breadcrumb(SentryLevel level, Map<String, dynamic> data) {
    try {
      Sentry.addBreadcrumb(Breadcrumb(
        type: 'http',
        category: 'http',
        level: level,
        data: data,
      ));
    } catch (_) {/* Sentry not initialised / inert — ignore */}
  }

  static void _capture(
    DioException err, {
    int? status,
    String? code,
    required String path,
    required String method,
  }) {
    try {
      Sentry.captureException(
        err,
        stackTrace: err.stackTrace,
        withScope: (scope) {
          scope.setTag('http.method', method);
          scope.setTag('http.path', path);
          if (status != null) scope.setTag('http.status', '$status');
          if (code != null) scope.setTag('api.code', code);
        },
      );
    } catch (_) {/* inert — ignore */}
  }
}
