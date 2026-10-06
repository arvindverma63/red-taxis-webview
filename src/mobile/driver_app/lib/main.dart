import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:driver_app/core/theme/theme.dart';
import 'package:driver_app/core/notifications/notification_handler.dart';
import 'package:driver_app/features/navigation/presentation/main_shell.dart';
import 'package:driver_app/features/auth/auth.dart';
import 'package:driver_app/features/auth/presentation/login_screen.dart';
import 'package:driver_app/features/splash/presentation/splash_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:driver_app/core/notifications/notification_sound_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:driver_app/core/location/background_location_service.dart';
import 'package:driver_app/firebase_options.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    if (defaultTargetPlatform == TargetPlatform.android) {
      await Firebase.initializeApp();
    } else {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  } catch (e) {
    debugPrint("Background Firebase initializeApp error: $e");
  }
  debugPrint("================ FCM BACKGROUND MESSAGE ================");
  debugPrint("Message ID: ${message.messageId}");
  debugPrint("Title: ${message.notification?.title}");
  debugPrint("Body: ${message.notification?.body}");
  debugPrint("Data: ${message.data}");
  debugPrint("========================================================");

  try {
    await NotificationSoundService.registerNotificationChannels();
    final title = message.notification?.title ?? message.data['title'] ?? '🚕 Dispatch Notification';
    final body = message.notification?.body ?? message.data['body'] ?? message.data['message'] ?? 'New alert received';

    await NotificationSoundService.showNotification(
      title: title,
      body: body,
      data: message.data,
      id: message.notification?.hashCode ?? message.hashCode,
      speakTts: false, // On background/closed state, native Android NotificationChannel audio handles the sound!
    );
  } catch (e) {
    debugPrint("Background notification dispatch error: $e");
  }
}

