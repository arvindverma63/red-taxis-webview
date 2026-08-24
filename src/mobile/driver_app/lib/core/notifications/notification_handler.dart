import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:driver_app/features/navigation/presentation/navigation_notifier.dart';
import 'package:driver_app/features/trip/trip.dart';

class NotificationNavigationHandler {
  static Map<String, dynamic>? _pendingPayload;
  static WidgetRef? _activeRef;

  /// Register active WidgetRef or container ref from the main shell
  static void registerRef(WidgetRef ref) {
    _activeRef = ref;
    if (_pendingPayload != null) {
      debugPrint("NotificationNavigationHandler: Processing pending payload on registration");
      final payload = _pendingPayload!;
      _pendingPayload = null;
      handlePayload(payload, ref: ref);
    }
  }

  /// Unregister ref when main shell unmounts
  static void unregisterRef() {
    _activeRef = null;
  }

  /// Handle incoming payload from FCM or local notifications
  static void handlePayload(dynamic rawPayload, {WidgetRef? ref}) {
    final targetRef = ref ?? _activeRef;
    Map<String, dynamic> data = {};

    if (rawPayload is String) {
      try {
        if (rawPayload.trim().startsWith('{')) {
          data = Map<String, dynamic>.from(jsonDecode(rawPayload));
        } else {
          data = {'nav_id': rawPayload.trim()};
        }
      } catch (e) {
        debugPrint("NotificationNavigationHandler: Failed to decode JSON payload string: $e");
        data = {'nav_id': rawPayload.trim()};
      }
    } else if (rawPayload is Map) {
      data = Map<String, dynamic>.from(rawPayload);
    }

    if (data.isEmpty) {
      debugPrint("NotificationNavigationHandler: Empty notification data payload");
      return;
    }

    debugPrint("NotificationNavigationHandler: Handling notification payload: $data");

    if (targetRef == null) {
      debugPrint("NotificationNavigationHandler: UI ref not ready yet, queuing pending payload");
      _pendingPayload = data;
      return;
    }

    // Extract navigation identifier and notification type from payload
    final notificationType = (data['notificationType'] ??
            data['notification_type'] ??
            data['type'] ??
            data['action'] ??
            data['nav_id'] ??
            data['navId'] ??
            data['nav_page'] ??
            data['page'] ??
            data['target'] ??
            data['screen'] ??
            data['tab'] ??
            data['route'] ??
            '')
        .toString()
        .trim()
        .toLowerCase();

    final deepLink = (data['deepLink'] ??
            data['deep_link'] ??
            data['link'] ??
            '')
        .toString()
        .trim();

    String bookingId = (data['bookingId'] ??
            data['BookingId'] ??
            data['booking_id'] ??
            data['bookingNo'] ??
            data['BookingNo'] ??
            data['jobId'] ??
            data['job_id'] ??
            data['id'] ??
            data['Id'] ??
            '')
        .toString()
        .trim();

    if (bookingId.isEmpty && deepLink.isNotEmpty) {
      if (deepLink.contains('/')) {
        bookingId = deepLink.split('/').last.trim();
      }
    }

    final guid = (data['notificationId'] ??
            data['notification_id'] ??
            data['guid'] ??
            data['Guid'] ??
            data['NotificationId'] ??
            data['Notification_Id'] ??
            '')
        .toString()
        .trim();

    final notificationTitle = (data['title'] ?? '').toString().trim().toLowerCase();
    final notificationBody = (data['body'] ?? data['message'] ?? '').toString().trim().toLowerCase();

    debugPrint("NotificationNavigationHandler: notificationType='$notificationType', title='$notificationTitle', body='$notificationBody', deepLink='$deepLink', bookingId='$bookingId', guid='$guid'");

    final navNotifier = targetRef.read(navigationProvider.notifier);

    // 1. Check for Booking Cancelled
    final isCancelled = notificationType == '4' ||
        notificationType == 'cancelled' ||
        notificationType == 'cancel' ||
        notificationType == 'job_cancelled' ||
        notificationType == 'booking_cancelled' ||
        notificationType == 'booking.cancelled' ||
        notificationType == 'bookingcancelled' ||
        notificationType == 'cancelled_booking' ||
        deepLink.toLowerCase().contains('cancel') ||
        notificationTitle.contains('cancel') ||
        notificationBody.contains('cancel');

    if (isCancelled) {
      debugPrint("NotificationNavigationHandler: Booking $bookingId CANCELLED. Dismissing any active offer and showing Cancelled screen.");
      targetRef.read(tripProvider.notifier).rejectJob();
      navNotifier.openCustomWebView(
        route: '/job-offer',
        title: 'Booking Cancelled',
        params: {
          if (bookingId.isNotEmpty) 'jobId': bookingId,
          'status': 'cancelled',
          ..._extractParams(data)
        },
      );
      return;
    }

    // 2. Check for Booking Unallocated
    final isUnallocated = notificationType == '2' ||
        notificationType == 'unallocated' ||
        notificationType == 'unallocate' ||
        notificationType == 'job_unallocated' ||
        notificationType == 'booking_unallocated' ||
        notificationType == 'booking.unallocated' ||
        notificationType == 'unallocated_booking' ||
        deepLink.toLowerCase().contains('unallocate') ||
        notificationTitle.contains('unallocate') ||
        notificationBody.contains('unallocate');

    if (isUnallocated) {
      debugPrint("NotificationNavigationHandler: Booking $bookingId UNALLOCATED. Dismissing any active offer and showing Unallocated screen.");
      targetRef.read(tripProvider.notifier).rejectJob();
      navNotifier.openCustomWebView(
        route: '/job-offer',
        title: 'Booking Unallocated',
        params: {
          if (bookingId.isNotEmpty) 'jobId': bookingId,
          'status': 'unallocated',
          ..._extractParams(data)
        },
      );
      return;
    }

    // 3. Check for Booking Amended
    final isAmended = notificationType == '3' ||
        notificationType == 'amended' ||
        notificationType == 'amend' ||
        notificationType == 'job_amended' ||
        notificationType == 'booking_amended' ||
        notificationType == 'booking.amended' ||
        notificationType == 'amended_booking' ||
        deepLink.toLowerCase().contains('amend') ||
        notificationTitle.contains('amend') ||
        notificationBody.contains('amend');

    if (isAmended) {
      debugPrint("NotificationNavigationHandler: Booking $bookingId AMENDED. Dismissing any active offer and showing Amended screen.");
      targetRef.read(tripProvider.notifier).rejectJob();
      navNotifier.openCustomWebView(
        route: '/job-offer',
        title: 'Booking Amended',
        params: {
          if (bookingId.isNotEmpty) 'jobId': bookingId,
          'status': 'amended',
          ..._extractParams(data)
        },
      );
      return;
    }

    // 4. Check for Job Offer / Booking Allocation payload (Strict matches only)
    final isBookingOffer = !isCancelled && !isUnallocated && !isAmended && (
        notificationType == '1' ||
        notificationType == 'allocated' ||
        notificationType == 'offered' ||
        notificationType == 'job_offered' ||
        notificationType == 'job_offer' ||
        (deepLink.isNotEmpty && deepLink.toLowerCase().startsWith('booking')) ||
        (bookingId.isNotEmpty && (notificationType.isEmpty || notificationType == '1' || notificationType == 'job_offer' || notificationType == 'allocated'))
    );

    if (isBookingOffer && bookingId.isNotEmpty) {
      final fare = double.tryParse(data['fare']?.toString() ?? '0.0') ?? 0.0;
      final pickup = data['pickupAddress'] ?? data['pickup'] ?? 'Pickup address';
      final dropoff = data['dropoffAddress'] ?? data['dropoff'] ?? 'Dropoff destination';
      final paymentType = data['paymentType'] ?? 'Cash';
      final vehicleType = data['vehicleType'] ?? 'Standard Saloon';
      final passenger = data['passengerName'] ?? data['passenger'] ?? 'Passenger';
      final notes = data['notes'] ?? '';

      debugPrint("NotificationNavigationHandler: Triggering fetchAndOfferJob for bookingId='$bookingId', guid='$guid'");
      targetRef.read(tripProvider.notifier).fetchAndOfferJob(
            bookingId,
            guid: guid,
            fallbackDetails: TripDetails(
              id: bookingId,
              guid: guid,
              pickupAddress: pickup.toString(),
              dropoffAddress: dropoff.toString(),
              fare: fare,
              paymentType: paymentType.toString(),
              vehicleType: vehicleType.toString(),
              passenger: passenger.toString(),
              notes: notes.toString(),
            ),
          );
      return;
    }

    final navId = notificationType;

    // Map nav_id to tab index or custom webview
    switch (navId) {
      case 'dashboard':
      case 'home':
      case 'main':
      case '0':
        navNotifier.setTabIndex(0);
        break;

      case 'bookings':
      case 'my_bookings':
      case 'my-bookings':
      case 'trips':
      case 'my_trips':
        navNotifier.setTabIndex(1);
        break;

      case 'profile':
      case 'my_profile':
      case 'my-profile':
      case 'compliance':
      case 'account':
        navNotifier.setTabIndex(2);
        break;

      case 'availability':
      case 'shifts':
      case 'shift_planner':
      case 'weekly_availability':
      case 'weekly-availability':
        navNotifier.setTabIndex(3);
        break;

      case 'expenses':
      case 'my_expenses':
      case 'my-expenses':
      case 'expense_log':
        navNotifier.setTabIndex(4);
        break;

      case '2': // Job Unallocated
      case 'unallocated':
      case 'job_unallocated':
        final currentTrip = targetRef.read(tripProvider).currentTrip;
        if (currentTrip != null && currentTrip.id == bookingId) {
          targetRef.read(tripProvider.notifier).rejectJob();
        }
        navNotifier.openCustomWebView(
          route: '/job-offer',
          title: 'Job Unallocated',
          params: {
            'jobId': bookingId,
            'status': 'unallocated',
            ..._extractParams(data)
          },
        );
        break;

      case '3': // Job Amended
      case 'amended':
      case 'job_amended':
        final currentTrip = targetRef.read(tripProvider).currentTrip;
        if (currentTrip != null && currentTrip.id == bookingId) {
          targetRef.read(tripProvider.notifier).rejectJob();
        }
        navNotifier.openCustomWebView(
          route: '/job-offer',
          title: 'Job Amended',
          params: {
            'jobId': bookingId,
            'status': 'amended',
            ..._extractParams(data)
          },
        );
        break;

      case '4': // Job Cancelled
      case 'cancelled':
      case 'job_cancelled':
        final currentTrip = targetRef.read(tripProvider).currentTrip;
        if (currentTrip != null && currentTrip.id == bookingId) {
          targetRef.read(tripProvider.notifier).rejectJob();
        }
        navNotifier.openCustomWebView(
          route: '/job-offer',
          title: 'Job Cancelled',
          params: {
            'jobId': bookingId,
            'status': 'cancelled',
            ..._extractParams(data)
          },
        );
        break;

      case 'create-booking':
      case 'create_booking':
      case 'rank_pickup':
      case 'rank-pickup':
      case '5':
        navNotifier.setTabIndex(5);
        break;

      case 'reports':
      case 'report':
      case 'statements':
      case 'statement':
      case 'earnings':
      case 'earning':
      case '6':
        navNotifier.setTabIndex(6);
        break;

      case 'upload':
      case 'doc_upload':
      case 'document_upload':
      case 'compliance_upload':
        navNotifier.openCustomWebView(
          route: '/upload',
          title: 'Upload Document',
          params: _extractParams(data),
        );
        break;

      default:
        // Check if a direct custom route or url is passed
        final customRoute = data['route'] ?? data['url'] ?? data['path'];
        if (customRoute != null && customRoute.toString().isNotEmpty) {
          String routeStr = customRoute.toString();
          if (routeStr.startsWith('/#/')) {
            routeStr = routeStr.replaceFirst('/#/', '/');
          } else if (routeStr.startsWith('#/')) {
            routeStr = routeStr.replaceFirst('#/', '/');
          }
          final title = data['title'] ?? 'Details';
          navNotifier.openCustomWebView(
            route: routeStr,
            title: title.toString(),
            params: _extractParams(data),
          );
        } else {
          debugPrint("NotificationNavigationHandler: Unhandled navId '$navId', defaulting to dashboard");
          navNotifier.setTabIndex(0);
        }
        break;
    }
  }

  static Map<String, String> _extractParams(Map<String, dynamic> data) {
    final params = <String, String>{};
    data.forEach((key, value) {
      if (value != null &&
          key != 'nav_id' &&
          key != 'navId' &&
          key != 'page' &&
          key != 'target' &&
          key != 'route') {
        params[key] = value.toString();
      }
    });
    return params;
  }
}
