import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_tts/flutter_tts.dart';

enum NotificationCategory {
  jobOffer,
  jobCancel,
  jobAmended,
  jobUnallocated,
  general,
}

class NotificationSoundService {
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  static final FlutterTts _tts = FlutterTts();
  static bool _ttsInitialized = false;

  static const AndroidNotificationChannel jobOfferChannel =
      AndroidNotificationChannel(
    'job_offer_speech_v1',
    'New Job Offers (Voice Speech)',
    description: 'High-priority voice speech alerts for incoming dispatch and booking job offers',
    importance: Importance.max,
    playSound: true,
    sound: RawResourceAndroidNotificationSound('job_offer'),
    enableVibration: true,
    audioAttributesUsage: AudioAttributesUsage.notificationRingtone,
  );

  static const AndroidNotificationChannel jobCancelChannel =
      AndroidNotificationChannel(
    'job_cancel_speech_v1',
    'Job Cancellations (Voice Speech)',
    description: 'Warning voice speech alerts when a job is cancelled or unallocated',
    importance: Importance.high,
    playSound: true,
    sound: RawResourceAndroidNotificationSound('job_cancel'),
    enableVibration: true,
    audioAttributesUsage: AudioAttributesUsage.notification,
  );

  static const AndroidNotificationChannel jobAmendedChannel =
      AndroidNotificationChannel(
    'job_amended_speech_v1',
    'Job Amendments (Voice Speech)',
    description: 'Notification voice speech alerts when a job is amended or modified',
    importance: Importance.high,
    playSound: true,
    sound: RawResourceAndroidNotificationSound('job_amended'),
    enableVibration: true,
    audioAttributesUsage: AudioAttributesUsage.notification,
  );

  static const AndroidNotificationChannel generalAlertChannel =
      AndroidNotificationChannel(
    'general_alert_speech_v1',
    'General Notifications (Voice Speech)',
    description: 'Standard notifications and announcements with voice alerts',
    importance: Importance.high,
    playSound: true,
    sound: RawResourceAndroidNotificationSound('general_alert'),
    enableVibration: true,
    audioAttributesUsage: AudioAttributesUsage.notification,
  );

  /// Initialize TTS voice engine
  static Future<void> initTts() async {
    if (_ttsInitialized) return;
    try {
      if (!kIsWeb) {
        await _tts.setLanguage('en-GB');
        await _tts.setSpeechRate(0.5);
        await _tts.setVolume(1.0);
        await _tts.setPitch(1.0);
        if (defaultTargetPlatform == TargetPlatform.android) {
          await _tts.awaitSpeakCompletion(true);
        }
      }
      _ttsInitialized = true;
      debugPrint('[NotificationSoundService] TTS speech engine initialized');
    } catch (e) {
      debugPrint('[NotificationSoundService] TTS initialization notice: $e');
    }
  }

  /// Speak spoken speech for a category directly (TTS engine)
  static Future<void> speakCategory(NotificationCategory category) async {
    try {
      await initTts();
      String phrase;
      switch (category) {
        case NotificationCategory.jobOffer:
          phrase = 'New job offer';
          break;
        case NotificationCategory.jobCancel:
          phrase = 'Job offer cancelled';
          break;
        case NotificationCategory.jobUnallocated:
          phrase = 'Job unallocated';
          break;
        case NotificationCategory.jobAmended:
          phrase = 'Job amended';
          break;
        case NotificationCategory.general:
          phrase = 'New alert received';
          break;
      }
      debugPrint('[NotificationSoundService] Speaking phrase: "$phrase"');
      await _tts.stop();
      await _tts.speak(phrase);
    } catch (e) {
      debugPrint('[NotificationSoundService] TTS speak error: $e');
    }
  }

