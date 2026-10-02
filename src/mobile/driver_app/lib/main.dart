import 'dart:convert';
import 'dart:ui';
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
import 'package:permission_handler/permission_handler.dart';
import 'package:driver_app/core/location/background_location_service.dart';
import 'package:driver_app/firebase_options.dart';

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  debugPrint("================ FCM BACKGROUND MESSAGE ================");
  debugPrint("Message ID: ${message.messageId}");
  debugPrint("Title: ${message.notification?.title}");
  debugPrint("Body: ${message.notification?.body}");
  debugPrint("Data: ${message.data}");
  debugPrint("========================================================");
}

// Global high importance channel definition for Android heads-up alerts
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
  DartPluginRegistrant.ensureInitialized();

  // 1. Initialize background location service
  try {
    await initializeBackgroundLocationService();
  } catch (e) {
    debugPrint('Background location initialization error: $e');
  }

  // 2. Initialize local notifications and request permissions for iOS & Android
  try {
    // Create Android High Importance Notification Channel
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

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

  // 3. Initialize Firebase Messaging (FCM)
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
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

    // FCM Foreground listener: show local heads-up notification with data payload and route immediately
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint("================ FCM FOREGROUND MESSAGE ================");
      debugPrint("Message ID: ${message.messageId}");
      debugPrint("Title: ${message.notification?.title}");
      debugPrint("Body: ${message.notification?.body}");
      debugPrint("Data: ${message.data}");
      debugPrint("========================================================");

      // Automatically trigger navigation/job offer overlay immediately on foreground message
      NotificationNavigationHandler.handlePayload(message.data);

      final notification = message.notification;

      // If notification payload exists, show native heads-up banner on Android/iOS
      if (notification != null) {
        flutterLocalNotificationsPlugin.show(
          notification.hashCode,
          notification.title,
          notification.body,
          NotificationDetails(
            android: AndroidNotificationDetails(
              channel.id,
              channel.name,
              channelDescription: channel.description,
              importance: Importance.high,
              priority: Priority.high,
              playSound: true,
            ),
            iOS: const DarwinNotificationDetails(
              presentAlert: true,
              presentBadge: true,
              presentSound: true,
            ),
          ),
          payload: jsonEncode(message.data),
        );
      }
    });

    // FCM Background Notification Tap
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint("FCM notification opened app: ${message.data}");
      NotificationNavigationHandler.handlePayload(message.data);
    });

    // FCM Terminated Cold-start Tap
    FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
      if (message != null) {
        debugPrint("FCM initial message on startup: ${message.data}");
        NotificationNavigationHandler.handlePayload(message.data);
      }
    });
  } catch (e) {
    debugPrint('Firebase initialization failed: $e');
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
