package dev.luofanqie.luo_fanqie_app

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.drawable.GradientDrawable
import android.os.Handler
import android.os.Looper
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityManager
import android.widget.Button
import android.widget.FrameLayout
import android.widget.LinearLayout
import android.widget.TextView

/**
 * 学霸守护：
 * - 只在用户开启学霸模式期间工作；
 * - 只读取当前前台应用包名，不读取窗口内容、文字、密码；
 * - 离开落·番茄时显示全屏置顶提醒，计时结束自动回到应用；
 * - 用户可以随时点「结束守护」或关闭系统无障碍服务。
 */
class StrictGuardAccessibilityService : AccessibilityService() {
    private var overlay: View? = null
    private var countdownView: TextView? = null
    private val handler = Handler(Looper.getMainLooper())
    private var ticking = false

    private val ticker = object : Runnable {
        override fun run() {
            if (!active) {
                hideOverlay()
                return
            }
            val remaining = endAtMillis - System.currentTimeMillis()
            if (remaining <= 0) {
                finishGuard()
                return
            }
            countdownView?.text = formatDuration(remaining)
            handler.postDelayed(this, 500)
        }
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this
        serviceInfo?.apply {
            eventTypes = AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED or
                AccessibilityEvent.TYPE_WINDOWS_CHANGED
            feedbackType = AccessibilityServiceInfo.FEEDBACK_GENERIC
            notificationTimeout = 100
        }
        restoreGuard()
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (!active || event == null) return
        val packageName = event.packageName?.toString() ?: return
        if (packageName == this.packageName) {
            hideOverlay()
        } else if (
            event.eventType == AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED ||
            event.eventType == AccessibilityEvent.TYPE_WINDOWS_CHANGED
        ) {
            showOverlay()
        }
    }

    override fun onInterrupt() {
        hideOverlay()
    }

    override fun onDestroy() {
        hideOverlay()
        if (instance === this) instance = null
        super.onDestroy()
    }

    private fun restoreGuard() {
        val prefs = getSharedPreferences(PREFS, MODE_PRIVATE)
        val storedEnd = prefs.getLong(KEY_END_AT, 0L)
        if (prefs.getBoolean(KEY_ACTIVE, false) && storedEnd > System.currentTimeMillis()) {
            active = true
            endAtMillis = storedEnd
            guardTitle = prefs.getString(KEY_TITLE, "专注") ?: "专注"
        }
    }

    private fun showOverlay() {
        if (overlay != null || !active) return
        val root = FrameLayout(this).apply {
            setBackgroundColor(Color.parseColor("#FFF7F1"))
        }

        val card = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_HORIZONTAL
            setPadding(dp(30), dp(36), dp(30), dp(36))
            background = roundedBackground(Color.parseColor("#FFFFFBF7"), dp(28).toFloat())
        }

        val cat = TextView(this).apply {
            text = "🐱"
            textSize = 58f
            gravity = Gravity.CENTER
        }
        val kicker = TextView(this).apply {
            text = "落落来抓你回番茄田啦"
            textSize = 22f
            setTextColor(Color.parseColor("#3B2420"))
            gravity = Gravity.CENTER
        }
        val message = TextView(this).apply {
            text = "学霸模式进行中。先把这一颗番茄吃完，再去做别的事吧。"
            textSize = 14f
            setTextColor(Color.parseColor("#8A6B60"))
            gravity = Gravity.CENTER
            setLineSpacing(dp(4).toFloat(), 1f)
        }
        val task = TextView(this).apply {
            text = "正在专注：$guardTitle"
            textSize = 13f
            setTextColor(Color.parseColor("#C44A31"))
            gravity = Gravity.CENTER
            setPadding(0, dp(16), 0, dp(4))
        }
        countdownView = TextView(this).apply {
            text = formatDuration((endAtMillis - System.currentTimeMillis()).coerceAtLeast(0))
            textSize = 46f
            setTextColor(Color.parseColor("#E85B3C"))
            gravity = Gravity.CENTER
            setPadding(0, dp(8), 0, dp(18))
        }
        val backButton = Button(this).apply {
            text = "回到专注"
            textSize = 15f
            setTextColor(Color.WHITE)
            background = roundedBackground(Color.parseColor("#E85B3C"), dp(18).toFloat())
            setOnClickListener {
                hideOverlay()
                launchApp()
            }
        }
        val stopButton = Button(this).apply {
            text = "结束守护"
            textSize = 14f
            setTextColor(Color.parseColor("#8A6B60"))
            background = roundedBackground(Color.parseColor("#F3E7DF"), dp(18).toFloat())
            setOnClickListener {
                stopGuard(this@StrictGuardAccessibilityService)
                launchApp()
            }
        }

