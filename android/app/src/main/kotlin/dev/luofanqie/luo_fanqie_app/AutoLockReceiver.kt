package dev.luofanqie.luo_fanqie_app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class AutoLockReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        AutoLockScheduler.fire(context)
    }
}
