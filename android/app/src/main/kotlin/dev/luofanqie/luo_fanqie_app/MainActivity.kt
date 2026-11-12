package dev.luofanqie.luo_fanqie_app

import android.Manifest
import android.app.ActivityManager
import android.content.pm.PackageManager
import android.os.Build
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        TimerNotifications.ensureChannel(this)

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
        private const val IMMERSIVE_CHANNEL = "dev.luofanqie/immersive"
        private const val NOTIFICATION_PERMISSION_REQUEST = 7300
    }
}
