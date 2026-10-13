import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

/// Fire-and-forget logger that ships diagnostics to the remote log service so
/// issues on physical devices (e.g. push registration on TestFlight builds)
/// can be inspected without a debugger attached.
///
/// Never throws and never blocks the caller. Do not pass secrets: use
/// [RemoteLogger.mask] for tokens.
class RemoteLogger {
  RemoteLogger._();

  static const String _endpoint =
      'https://acetaxislogger.backendcodersindia.com/api/logs';

  static final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 8),
      sendTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 8),
      headers: {
        'accept': 'application/json',
        'Content-Type': 'application/json',
      },
    ),
  );

  static String get _platform => kIsWeb ? 'web' : defaultTargetPlatform.name;

  /// Keeps only the head and tail of a token so it is identifiable but unusable.
  static String mask(String? value) {
    if (value == null || value.isEmpty) return 'null';
    if (value.length <= 12) return '***(${value.length})';
    return '${value.substring(0, 6)}…${value.substring(value.length - 4)}(${value.length})';
  }

  static void info(String source, String message) =>
      _send('info', source, message);

  static void warn(String source, String message) =>
      _send('warning', source, message);

  static void error(String source, String message) =>
      _send('error', source, message);

  static void _send(String type, String source, String message) {
    if (kDebugMode) {
      debugPrint('[RemoteLogger][$type][$source] $message');
    }
    unawaited(_post(type, source, message));
  }

  static Future<void> _post(String type, String source, String message) async {
    try {
      final text = '[$_platform] $message';
      await _dio.post(
        _endpoint,
        data: {
          'type': type,
          'message': text.length > 1000 ? text.substring(0, 1000) : text,
          'source': source,
        },
      );
    } catch (_) {
      // Logging must never affect app behaviour.
    }
  }
}
