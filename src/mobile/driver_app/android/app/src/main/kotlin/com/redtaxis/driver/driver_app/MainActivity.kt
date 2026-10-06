package com.redtaxis.driver.driver_app

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.ContentResolver
import android.media.AudioAttributes
import android.net.Uri
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        createNotificationChannels()
    }

    private fun createNotificationChannels() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val notificationManager = getSystemService(NotificationManager::class.java) ?: return

            val ringtoneAudioAttributes = AudioAttributes.Builder()
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .setUsage(AudioAttributes.USAGE_NOTIFICATION_RINGTONE)
                .build()

            val alertAudioAttributes = AudioAttributes.Builder()
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .setUsage(AudioAttributes.USAGE_NOTIFICATION)
                .build()

            val jobOfferSoundUri = Uri.parse("${ContentResolver.SCHEME_ANDROID_RESOURCE}://${packageName}/raw/job_offer")
            val jobCancelSoundUri = Uri.parse("${ContentResolver.SCHEME_ANDROID_RESOURCE}://${packageName}/raw/job_cancel")
            val jobAmendedSoundUri = Uri.parse("${ContentResolver.SCHEME_ANDROID_RESOURCE}://${packageName}/raw/job_amended")
            val generalAlertSoundUri = Uri.parse("${ContentResolver.SCHEME_ANDROID_RESOURCE}://${packageName}/raw/general_alert")

            // 1. Job Offer Channel
            val jobOfferChannel = NotificationChannel(
                "job_offer_speech_v1",
                "New Job Offers (Voice Speech)",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "High-priority voice speech alerts for incoming dispatch and booking job offers"
                setSound(jobOfferSoundUri, ringtoneAudioAttributes)
                enableVibration(true)
                vibrationPattern = longArrayOf(0, 800, 300, 800, 300, 800)
                lockscreenVisibility = android.app.Notification.VISIBILITY_PUBLIC
            }

            // 2. Job Cancel Channel
            val jobCancelChannel = NotificationChannel(
                "job_cancel_speech_v1",
                "Job Cancellations (Voice Speech)",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Warning voice speech alerts when a job is cancelled or unallocated"
                setSound(jobCancelSoundUri, alertAudioAttributes)
                enableVibration(true)
                vibrationPattern = longArrayOf(0, 600, 300, 600)
                lockscreenVisibility = android.app.Notification.VISIBILITY_PUBLIC
            }

            // 3. Job Amended Channel
            val jobAmendedChannel = NotificationChannel(
                "job_amended_speech_v1",
                "Job Amendments (Voice Speech)",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Notification voice speech alerts when a job is amended or modified"
                setSound(jobAmendedSoundUri, alertAudioAttributes)
                enableVibration(true)
                vibrationPattern = longArrayOf(0, 500, 250, 500)
                lockscreenVisibility = android.app.Notification.VISIBILITY_PUBLIC
            }

            // 4. General Alert Channel
            val generalAlertChannel = NotificationChannel(
                "general_alert_speech_v1",
                "General Notifications (Voice Speech)",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Standard notifications and announcements with voice alerts"
                setSound(generalAlertSoundUri, alertAudioAttributes)
                enableVibration(true)
                vibrationPattern = longArrayOf(0, 250, 200, 250)
                lockscreenVisibility = android.app.Notification.VISIBILITY_PUBLIC
            }

            notificationManager.createNotificationChannel(jobOfferChannel)
            notificationManager.createNotificationChannel(jobCancelChannel)
            notificationManager.createNotificationChannel(jobAmendedChannel)
            notificationManager.createNotificationChannel(generalAlertChannel)
        }
    }
}
