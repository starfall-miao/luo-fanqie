package dev.luofanqie.luo_fanqie_app

import android.content.Context
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification

/**
 * 系统勿扰不可用时的兜底：用系统 snooze 把通知暂时收起，
 * 专注结束后由系统自动放回。不会读取通知内容，也不伪造通知。
 */
class FocusNotificationGuardService : NotificationListenerService() {
    override fun onListenerConnected() {
        super.onListenerConnected()
        instance = this
        restore()
    }

    override fun onNotificationPosted(sbn: StatusBarNotification?) {
        if (sbn == null || !active) return
        if (sbn.packageName == packageName) return
        if (sbn.isOngoing) return
        val remaining = endAtMillis - System.currentTimeMillis()
        if (remaining <= 0) {
            active = false
            return
        }
        try {
            snoozeNotification(sbn.key, remaining)
        } catch (_: Exception) {
            // 部分 ROM 不允许 snooze，忽略即可。
        }
    }

    override fun onDestroy() {
        if (instance === this) instance = null
        super.onDestroy()
    }

    private fun restore() {
        val prefs = getSharedPreferences(PREFS, MODE_PRIVATE)
        val storedEnd = prefs.getLong(KEY_END_AT, 0L)
        if (prefs.getBoolean(KEY_ACTIVE, false) && storedEnd > System.currentTimeMillis()) {
            active = true
            endAtMillis = storedEnd
        }
    }

    companion object {
        private const val PREFS = "luo_fanqie_notification_guard"
        private const val KEY_ACTIVE = "active"
        private const val KEY_END_AT = "end_at"

        @Volatile private var instance: FocusNotificationGuardService? = null

        @Volatile private var active = false

        @Volatile private var endAtMillis = 0L

        fun start(context: Context, endAt: Long) {
            active = endAt > System.currentTimeMillis()
            endAtMillis = endAt
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                .edit()
                .putBoolean(KEY_ACTIVE, active)
                .putLong(KEY_END_AT, endAt)
                .apply()
        }

        fun stop(context: Context) {
            active = false
            endAtMillis = 0L
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                .edit().clear().apply()
        }
    }
}
