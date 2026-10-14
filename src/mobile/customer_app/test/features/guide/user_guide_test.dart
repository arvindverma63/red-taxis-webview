import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:customer_app/core/theme/app_theme.dart';
import 'package:customer_app/features/guide/application/user_guide_controller.dart';
import 'package:customer_app/features/guide/presentation/feature_discovery_overlay.dart';
import 'package:customer_app/features/guide/presentation/user_guide_sheet.dart';
import 'package:customer_app/features/guide/presentation/widgets/guide_banner_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('UserGuideSeenController', () {
    test('defaults to false when storage is empty', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final state = await container.read(userGuideSeenProvider.future);
      expect(state, isFalse);
    });

    test('markSeen persists true and updates state', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await container.read(userGuideSeenProvider.future);
      await container.read(userGuideSeenProvider.notifier).markSeen();

      final updated = container.read(userGuideSeenProvider).valueOrNull;
      expect(updated, isTrue);
    });

    test('reset clears storage flag and updates state to false', () async {
      FlutterSecureStorage.setMockInitialValues({
        'first_time_user_guide_seen': 'true',
      });

      final container = ProviderContainer();
      addTearDown(container.dispose);

      final initial = await container.read(userGuideSeenProvider.future);
      expect(initial, isTrue);

      await container.read(userGuideSeenProvider.notifier).reset();
      expect(container.read(userGuideSeenProvider).valueOrNull, isFalse);
    });
  });

  group('GuideBannerCard Widget', () {
    testWidgets('renders headline, body and triggers callbacks', (tester) async {
      bool opened = false;
      bool dismissed = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: GuideBannerCard(
              onOpenGuide: () => opened = true,
              onDismiss: () => dismissed = true,
            ),
          ),
        ),
      );

      expect(find.text('New to First Taxis? 👋'), findsOneWidget);
      expect(find.text('Open User Guide'), findsOneWidget);

      await tester.tap(find.text('Open User Guide'));
      expect(opened, isTrue);

      await tester.tap(find.byIcon(Icons.close_rounded));
      expect(dismissed, isTrue);
    });
  });

  group('UserGuideSheet Modal', () {
    testWidgets('opens sheet, displays Step 1 of 4 and advances on Next Step',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.light,
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => showFirstTimeUserGuide(context, markAsSeen: false),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.text('First Taxis User Guide'), findsOneWidget);
      expect(find.text('Step 1 of 4'), findsOneWidget);
      expect(find.text('Set Your Journey'), findsOneWidget);

      // Tap Next Step ➔
      await tester.tap(find.text('Next Step ➔'));
      await tester.pumpAndSettle();

      expect(find.text('Step 2 of 4'), findsOneWidget);
      expect(find.text('Choose Fleet Vehicle'), findsOneWidget);
    });
  });

  group('Google Feature Discovery Overlay', () {
    testWidgets(
        'mounts spotlight overlay, highlights target and advances on Next',
        (tester) async {
      final key1 = GlobalKey();
      final key2 = GlobalKey();

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: Column(
              children: [
                Container(
                  key: key1,
                  height: 60,
                  width: 200,
                  color: Colors.blue,
                ),
                const SizedBox(height: 40),
                Container(
                  key: key2,
                  height: 60,
                  width: 200,
                  color: Colors.green,
                ),
                Builder(
                  builder: (context) => ElevatedButton(
                    onPressed: () {
                      showGoogleFeatureDiscovery(
                        context: context,
                        steps: [
                          FeatureDiscoveryStep(
                            targetKey: key1,
                            title: 'First Target',
                            description: 'Description 1',
                            icon: Icons.star,
                          ),
                          FeatureDiscoveryStep(
                            targetKey: key2,
                            title: 'Second Target',
                            description: 'Description 2',
                            icon: Icons.local_taxi,
                          ),
                        ],
                      );
                    },
                    child: const Text('Start Tour'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      await tester.tap(find.text('Start Tour'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('STEP 1 OF 2'), findsOneWidget);
      expect(find.text('First Target'), findsOneWidget);
      expect(find.text('Description 1'), findsOneWidget);

      // Tap Next ➔
      await tester.tap(find.text('Next ➔'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('STEP 2 OF 2'), findsOneWidget);
      expect(find.text('Second Target'), findsOneWidget);
      expect(find.text('Description 2'), findsOneWidget);
    });
  });
}
