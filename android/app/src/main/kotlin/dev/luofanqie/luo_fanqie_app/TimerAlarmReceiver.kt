package dev.luofanqie.luo_fanqie_app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class TimerAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val title = intent.getStringExtra(TimerNotifications.EXTRA_TITLE).orEmpty()
        val body = intent.getStringExtra(TimerNotifications.EXTRA_BODY).orEmpty()
        TimerNotifications.showNow(context, title, body)
    }
}