  /// Register all sound-specific Android Notification Channels
  static Future<void> registerNotificationChannels() async {
    await initTts();
    if (defaultTargetPlatform == TargetPlatform.android) {
      final androidPlugin = _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        await androidPlugin.createNotificationChannel(jobOfferChannel);
        await androidPlugin.createNotificationChannel(jobCancelChannel);
        await androidPlugin.createNotificationChannel(jobAmendedChannel);
        await androidPlugin.createNotificationChannel(generalAlertChannel);
        debugPrint('[NotificationSoundService] Registered 4 voice speech notification channels');
      }
    }
  }

  /// Classify notification payload and text into precise category
  static NotificationCategory categorize(
    Map<String, dynamic> data, {
    String? title,
    String? body,
  }) {
    final type = (data['notificationType'] ??
            data['notification_type'] ??
            data['type'] ??
            data['action'] ??
            data['nav_id'] ??
            data['navId'] ??
            data['status'] ??
            '')
        .toString()
        .trim()
        .toLowerCase();

    final fullTitle = '${data['title'] ?? ''} ${title ?? ''}'.toLowerCase();
    final fullBody = '${data['body'] ?? ''} ${data['message'] ?? ''} ${body ?? ''}'.toLowerCase();
    final link = (data['deepLink'] ?? data['deep_link'] ?? data['link'] ?? '').toString().trim().toLowerCase();
    final bookingId = (data['bookingId'] ??
            data['BookingId'] ??
            data['booking_id'] ??
            data['jobId'] ??
            data['job_id'] ??
            data['id'] ??
            '')
        .toString()
        .trim();
    final guid = (data['notificationId'] ?? data['guid'] ?? data['Guid'] ?? '').toString().trim();

    // 1. Amended Check (High Priority: Check before cancellation keywords so edit notifications don't get misidentified)
    if (type == '3' ||
        type == 'amended' ||
        type == 'amend' ||
        type == 'job_amended' ||
        type == 'booking_amended' ||
        type == 'booking.amended' ||
        type == 'amended_booking' ||
        type == 'modified' ||
        type == 'updated' ||
        type == 'job_updated' ||
        link.contains('amend') ||
        link.contains('modified') ||
        fullTitle.contains('amend') ||
        fullTitle.contains('amended') ||
        fullBody.contains('amend') ||
        fullBody.contains('amended') ||
        fullTitle.contains('modified') ||
        fullBody.contains('modified') ||
        fullTitle.contains('job updated') ||
        fullBody.contains('job updated')) {
      return NotificationCategory.jobAmended;
    }

    // 2. Cancellation Check
    if (type == '4' ||
        type == 'cancelled' ||
        type == 'cancel' ||
        type == 'job_cancelled' ||
        type == 'booking_cancelled' ||
        type == 'cancelled_booking' ||
        type == 'booking.cancelled' ||
        link.contains('cancel') ||
        fullTitle.contains('cancel') ||
        fullTitle.contains('cancelled') ||
        fullTitle.contains('abort') ||
        fullBody.contains('cancel') ||
        fullBody.contains('cancelled') ||
        fullBody.contains('has been cancelled')) {
      return NotificationCategory.jobCancel;
    }

    // 3. Unallocated Check
    if (type == '2' ||
        type == 'unallocated' ||
        type == 'unallocate' ||
        type == 'job_unallocated' ||
        type == 'booking_unallocated' ||
        type == 'booking.unallocated' ||
        link.contains('unallocate') ||
        fullTitle.contains('unallocate') ||
        fullBody.contains('unallocate') ||
        fullBody.contains('unallocated')) {
      return NotificationCategory.jobUnallocated;
    }

    // 4. Job Offer Check (Strict matching)
    final isExplicitOfferType = type == '1' ||
        type == 'job_offer' ||
        type == 'job_offered' ||
        type == 'offered' ||
        type == 'allocated' ||
        type == 'dispatch' ||
        type == 'new_job' ||
        type == 'booking.offered';

    final hasOfferKeywords = fullTitle.contains('job offer') ||
        fullTitle.contains('new job') ||
        fullTitle.contains('new booking') ||
        fullTitle.contains('dispatch') ||
        fullBody.contains('job offer') ||
        fullBody.contains('new booking') ||
        link.startsWith('booking');

    if (isExplicitOfferType || hasOfferKeywords) {
      return NotificationCategory.jobOffer;
    }

    // If only bookingId / guid exists with no other info, verify it's not a generic message
    if ((bookingId.isNotEmpty || guid.isNotEmpty) &&
        (type.isEmpty || type == '1') &&
        !fullTitle.contains('message') &&
        !fullTitle.contains('statement') &&
        !fullTitle.contains('document') &&
        !fullTitle.contains('announcement')) {
      return NotificationCategory.jobOffer;
    }

    // 5. Default to General Alert
    return NotificationCategory.general;
  }

  /// Build NotificationDetails with the specific channel, raw sound asset & vibration
  static NotificationDetails getDetailsForCategory(NotificationCategory category) {
    switch (category) {
      case NotificationCategory.jobOffer:
        return NotificationDetails(
          android: AndroidNotificationDetails(
            jobOfferChannel.id,
            jobOfferChannel.name,
            channelDescription: jobOfferChannel.description,
            importance: Importance.max,
            priority: Priority.max,
            playSound: true,
            sound: const RawResourceAndroidNotificationSound('job_offer'),
            enableVibration: true,
            vibrationPattern: Int64List.fromList([0, 800, 300, 800, 300, 800]),
            audioAttributesUsage: AudioAttributesUsage.notificationRingtone,
            category: AndroidNotificationCategory.call,
            fullScreenIntent: true,
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
            sound: 'job_offer.wav',
            interruptionLevel: InterruptionLevel.timeSensitive,
          ),
        );

      case NotificationCategory.jobCancel:
      case NotificationCategory.jobUnallocated:
        return NotificationDetails(
          android: AndroidNotificationDetails(
            jobCancelChannel.id,
            jobCancelChannel.name,
            channelDescription: jobCancelChannel.description,
            importance: Importance.high,
            priority: Priority.high,
            playSound: true,
            sound: const RawResourceAndroidNotificationSound('job_cancel'),
            enableVibration: true,
            vibrationPattern: Int64List.fromList([0, 600, 300, 600]),
            audioAttributesUsage: AudioAttributesUsage.notification,
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
            sound: 'job_cancel.wav',
          ),
        );

      case NotificationCategory.jobAmended:
        return NotificationDetails(
          android: AndroidNotificationDetails(
            jobAmendedChannel.id,
            jobAmendedChannel.name,
            channelDescription: jobAmendedChannel.description,
            importance: Importance.high,
            priority: Priority.high,
            playSound: true,
            sound: const RawResourceAndroidNotificationSound('job_amended'),
            enableVibration: true,
            vibrationPattern: Int64List.fromList([0, 500, 250, 500]),
            audioAttributesUsage: AudioAttributesUsage.notification,
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
            sound: 'job_amended.wav',
          ),
        );

      case NotificationCategory.general:
        return NotificationDetails(
          android: AndroidNotificationDetails(
            generalAlertChannel.id,
            generalAlertChannel.name,
            channelDescription: generalAlertChannel.description,
            importance: Importance.high,
            priority: Priority.high,
            playSound: true,
            sound: const RawResourceAndroidNotificationSound('general_alert'),
            enableVibration: true,
            vibrationPattern: Int64List.fromList([0, 250, 200, 250]),
            audioAttributesUsage: AudioAttributesUsage.notification,
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
            sound: 'general_alert.wav',
          ),
        );
    }
  }

  /// Show banner notification with voice speech based on payload category
  static Future<void> showNotification({
    required String title,
    required String body,
    required Map<String, dynamic> data,
    int? id,
    bool speakTts = false,
  }) async {
    try {
      final category = categorize(data, title: title, body: body);
      final details = getDetailsForCategory(category);
      final notificationId = id ?? DateTime.now().millisecond;

      // On mobile devices, the NotificationChannel plays the chime + voice WAV file.
      // If speakTts is explicitly true (e.g. settings testing), speak without overlapping.
      if (speakTts) {
        speakCategory(category);
      }

      await _localNotifications.show(
        notificationId,
        title,
        body,
        details,
        payload: jsonEncode(data),
      );
      debugPrint('[NotificationSoundService] Dispatched notification #$notificationId (category: $category, voice sound: ${category.name})');
    } catch (e) {
      debugPrint('[NotificationSoundService] Failed to show sound notification: $e');
    }
  }
}
