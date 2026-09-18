import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';

class NavigationState {
  final int selectedIndex;
  final String? customRoute;
  final String? customTitle;
  final Map<String, String>? customParams;

  const NavigationState({
    this.selectedIndex = 0,
    this.customRoute,
    this.customTitle,
    this.customParams,
  });

  bool get hasCustomRoute => customRoute != null && customRoute!.isNotEmpty;

  NavigationState copyWith({
    int? selectedIndex,
    String? customRoute,
    String? customTitle,
    Map<String, String>? customParams,
    bool clearCustomRoute = false,
  }) {
    return NavigationState(
      selectedIndex: selectedIndex ?? this.selectedIndex,
      customRoute: clearCustomRoute ? null : (customRoute ?? this.customRoute),
      customTitle: clearCustomRoute ? null : (customTitle ?? this.customTitle),
      customParams: clearCustomRoute ? null : (customParams ?? this.customParams),
    );
  }
}

class NavigationNotifier extends StateNotifier<NavigationState> {
  NavigationNotifier() : super(const NavigationState());

  void setTabIndex(int index) {
    state = state.copyWith(
      selectedIndex: index,
      clearCustomRoute: true,
    );
  }

  void openCustomWebView({
    required String route,
    required String title,
    Map<String, String>? params,
  }) {
    state = state.copyWith(
      customRoute: route,
      customTitle: title,
      customParams: params,
    );
  }

  void closeCustomWebView() {
    state = state.copyWith(clearCustomRoute: true);
  }
}

final navigationProvider =
    StateNotifierProvider<NavigationNotifier, NavigationState>((ref) {
  return NavigationNotifier();
});

/// Central registry for tab WebViewController instances to enable intelligent back navigation
class WebviewRegistry {
  static final Map<int, WebViewController> tabControllers = {};
  static WebViewController? customController;

  static void registerTab(int index, WebViewController controller) {
    tabControllers[index] = controller;
  }

  static void unregisterTab(int index) {
    tabControllers.remove(index);
  }

  static void registerCustom(WebViewController? controller) {
    customController = controller;
  }

  static void clear() {
    tabControllers.clear();
    customController = null;
  }
}


