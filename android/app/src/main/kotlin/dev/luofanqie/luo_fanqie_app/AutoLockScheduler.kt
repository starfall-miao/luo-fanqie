package dev.luofanqie.luo_fanqie_app

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build

/**
 * 每日自动锁机闹钟。到点尝试把应用带到前台，由 Flutter 启动严格锁机；
 * 部分 ROM 限制后台启动时退化为高优先级通知。
 */
object AutoLockScheduler {
    private const val PREFS = "luo_fanqie_auto_lock"
    private const val KEY_ENABLED = "enabled"
    private const val KEY_HOUR = "hour"
    private const val KEY_MINUTE = "minute"
    private const val REQUEST_CODE = 7410

    fun schedule(context: Context, hour: Int, minute: Int) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit()
            .putBoolean(KEY_ENABLED, true)
            .putInt(KEY_HOUR, hour)
            .putInt(KEY_MINUTE, minute)
            .apply()
        scheduleNext(context)
    }

    fun cancel(context: Context) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit().clear().apply()
        val pending = alarmIntent(context)
        context.getSystemService(AlarmManager::class.java)?.cancel(pending)
    }

    fun scheduleNext(context: Context) {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        if (!prefs.getBoolean(KEY_ENABLED, false)) return
        val hour = prefs.getInt(KEY_HOUR, 21)
        val minute = prefs.getInt(KEY_MINUTE, 0)
        val now = System.currentTimeMillis()
        val calendar = java.util.Calendar.getInstance().apply {
            timeInMillis = now
            set(java.util.Calendar.HOUR_OF_DAY, hour)
            set(java.util.Calendar.MINUTE, minute)
            set(java.util.Calendar.SECOND, 0)
            set(java.util.Calendar.MILLISECOND, 0)
            if (timeInMillis <= now) add(java.util.Calendar.DAY_OF_YEAR, 1)
        }
        val fireAt = calendar.timeInMillis
        val pending = alarmIntent(context)
        val manager = context.getSystemService(AlarmManager::class.java) ?: return
        manager.cancel(pending)
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S &&
                !manager.canScheduleExactAlarms()
            ) {
                manager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, fireAt, pending)
            } else {
                manager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, fireAt, pending)
            }
        } catch (_: SecurityException) {
            manager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, fireAt, pending)
        }
    }

    fun fire(context: Context) {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        if (!prefs.getBoolean(KEY_ENABLED, false)) return
        val intent = Intent(context, MainActivity::class.java).apply {
            addFlags(
                Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_REORDER_TO_FRONT or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP,
            )
            putExtra("auto_lock_alarm", true)
        }
        try {
            context.startActivity(intent)
        } catch (_: Exception) {
            // 后台启动被 ROM 拦截，继续发通知作为兜底。
            TimerNotifications.showNow(
                context,
                "锁机时间到",
                "落落来收番茄了，点一下回来开始锁机。",
            )
        }
        scheduleNext(context)
    }

    private fun alarmIntent(context: Context): PendingIntent {
        val intent = Intent(context, AutoLockReceiver::class.java)
        return PendingIntent.getBroadcast(
            context,
            REQUEST_CODE,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }
}