// Global default channel definition for Android
const AndroidNotificationChannel channel = AndroidNotificationChannel(
  'high_importance_channel', // id
  'High Importance Notifications', // title
  description: 'This channel is used for important notifications.', // description
  importance: Importance.high,
  playSound: true,
  enableVibration: true,
);

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Initialize Firebase Messaging (FCM) on primary Flutter engine
  try {
    if (defaultTargetPlatform == TargetPlatform.android) {
      await Firebase.initializeApp();
    } else {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    final messaging = FirebaseMessaging.instance;
    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    debugPrint(
        'User notification permission status: ${settings.authorizationStatus}');

    await messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    try {
      final token = await messaging.getToken();
      debugPrint('FCM Token: $token');
    } catch (tokenErr) {
      debugPrint('FCM getToken notice (simulator/APNs unavailable): $tokenErr');
    }

    // FCM Foreground listener: show local heads-up notification with custom category sound and route immediately
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint("================ FCM FOREGROUND MESSAGE ================");
      debugPrint("Message ID: ${message.messageId}");
      debugPrint("Title: ${message.notification?.title}");
      debugPrint("Body: ${message.notification?.body}");
      debugPrint("Data: ${message.data}");
      debugPrint("========================================================");

      final mergedData = <String, dynamic>{
        ...message.data,
        if (message.notification?.title != null) 'title': message.notification!.title,
        if (message.notification?.body != null) 'body': message.notification!.body,
      };

      NotificationNavigationHandler.handlePayload(mergedData);

      final title = message.notification?.title ?? message.data['title'] ?? '🚕 Dispatch Notification';
      final body = message.notification?.body ?? message.data['body'] ?? message.data['message'] ?? 'New alert received';

      NotificationSoundService.showNotification(
        title: title,
        body: body,
        data: mergedData,
        id: message.notification?.hashCode ?? message.hashCode,
      );
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint("App opened via FCM notification: payload=${message.data}");
      final mergedData = <String, dynamic>{
        ...message.data,
        if (message.notification?.title != null) 'title': message.notification!.title,
        if (message.notification?.body != null) 'body': message.notification!.body,
      };
      NotificationNavigationHandler.handlePayload(mergedData);
    });

    final initialMessage = await messaging.getInitialMessage();
    if (initialMessage != null) {
      debugPrint("Initial FCM notification message: payload=${initialMessage.data}");
      final mergedData = <String, dynamic>{
        ...initialMessage.data,
        if (initialMessage.notification?.title != null) 'title': initialMessage.notification!.title,
        if (initialMessage.notification?.body != null) 'body': initialMessage.notification!.body,
      };
      NotificationNavigationHandler.handlePayload(mergedData);
    }
  } catch (e) {
    debugPrint('Firebase initialization notice: $e');
  }

  // 2. Initialize local notifications and register sound-specific channels
  try {
    // Create Android High Importance & Categorized Notification Channels
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
    await NotificationSoundService.registerNotificationChannels();

    // Initialize local notifications with explicit iOS/Darwin permissions
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );

    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        debugPrint("Local Notification Clicked: payload=${response.payload}");
        if (response.payload != null && response.payload!.isNotEmpty) {
          NotificationNavigationHandler.handlePayload(response.payload);
        }
      },
    );

    // Explicitly request iOS notification authorization
    final iosPlugin = flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>();
    if (iosPlugin != null) {
      final granted = await iosPlugin.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      debugPrint("iOS notification permission granted: $granted");
    }

    // Trigger system permission handler prompt on Android 13+ & iOS
    await Permission.notification.request();

    // Check if app was opened via a local notification tap (terminated state)
    final launchDetails =
        await flutterLocalNotificationsPlugin.getNotificationAppLaunchDetails();
    if (launchDetails != null && launchDetails.didNotificationLaunchApp) {
      final payload = launchDetails.notificationResponse?.payload;
      if (payload != null && payload.isNotEmpty) {
        debugPrint(
            "App launched from local notification click: payload=$payload");
        NotificationNavigationHandler.handlePayload(payload);
      }
    }
  } catch (e) {
    debugPrint('Local notifications initialization error: $e');
  }

  // 3. Initialize background location service
  try {
    await initializeBackgroundLocationService();
  } catch (e) {
    debugPrint('Background location initialization error: $e');
  }

  runApp(
    const ProviderScope(
      child: DriverApp(),
    ),
  );
}

final routerProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    initialLocation: '/splash',
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/',
        builder: (context, state) => const MainShell(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
    ],
    redirect: (context, state) {
      final isLoggedIn = authState.status == AuthStatus.authenticated;
      final isLoggingIn = state.matchedLocation == '/login';
      final isSplash = state.matchedLocation == '/splash';

      if (isSplash) {
        return null;
      }

      if (authState.status == AuthStatus.authenticating) {
        return null;
      }

      if (!isLoggedIn) {
        return '/login';
      }

      if (isLoggedIn && isLoggingIn) {
        return '/';
      }

      return null;
    },
  );
});

class DriverApp extends ConsumerWidget {
  const DriverApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);
    final authState = ref.watch(authProvider);
    final branding = authState.tenantBranding ?? TenantBranding.defaultRedTaxis();
    final appTitle = branding.name.isNotEmpty ? '${branding.name} Driver' : 'Red Taxis Driver';

    // Dynamically update the OS Recent Apps / Task Switcher title and brand primary color
    SystemChrome.setApplicationSwitcherDescription(
      ApplicationSwitcherDescription(
        label: appTitle,
        primaryColor: branding.primaryColor.toARGB32(),
      ),
    );

    final fontOption = ref.watch(fontSizeScaleProvider);

    return MaterialApp.router(
      title: appTitle,
      theme: AppTheme.getDynamicLightTheme(branding),
      darkTheme: AppTheme.getDynamicDarkTheme(branding),
      themeMode: themeMode,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
      builder: (context, child) {
        final mediaQuery = MediaQuery.of(context);
        return MediaQuery(
          data: mediaQuery.copyWith(
            textScaler: TextScaler.linear(fontOption.scale),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
