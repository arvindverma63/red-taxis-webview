import 'dart:io' show Platform;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../logging/remote_logger.dart';

/// A newer build of the app is available in the store.
class AvailableUpdate {
  const AvailableUpdate({this.version, this.storeUrl, this.androidInfo});

  /// Store version name (iOS only; Play does not expose it to the app).
  final String? version;

  /// App Store page (iOS).
  final String? storeUrl;

  /// Play in-app update handle (Android).
  final AppUpdateInfo? androidInfo;
}

/// True when [store] is a newer dotted version than [current] (1.0.2 > 1.0.1).
@visibleForTesting
bool isNewerVersion(String store, String current) {
  List<int> parse(String v) => v
      .split('+')
      .first
      .split('.')
      .map((p) => int.tryParse(p.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0)
      .toList();
  final a = parse(store);
  final b = parse(current);
  final len = a.length > b.length ? a.length : b.length;
  for (var i = 0; i < len; i++) {
    final x = i < a.length ? a[i] : 0;
    final y = i < b.length ? b[i] : 0;
    if (x != y) return x > y;
  }
  return false;
}

/// Checks the store for a newer version and starts the update.
///
/// * Android: Google Play in-app updates (only works for builds installed from
///   Play — sideloaded APKs simply report no update).
/// * iOS: Apple has no in-app update API, so we look the app up on the App
///   Store and send the user to its page. This needs the app to be live, and
///   the *version name* (not just the build number) to be higher.
///
/// Every failure is swallowed: an update check must never disturb the app.
class AppUpdateService {
  const AppUpdateService();

  Future<AvailableUpdate?> check() async {
    if (kIsWeb || kDebugMode) return null;
    try {
      if (Platform.isAndroid) return await _checkAndroid();
      if (Platform.isIOS) return await _checkIos();
    } catch (e) {
      RemoteLogger.error('Update', 'Update check failed: $e');
    }
    return null;
  }

  Future<AvailableUpdate?> _checkAndroid() async {
    final info = await InAppUpdate.checkForUpdate();
    if (info.updateAvailability != UpdateAvailability.updateAvailable) {
      return null;
    }
    return AvailableUpdate(androidInfo: info);
  }

  Future<AvailableUpdate?> _checkIos() async {
    final pkg = await PackageInfo.fromPlatform();
    final res = await Dio().get<Map<String, dynamic>>(
      'https://itunes.apple.com/lookup',
      queryParameters: {'bundleId': pkg.packageName, 'country': 'gb'},
      options: Options(receiveTimeout: const Duration(seconds: 8)),
    );
    final results = res.data?['results'];
    if (results is! List || results.isEmpty) return null; // not live yet
    final app = results.first as Map<String, dynamic>;
    final storeVersion = app['version']?.toString();
    if (storeVersion == null || !isNewerVersion(storeVersion, pkg.version)) {
      return null;
    }
    return AvailableUpdate(
      version: storeVersion,
      storeUrl: app['trackViewUrl']?.toString(),
    );
  }

  /// Starts the update. Returns true if the store flow was launched.
  Future<bool> start(AvailableUpdate update) async {
    try {
      final info = update.androidInfo;
      if (info != null) {
        if (info.immediateUpdateAllowed) {
          final r = await InAppUpdate.performImmediateUpdate();
          return r == AppUpdateResult.success;
        }
        if (info.flexibleUpdateAllowed) {
          final r = await InAppUpdate.startFlexibleUpdate();
          if (r == AppUpdateResult.success) {
            await InAppUpdate.completeFlexibleUpdate();
            return true;
          }
        }
        return false;
      }
      final url = update.storeUrl;
      if (url == null) return false;
      return await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
    } catch (e) {
      RemoteLogger.error('Update', 'Update start failed: $e');
      return false;
    }
  }
}
