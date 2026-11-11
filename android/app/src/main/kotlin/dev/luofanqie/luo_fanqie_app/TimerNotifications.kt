package dev.luofanqie.luo_fanqie_app

import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build

/**
 * 用 AlarmManager + BroadcastReceiver 在番茄结束时发通知。
 *
 * 这类提醒必须由系统在应用进程之外触发，所以不依赖 Dart 定时器。
 * Android 12+ 若没有精确闹钟权限，则退化为 setAndAllowWhileIdle，
 * 提醒可能略有延迟，但不会被完全丢弃。
 */
object TimerNotifications {
    private const val CHANNEL_ID = "pomodoro_timer"
    private const val NOTIFICATION_ID = 7301
    private const val ALARM_REQUEST_CODE = 7302
    private const val CONTENT_REQUEST_CODE = 7303

    const val EXTRA_TITLE = "notification_title"
    const val EXTRA_BODY = "notification_body"

    fun ensureChannel(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = context.getSystemService(NotificationManager::class.java) ?: return
        if (manager.getNotificationChannel(CHANNEL_ID) != null) return
        val channel = NotificationChannel(
            CHANNEL_ID,
            "专注提醒",
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "番茄完成与休息结束的提醒"
            enableVibration(true)
            setShowBadge(true)
        }
        manager.createNotificationChannel(channel)
    }

    fun schedule(
        context: Context,
        fireAtMillis: Long,
        title: String,
        body: String,
    ) {
        ensureChannel(context)
        val alarmManager = context.getSystemService(AlarmManager::class.java) ?: return
        val pendingIntent = alarmPendingIntent(context, title, body)
        alarmManager.cancel(pendingIntent)
        if (fireAtMillis <= System.currentTimeMillis()) return

        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S &&
                !alarmManager.canScheduleExactAlarms()
            ) {
                alarmManager.setAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    fireAtMillis,
                    pendingIntent,
                )
            } else {
                alarmManager.setExactAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    fireAtMillis,
                    pendingIntent,
                )
            }
        } catch (_: SecurityException) {
            // 没有精确闹钟权限时，系统仍允许非精确的唤醒闹钟。
            alarmManager.setAndAllowWhileIdle(
                AlarmManager.RTC_WAKEUP,
                fireAtMillis,
                pendingIntent,
            )
        }
    }

    fun cancel(context: Context) {
        val alarmManager = context.getSystemService(AlarmManager::class.java)
        alarmManager?.cancel(alarmPendingIntent(context, "", ""))
        context.getSystemService(NotificationManager::class.java)
            ?.cancel(NOTIFICATION_ID)
    }

    fun showNow(context: Context, title: String, body: String) {
        ensureChannel(context)
        val launchIntent = context.packageManager
            .getLaunchIntentForPackage(context.packageName)
            ?.apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            } ?: return
        val contentIntent = PendingIntent.getActivity(
            context,
            CONTENT_REQUEST_CODE,
            launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(context, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(context)
        }
        builder
            .setSmallIcon(R.drawable.ic_stat_tomato)
            .setContentTitle(title.ifBlank { "落·番茄" })
            .setContentText(body)
            .setStyle(Notification.BigTextStyle().bigText(body))
            .setContentIntent(contentIntent)
            .setAutoCancel(true)
            .setCategory(Notification.CATEGORY_REMINDER)
            .setVisibility(Notification.VISIBILITY_PUBLIC)

        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            @Suppress("DEPRECATION")
            builder.setPriority(Notification.PRIORITY_HIGH)
        }

        context.getSystemService(NotificationManager::class.java)
            ?.notify(NOTIFICATION_ID, builder.build())
    }

    private fun alarmPendingIntent(
        context: Context,
        title: String,
        body: String,
    ): PendingIntent {
        val intent = Intent(context, TimerAlarmReceiver::class.java).apply {
            putExtra(EXTRA_TITLE, title)
            putExtra(EXTRA_BODY, body)
        }
        return PendingIntent.getBroadcast(
            context,
            ALARM_REQUEST_CODE,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }
}