        card.addView(cat)
        card.addView(kicker)
        card.addView(message)
        card.addView(task)
        card.addView(countdownView)
        card.addView(
            backButton,
            LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                dp(52),
            ).apply { topMargin = dp(4) },
        )
        card.addView(
            stopButton,
            LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                dp(46),
            ).apply { topMargin = dp(10) },
        )

        val frameParams = FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.MATCH_PARENT,
            FrameLayout.LayoutParams.WRAP_CONTENT,
            Gravity.CENTER,
        ).apply { leftMargin = dp(22); rightMargin = dp(22) }
        root.addView(card, frameParams)
        overlay = root

        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY,
            WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS or
                WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON,
            PixelFormat.TRANSLUCENT,
        ).apply {
            gravity = Gravity.TOP or Gravity.START
        }
        try {
            (getSystemService(Context.WINDOW_SERVICE) as WindowManager).addView(root, params)
        } catch (error: Exception) {
            overlay = null
            return
        }
        if (!ticking) {
            ticking = true
            handler.post(ticker)
        }
    }

    private fun hideOverlay() {
        ticking = false
        handler.removeCallbacks(ticker)
        val view = overlay ?: return
        overlay = null
        countdownView = null
        try {
            (getSystemService(Context.WINDOW_SERVICE) as WindowManager)
                .removeViewImmediate(view)
        } catch (_: Exception) {
            // 已经移除时忽略。
        }
    }

    private fun finishGuard() {
        active = false
        getSharedPreferences(PREFS, MODE_PRIVATE).edit().clear().apply()
        hideOverlay()
        launchApp()
    }

    private fun launchApp() {
        val intent = (packageManager.getLaunchIntentForPackage(packageName)
            ?: Intent(this, MainActivity::class.java)).apply {
            addFlags(
                Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_REORDER_TO_FRONT or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP,
            )
            putExtra("strict_guard_finished", true)
        }
        try {
            startActivity(intent)
        } catch (_: Exception) {
            // 后台启动被系统拦截时，用户仍可点通知或手动打开应用。
        }
    }

    private fun formatDuration(millis: Long): String {
        val total = (millis / 1000).coerceAtLeast(0)
        val minutes = total / 60
        val seconds = total % 60
        return "%02d:%02d".format(minutes, seconds)
    }

    private fun roundedBackground(color: Int, radius: Float): GradientDrawable {
        return GradientDrawable().apply {
            setColor(color)
            cornerRadius = radius
        }
    }

    private fun dp(value: Int): Int {
        return (value * resources.displayMetrics.density).toInt()
    }

    companion object {
        private const val PREFS = "luo_fanqie_strict_guard"
        private const val KEY_ACTIVE = "active"
        private const val KEY_END_AT = "end_at"
        private const val KEY_TITLE = "title"

        @Volatile private var instance: StrictGuardAccessibilityService? = null

        @Volatile private var active = false

        @Volatile private var endAtMillis = 0L

        @Volatile private var guardTitle = "专注"

        fun isEnabled(context: Context): Boolean {
            val manager = context.getSystemService(Context.ACCESSIBILITY_SERVICE)
                as? AccessibilityManager ?: return false
            val expected = ComponentName(context, StrictGuardAccessibilityService::class.java)
            return manager.getEnabledAccessibilityServiceList(
                AccessibilityServiceInfo.FEEDBACK_ALL_MASK,
            ).any { info ->
                val serviceInfo = info.resolveInfo.serviceInfo
                serviceInfo.packageName == expected.packageName &&
                    serviceInfo.name == expected.className
            }
        }

        fun startGuard(context: Context, endAt: Long, title: String): Boolean {
            active = endAt > System.currentTimeMillis()
            endAtMillis = endAt
            guardTitle = title.ifBlank { "专注" }
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                .edit()
                .putBoolean(KEY_ACTIVE, active)
                .putLong(KEY_END_AT, endAt)
                .putString(KEY_TITLE, guardTitle)
                .apply()
            instance?.let {
                it.restoreGuard()
                it.showOverlayIfNeeded()
            }
            return active && isEnabled(context)
        }

        fun stopGuard(context: Context) {
            active = false
            endAtMillis = 0L
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                .edit().clear().apply()
            instance?.hideOverlay()
        }
    }

    private fun showOverlayIfNeeded() {
        // 不主动盖住正在使用的落·番茄；等用户切到其他 App 的事件再展示。
    }
}
