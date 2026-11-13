package dev.luofanqie.luo_fanqie_app

import android.Manifest
import android.app.ActivityManager
import android.app.NotificationManager
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.provider.Settings
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        TimerNotifications.ensureChannel(this)
        restoreDndIfNeeded()

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            NOTIFICATION_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "requestPermission" -> {
                    requestNotificationPermission()
                    result.success(null)
                }

                "schedule" -> {
                    val fireAtMillis = call.argument<Number>("fireAtMillis")?.toLong()
                    val title = call.argument<String>("title").orEmpty()
                    val body = call.argument<String>("body").orEmpty()
                    if (fireAtMillis == null || fireAtMillis <= 0L) {
                        result.error("invalid_arguments", "fireAtMillis is required", null)
                    } else {
                        TimerNotifications.schedule(
                            context = this,
                            fireAtMillis = fireAtMillis,
                            title = title,
                            body = body,
                        )
                        result.success(null)
                    }
                }

                "cancel" -> {
                    TimerNotifications.cancel(this)
                    result.success(null)
                }

                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            IMMERSIVE_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "isStrictGuardEnabled" -> {
                    result.success(
                        StrictGuardAccessibilityService.isEnabled(this),
                    )
                }

                "openAccessibilitySettings" -> {
                    try {
                        startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))
                        result.success(null)
                    } catch (error: Exception) {
                        result.error("accessibility_settings_failed", error.message, null)
                    }
                }

                "startLockTask" -> {
                    try {
                        val activityManager = getSystemService(ActivityManager::class.java)
                        if (activityManager?.lockTaskModeState ==
                            ActivityManager.LOCK_TASK_MODE_NONE
                        ) {
                            startLockTask()
                        }
                        result.success(null)
                    } catch (error: Exception) {
                        result.error("lock_task_failed", error.message, null)
                    }
                }

                "stopLockTask" -> {
                    try {
                        val activityManager = getSystemService(ActivityManager::class.java)
                        if (activityManager?.lockTaskModeState !=
                            ActivityManager.LOCK_TASK_MODE_NONE
                        ) {
                            stopLockTask()
                        }
                        result.success(null)
                    } catch (error: Exception) {
                        result.error("unlock_task_failed", error.message, null)
                    }
                }

                "isDndAccessGranted" -> {
                    val manager = getSystemService(NotificationManager::class.java)
                    result.success(manager?.isNotificationPolicyAccessGranted == true)
                }

                "openDndAccessSettings" -> {
                    try {
                        startActivity(Intent(Settings.ACTION_NOTIFICATION_POLICY_ACCESS_SETTINGS))
                        result.success(null)
                    } catch (error: Exception) {
                        result.error("dnd_settings_failed", error.message, null)
                    }
                }

                "startDnd" -> {
                    val manager = getSystemService(NotificationManager::class.java)
                    if (manager == null || !manager.isNotificationPolicyAccessGranted) {
                        result.success(false)
                    } else {
                        val prefs = getSharedPreferences(DND_PREFS, MODE_PRIVATE)
                        if (!prefs.contains(DND_PREVIOUS)) {
                            prefs.edit()
                                .putInt(DND_PREVIOUS, manager.currentInterruptionFilter)
                                .apply()
                        }
                        manager.setInterruptionFilter(
                            NotificationManager.INTERRUPTION_FILTER_NONE,
                        )
                        result.success(true)
                    }
                }

                "stopDnd" -> {
                    val manager = getSystemService(NotificationManager::class.java)
                    val prefs = getSharedPreferences(DND_PREFS, MODE_PRIVATE)
                    if (manager != null && prefs.contains(DND_PREVIOUS)) {
                        manager.setInterruptionFilter(
                            prefs.getInt(DND_PREVIOUS, NotificationManager.INTERRUPTION_FILTER_ALL),
                        )
                        prefs.edit().remove(DND_PREVIOUS).apply()
                    }
                    result.success(null)
                }

                "startStrictGuard" -> {
                    val endAtMillis = call.argument<Number>("endAtMillis")?.toLong()
                    val title = call.argument<String>("title").orEmpty()
                    if (endAtMillis == null || endAtMillis <= System.currentTimeMillis()) {
                        result.error("invalid_arguments", "endAtMillis is required", null)
                    } else {
                        val started = StrictGuardAccessibilityService.startGuard(
                            this,
                            endAtMillis,
                            title,
                        )
                        result.success(started)
                    }
                }

                "stopStrictGuard" -> {
                    StrictGuardAccessibilityService.stopGuard(this)
                    result.success(null)
                }

                "keepScreenOn" -> {
                    window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                    result.success(null)
                }

                "clearKeepScreenOn" -> {
                    window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                    result.success(null)
                }

                else -> result.notImplemented()
            }
        }
    }

    private fun restoreDndIfNeeded() {
        val manager = getSystemService(NotificationManager::class.java) ?: return
        val prefs = getSharedPreferences(DND_PREFS, MODE_PRIVATE)
        if (prefs.contains(DND_PREVIOUS) && manager.isNotificationPolicyAccessGranted) {
            manager.setInterruptionFilter(
                prefs.getInt(DND_PREVIOUS, NotificationManager.INTERRUPTION_FILTER_ALL),
            )
            prefs.edit().remove(DND_PREVIOUS).apply()
        }
    }

    private fun requestNotificationPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            requestPermissions(
                arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                NOTIFICATION_PERMISSION_REQUEST,
            )
        }
    }

    companion object {
        private const val NOTIFICATION_CHANNEL = "dev.luofanqie/notifications"
        private const val DND_PREFS = "luo_fanqie_dnd"
        private const val DND_PREVIOUS = "previous_filter"
        private const val IMMERSIVE_CHANNEL = "dev.luofanqie/immersive"
        private const val NOTIFICATION_PERMISSION_REQUEST = 7300
    }
}
