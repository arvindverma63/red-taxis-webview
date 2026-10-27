import 'dart:async';

import 'package:flutter/material.dart';

import '../config/app_config.dart';
import '../widgets/confirm_dialog.dart';
import 'app_update_service.dart';

/// Wraps the app and, shortly after launch and when the app returns to the
/// foreground (at most every few hours), asks the store whether a newer build
/// exists. If so it shows an "Update available" dialog; "Update now" opens the
/// store update flow.
class AppUpdateGate extends StatefulWidget {
  const AppUpdateGate({
    super.key,
    required this.navigatorKey,
    required this.child,
    this.service = const AppUpdateService(),
  });

  /// The router's navigator, used to show the dialog above the current screen.
  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;
  final AppUpdateService service;

  @override
  State<AppUpdateGate> createState() => _AppUpdateGateState();
}

class _AppUpdateGateState extends State<AppUpdateGate>
    with WidgetsBindingObserver {
  static const _recheckAfter = Duration(hours: 6);

  Timer? _startupTimer;
  DateTime? _lastCheck;
  bool _showing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Let the first screen settle before interrupting with a dialog.
    _startupTimer = Timer(const Duration(seconds: 4), _maybeCheck);
  }

  @override
  void dispose() {
    _startupTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _maybeCheck();
  }

  Future<void> _maybeCheck() async {
    if (!mounted || _showing) return;
    final last = _lastCheck;
    if (last != null && DateTime.now().difference(last) < _recheckAfter) return;
    _lastCheck = DateTime.now();

    final update = await widget.service.check();
    if (update == null || !mounted) return;
    final ctx = widget.navigatorKey.currentContext;
    if (ctx == null || !ctx.mounted) return;

    _showing = true;
    final brand = AppConfig.fromEnvironment().brandName;
    final accept = await showConfirmDialog(
      ctx,
      title: 'Update available',
      message:
          'A new version of $brand is available with improvements and fixes. '
          'Update now to keep everything working smoothly.',
      confirmLabel: 'Update now',
      cancelLabel: 'Later',
    );
    _showing = false;
    if (accept) await widget.service.start(update);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
