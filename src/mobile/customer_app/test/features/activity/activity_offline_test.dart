import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:customer_app/core/domain/place.dart';
import 'package:customer_app/core/storage/token_storage.dart';
import 'package:customer_app/features/activity/data/activity_repository.dart';
import 'package:customer_app/features/activity/domain/booking_summary.dart';
import 'package:customer_app/features/activity/presentation/activity_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  group('ActivityRepository Offline Trip History', () {
    test('returns cached offline bookings when network fails', () async {
      FlutterSecureStorage.setMockInitialValues({
        'cached_customer_bookings': jsonEncode([
          {
            'id': 'offline-trip-99',
            'pickup': {
              'description': '10 Downing St, London',
              'postcode': 'SW1A 2AA',
              'addressLine': '10 Downing St',
            },
            'dropoff': {
              'description': 'Heathrow Airport Terminal 5',
              'postcode': 'TW6 2GA',
              'addressLine': 'Heathrow Terminal 5',
            },
            'scheduledFor': DateTime.now().toIso8601String(),
            'status': 'completed',
            'price': 65.50,
            'vehicleName': 'Saloon',
            'passengers': 2,
            'paymentMethod': 'Card',
          }
        ]),
      });

      final container = ProviderContainer();
      addTearDown(container.dispose);

      final repo = container.read(activityRepositoryProvider);
      final trips = await repo.myBookings();

      expect(trips, isNotEmpty);
      expect(trips.first.id, equals('offline-trip-99'));
      expect(trips.first.price, equals(65.50));
      expect(container.read(activityIsOfflineProvider), isTrue);

      final detail = await repo.detail('offline-trip-99');
      expect(detail.id, equals('offline-trip-99'));
      expect(detail.vehicleName, equals('Saloon'));
    });

    test('initializes starter offline history if storage is completely empty', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final repo = container.read(activityRepositoryProvider);
      final trips = await repo.myBookings();

      expect(trips, isNotEmpty);
      expect(container.read(activityIsOfflineProvider), isTrue);

      // Verify that starter history was saved to secure storage
      final storage = container.read(secureStorageProvider);
      final savedStr = await storage.read(key: 'cached_customer_bookings');
      expect(savedStr, isNotNull);
      expect(savedStr, contains('mock-1'));
    });

    test('recordBooking appends new booking to offline history', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final repo = container.read(activityRepositoryProvider);
      final newBooking = BookingSummary(
        id: 'new-local-101',
        pickup: const Place(description: 'Station Square', addressLine: 'Station Square'),
        dropoff: const Place(description: 'City Hall', addressLine: 'City Hall'),
        scheduledFor: DateTime.fromMillisecondsSinceEpoch(1770000000000),
        status: 'confirmed',
        price: 24.00,
        vehicleName: 'Executive',
        passengers: 3,
        paymentMethod: 'Card',
      );

      await repo.recordBooking(newBooking);

      final trips = await repo.myBookings();
      expect(trips.any((b) => b.id == 'new-local-101'), isTrue);
    });
  });

  group('ActivityScreen Offline Rendering & Header Cleanup', () {
    testWidgets('renders search, filter tabs and offline banner without stats grid header', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Mark as offline
      container.read(activityIsOfflineProvider.notifier).state = true;

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: ActivityScreen(),
          ),
        ),
      );

      // Wait for repository and controllers to resolve
      await tester.pump();
      await tester.pumpAndSettle();

      // 1. Verify offline indicator banner is displayed
      expect(find.textContaining('Offline mode'), findsOneWidget);

      // 2. Verify search bar is visible right at the top
      expect(find.byType(TextField), findsOneWidget);

      // 3. Verify filter chips are present
      expect(find.text('All'), findsOneWidget);
      expect(find.text('Ongoing'), findsOneWidget);
      expect(find.text('Completed'), findsOneWidget);

      // 4. Verify the top stats grid header is completely removed
      expect(find.text('Total Rides'), findsNothing);
      expect(find.text('Total Spent'), findsNothing);
      expect(find.text('Active / Planned'), findsNothing);
    });
  });
}
