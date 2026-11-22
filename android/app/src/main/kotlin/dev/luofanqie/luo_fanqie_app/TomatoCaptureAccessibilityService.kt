package dev.luofanqie.luo_fanqie_app

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.AccessibilityServiceInfo
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.drawable.GradientDrawable
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.view.accessibility.AccessibilityEvent
import android.view.accessibility.AccessibilityManager
import android.view.accessibility.AccessibilityNodeInfo
import android.widget.Button
import org.json.JSONArray

/**
 * 番茄ToDo 页面导入服务。
 *
 * 只有目标应用在前台时显示一个小按钮；只有用户点击按钮时才抓取当前窗口文字。
 * 不持续读取，不读取密码/聊天，抓取结果只保存在本机待确认。
 */
class TomatoCaptureAccessibilityService : AccessibilityService() {
    private var overlay: View? = null

    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this
        serviceInfo?.apply {
            eventTypes = AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED or
                AccessibilityEvent.TYPE_WINDOWS_CHANGED
            feedbackType = AccessibilityServiceInfo.FEEDBACK_GENERIC
            notificationTimeout = 100
        }
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) return
        val packageName = event.packageName?.toString() ?: return
        val target = getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getString(KEY_TARGET, "") ?: ""
        if (target.isNotEmpty() && packageName == target) {
            showButton()
        } else {
            hideButton()
        }
    }

    override fun onInterrupt() {
        hideButton()
    }

    override fun onDestroy() {
        hideButton()
        if (instance === this) instance = null
        super.onDestroy()
    }

    private fun showButton() {
        if (overlay != null) return
        val button = Button(this).apply {
            text = "导入此页"
            textSize = 12f
            setTextColor(Color.WHITE)
            background = GradientDrawable().apply {
                setColor(Color.parseColor("#D45137"))
                cornerRadius = dp(18).toFloat()
            }
            setOnClickListener {
                captureCurrentPage()
            }
        }
        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.WRAP_CONTENT,
            dp(40),
            WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY,
            WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
            PixelFormat.TRANSLUCENT,
        ).apply {
            gravity = Gravity.TOP or Gravity.END
            x = dp(12)
            y = dp(120)
        }
        try {
            (getSystemService(Context.WINDOW_SERVICE) as WindowManager)
                .addView(button, params)
            overlay = button
        } catch (_: Exception) {
            overlay = null
        }
    }

    private fun hideButton() {
        val view = overlay ?: return
        overlay = null
        try {
            (getSystemService(Context.WINDOW_SERVICE) as WindowManager)
                .removeViewImmediate(view)
        } catch (_: Exception) {
            // Already removed.
        }
    }

    private fun captureCurrentPage() {
        val root = rootInActiveWindow ?: return
        val texts = JSONArray()
        val seen = mutableSetOf<String>()
        collectText(root, texts, seen)
        getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit()
            .putString(KEY_PENDING, texts.toString())
            .putLong(KEY_CAPTURED_AT, System.currentTimeMillis())
            .apply()
        hideButton()
        launchApp()
    }

    private fun collectText(
        node: AccessibilityNodeInfo?,
        output: JSONArray,
        seen: MutableSet<String>,
    ) {
        if (node == null || output.length() >= 180) return
        val text = node.text?.toString()?.trim().orEmpty()
        if (text.isNotEmpty() && text.length <= 300 && seen.add(text)) {
            output.put(text)
        }
        for (index in 0 until node.childCount) {
            collectText(node.getChild(index), output, seen)
        }
    }

    private fun launchApp() {
        val intent = packageManager.getLaunchIntentForPackage(packageName)
            ?: return
        intent.addFlags(
            Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_REORDER_TO_FRONT,
        )
        startActivity(intent)
    }

    private fun dp(value: Int): Int =
        (value * resources.displayMetrics.density).toInt()

    companion object {
        private const val PREFS = "luo_fanqie_capture"
        private const val KEY_TARGET = "target_package"
        const val KEY_PENDING = "pending_texts"
        const val KEY_CAPTURED_AT = "captured_at"

        @Volatile private var instance: TomatoCaptureAccessibilityService? = null

        fun setTarget(context: Context, packageName: String) {
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                .edit()
                .putString(KEY_TARGET, packageName)
                .apply()
        }

        fun consumePending(context: Context): String {
            val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            val raw = prefs.getString(KEY_PENDING, "[]") ?: "[]"
            prefs.edit().remove(KEY_PENDING).apply()
            return raw
        }

        fun isEnabled(context: Context): Boolean {
            val manager = context.getSystemService(Context.ACCESSIBILITY_SERVICE)
                as? AccessibilityManager ?: return false
            val expected = ComponentName(
                context,
                TomatoCaptureAccessibilityService::class.java,
            )
            return manager.getEnabledAccessibilityServiceList(
                AccessibilityServiceInfo.FEEDBACK_ALL_MASK,
            ).any { info ->
                val serviceInfo = info.resolveInfo.serviceInfo
                serviceInfo.packageName == expected.packageName &&
                    serviceInfo.name == expected.className
            }
        }
    }
}
