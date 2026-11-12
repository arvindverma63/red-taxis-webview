import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Hosts the Home tab. Navigation to Activity, Profile and the account pages
/// lives in the Home drawer (pushed routes), so there is no bottom bar.
class MainShell extends StatelessWidget {
  const MainShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) => Scaffold(body: shell);
}
