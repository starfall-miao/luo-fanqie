package dev.luofanqie.luo_fanqie_app

import android.Manifest
import android.app.ActivityManager
import android.app.AppOpsManager
import android.app.NotificationManager
import android.app.usage.UsageStatsManager
import android.content.ComponentName
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.net.Uri
import android.os.PowerManager
import android.provider.Settings
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray
import android.os.Process

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        TimerNotifications.ensureChannel(this)
        restoreDndIfNeeded()
        configureAppChannel(flutterEngine)
        configureUsageChannel(flutterEngine)

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

                "scheduleAutoLock" -> {
                    val hour = call.argument<Number>("hour")?.toInt()
                    val minute = call.argument<Number>("minute")?.toInt()
                    if (hour == null || minute == null) {
                        result.error("invalid_arguments", "hour/minute required", null)
                    } else {
                        AutoLockScheduler.schedule(this, hour, minute)
                        result.success(null)
                    }
                }

                "cancelAutoLock" -> {
                    AutoLockScheduler.cancel(this)
                    result.success(null)
                }

                "isIgnoringBatteryOptimizations" -> {
                    val power = getSystemService(PowerManager::class.java)
                    result.success(
                        power?.isIgnoringBatteryOptimizations(packageName) == true,
                    )
                }

                "requestIgnoreBatteryOptimizations" -> {
                    try {
                        val intent = Intent(
                            Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS,
                            Uri.parse("package:$packageName"),
                        )
                        startActivity(intent)
                        result.success(null)
                    } catch (error: Exception) {
                        result.error("battery_optimization_failed", error.message, null)
                    }
                }

                "openAutostartSettings" -> {
                    val intents = listOf(
                        Intent().setComponent(
                            ComponentName(
                                "com.miui.securitycenter",
                                "com.miui.permcenter.autostart.AutoStartManagementActivity",
                            ),
                        ),
                        Intent().setComponent(
                            ComponentName(
                                "com.huawei.systemmanager",
                                "com.huawei.systemmanager.startupmgr.ui.StartupNormalAppListActivity",
                            ),
                        ),
                        Intent().setComponent(
                            ComponentName(
                                "com.coloros.safecenter",
                                "com.coloros.safecenter.permission.startup.StartupAppListActivity",
                            ),
                        ),
                        Intent().setComponent(
                            ComponentName(
                                "com.vivo.permissionmanager",
                                "com.vivo.permissionmanager.activity.BgStartUpManagerActivity",
                            ),
                        ),
                        Intent().setComponent(
                            ComponentName(
                                "com.samsung.android.lool",
                                "com.samsung.android.sm.ui.battery.BatteryActivity",
                            ),
                        ),
                    )
                    var launched = false
                    for (intent in intents) {
                        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        try {
                            startActivity(intent)
                            launched = true
                            break
                        } catch (_: Exception) {
                            // 尝试下一个厂商页面。
                        }
                    }
                    if (!launched) {
                        try {
                            startActivity(
                                Intent(
                                    Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                                    Uri.parse("package:$packageName"),
                                ),
                            )
                        } catch (_: Exception) {
                            // 设置页也无法打开时保持静默。
                        }
                    }
                    result.success(null)
                }

                "isNotificationListenerEnabled" -> {
                    val component = ComponentName(
                        this,
                        FocusNotificationGuardService::class.java,
                    )
                    val granted = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
                        getSystemService(NotificationManager::class.java)
                            ?.isNotificationListenerAccessGranted(component) == true
                    } else {
                        val enabled = Settings.Secure.getString(
                            contentResolver,
                            "enabled_notification_listeners",
                        ).orEmpty()
                        enabled.contains(component.flattenToString()) ||
                            enabled.contains(component.flattenToShortString())
                    }
                    result.success(granted)
                }

                "openNotificationListenerSettings" -> {
                    try {
                        startActivity(Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS))
                        result.success(null)
                    } catch (error: Exception) {
                        result.error("listener_settings_failed", error.message, null)
                    }
                }

                "startNotificationGuard" -> {
                    val endAtMillis = call.argument<Number>("endAtMillis")?.toLong()
                    if (endAtMillis == null || endAtMillis <= System.currentTimeMillis()) {
                        result.success(false)
                    } else {
                        FocusNotificationGuardService.start(this, endAtMillis)
                        result.success(true)
                    }
                }

                "stopNotificationGuard" -> {
                    FocusNotificationGuardService.stop(this)
                    result.success(null)
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
                    val whitelist = call.argument<List<String>>("whitelist") ?: emptyList()
                    if (endAtMillis == null || endAtMillis <= System.currentTimeMillis()) {
                        result.error("invalid_arguments", "endAtMillis is required", null)
                    } else {
                        val started = StrictGuardAccessibilityService.startGuard(
                            this,
                            endAtMillis,
                            title,
                            whitelist,
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

    private fun configureUsageChannel(flutterEngine: FlutterEngine) {
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            USAGE_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "hasUsageAccess" -> result.success(hasUsageAccess())
                "openUsageAccessSettings" -> {
                    try {
                        startActivity(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS))
                        result.success(null)
                    } catch (error: Exception) {
                        result.error("usage_settings_failed", error.message, null)
                    }
                }
                "queryUsage" -> {
                    val start = call.argument<Number>("startMillis")?.toLong()
                    val end = call.argument<Number>("endMillis")?.toLong()
                    if (start == null || end == null || end <= start) {
                        result.error("invalid_arguments", "startMillis/endMillis required", null)
                    } else if (!hasUsageAccess()) {
                        result.error("usage_access_denied", "需要系统使用情况访问权限", null)
                    } else {
                        try {
                            result.success(queryUsage(start, end))
                        } catch (error: Exception) {
                            result.error("query_usage_failed", error.message, null)
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun hasUsageAccess(): Boolean {
        val appOps = getSystemService(AppOpsManager::class.java) ?: return false
        val mode = appOps.checkOpNoThrow(
            AppOpsManager.OPSTR_GET_USAGE_STATS,
            Process.myUid(),
            packageName,
        )
        return mode == AppOpsManager.MODE_ALLOWED
    }

    private fun queryUsage(start: Long, end: Long): String {
        val manager = getSystemService(UsageStatsManager::class.java)
            ?: return "[]"
        val grouped = mutableMapOf<String, Long>()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val stats = manager.queryAndAggregateUsageStats(start, end)
            for ((packageName, stat) in stats) {
                if (stat.totalTimeInForeground > 0) {
                    grouped[packageName] = stat.totalTimeInForeground
                }
            }
        } else {
            val stats = manager.queryUsageStats(
                UsageStatsManager.INTERVAL_DAILY,
                start,
                end,
            )
            for (stat in stats) {
                if (stat.totalTimeInForeground > 0) {
                    grouped[stat.packageName] =
                        (grouped[stat.packageName] ?: 0L) + stat.totalTimeInForeground
                }
            }
        }
        val apps = JSONArray()
        for ((packageName, millis) in grouped.entries.sortedByDescending { it.value }) {
            if (packageName == this.packageName) continue
            val launchIntent = packageManager.getLaunchIntentForPackage(packageName)
                ?: continue
            if (launchIntent == null) continue
            val label = try {
                packageManager.getApplicationLabel(
                    packageManager.getApplicationInfo(packageName, 0),
                ).toString()
            } catch (_: Exception) {
                packageName
            }
            apps.put(
                org.json.JSONObject()
                    .put("packageName", packageName)
                    .put("label", label)
                    .put("minutes", millis / 60000L),
            )
        }
        return apps.toString()
    }

    private fun configureAppChannel(flutterEngine: FlutterEngine) {
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            APP_CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "listApps" -> {
                    try {
                        val intent = Intent(Intent.ACTION_MAIN).apply {
                            addCategory(Intent.CATEGORY_LAUNCHER)
                        }
                        val infos = packageManager.queryIntentActivities(
                            intent,
                            PackageManager.MATCH_ALL,
                        )
                        val seen = mutableSetOf<String>()
                        val apps = JSONArray()
                        for (info in infos) {
                            val packageName = info.activityInfo.packageName
                            if (packageName == this.packageName || !seen.add(packageName)) {
                                continue
                            }
                            val label = info.loadLabel(packageManager).toString()
                            val isVendorApp = VENDOR_PREFIXES.any {
                                packageName.startsWith(it)
                            }
                            val isEducation = !isVendorApp &&
                                EDUCATION_WORDS.any {
                                    label.lowercase().contains(it) ||
                                        packageName.lowercase().contains(it)
                                }
                            apps.put(
                                org.json.JSONObject()
                                    .put("packageName", packageName)
                                    .put("label", label)
                                    .put("education", isEducation),
                            )
                        }
                        result.success(apps.toString())
                    } catch (error: Exception) {
                        result.error("list_apps_failed", error.message, null)
                    }
                }

                "launchApp" -> {
                    val packageName = call.argument<String>("packageName")
                    if (packageName.isNullOrBlank()) {
                        result.error("invalid_arguments", "packageName is required", null)
                    } else {
                        val intent = packageManager.getLaunchIntentForPackage(packageName)
                        if (intent == null) {
                            result.error("app_not_found", "找不到可启动的 App", null)
                        } else {
                            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            try {
                                startActivity(intent)
                                result.success(true)
                            } catch (error: Exception) {
                                result.error("launch_failed", error.message, null)
                            }
                        }
                    }
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
        private const val APP_CHANNEL = "dev.luofanqie/apps"
        private const val USAGE_CHANNEL = "dev.luofanqie/usage"

        private val VENDOR_PREFIXES = listOf(
            "com.android.",
            "com.miui.",
            "com.xiaomi.",
            "com.huawei.",
            "com.honor.",
            "com.samsung.",
            "com.oppo.",
            "com.coloros.",
            "com.vivo.",
            "com.oneplus.",
            "com.meizu.",
            "com.lenovo.",
        )

        private val EDUCATION_WORDS = listOf(
            "学习", "课程", "教育", "单词", "词典", "口语", "听力", "刷题",
            "作业", "考试", "考研", "四六级", "anki", "quizlet", "duolingo",
            "coursera", "khan", "udemy", "edx", "背单词", "网课",
        )
        private const val IMMERSIVE_CHANNEL = "dev.luofanqie/immersive"
        private const val NOTIFICATION_PERMISSION_REQUEST = 7300
    }
}
