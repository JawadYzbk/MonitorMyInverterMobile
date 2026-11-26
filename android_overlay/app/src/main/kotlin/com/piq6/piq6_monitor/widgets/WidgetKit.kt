package com.piq6.piq6_monitor.widgets

import android.app.PendingIntent
import android.content.Context
import android.content.SharedPreferences
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.DashPathEffect
import android.graphics.Paint
import android.graphics.Path
import android.graphics.RectF
import android.net.Uri
import com.piq6.piq6_monitor.MainActivity
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale

/** Shared helpers for the home screen widgets. Data comes from lib/services/widget_sync.dart. */
object Kit {
    // Same palette as the app / web dashboard.
    const val TEXT = 0xFFF4F4F5.toInt()
    const val MUTED = 0xFFA1A1AA.toInt()
    const val FAINT = 0xFF71717A.toInt()
    const val BORDER = 0xFF27272A.toInt()
    const val BATTERY = 0xFF34D399.toInt()
    const val DANGER = 0xFFF87171.toInt()
    const val SOLAR = 0xFFFBBF24.toInt()
    const val LOAD = 0xFFA78BFA.toInt()
    const val GRID_ON = 0xFF38BDF8.toInt()
    const val GRID_OFF = 0xFF5B2A30.toInt()
    const val NO_DATA = 0xFF27272A.toInt()

    /** Readings older than this are shown as stale. */
    private const val STALE_MS = 5 * 60_000L

    fun s(p: SharedPreferences, key: String, def: String = ""): String = p.getString(key, null) ?: def

    fun ms(p: SharedPreferences, key: String): Long? = s(p, key).toLongOrNull()?.takeIf { it > 0 }

    fun hasData(p: SharedPreferences) = s(p, "w_battery").isNotEmpty()

    fun clock(ms: Long): String = SimpleDateFormat("HH:mm", Locale.getDefault()).format(Date(ms))

    fun duration(ms: Long): String {
        val min = (ms / 60_000).coerceAtLeast(0)
        val h = min / 60
        val m = min % 60
        return if (h > 0) "${h}h ${m}m" else "${m}m"
    }

    private fun sameDay(a: Long, b: Long): Boolean {
        val ca = Calendar.getInstance().apply { timeInMillis = a }
        val cb = Calendar.getInstance().apply { timeInMillis = b }
        return ca.get(Calendar.YEAR) == cb.get(Calendar.YEAR) && ca.get(Calendar.DAY_OF_YEAR) == cb.get(Calendar.DAY_OF_YEAR)
    }

    /** "", "tomorrow " or "Wed " before a time, like the app. */
    fun dayWord(t: Long, now: Long = System.currentTimeMillis()): String = when {
        sameDay(t, now) -> ""
        sameDay(t, now + 86_400_000L) -> "tomorrow "
        else -> SimpleDateFormat("EEE ", Locale.getDefault()).format(Date(t))
    }

    fun isStale(p: SharedPreferences): Boolean {
        val u = ms(p, "w_updated") ?: return true
        return System.currentTimeMillis() - u > STALE_MS || s(p, "w_online") != "1"
    }

    /** Footer: "Updated 14:20", or why the numbers may be old. */
    fun updatedText(p: SharedPreferences): String {
        val u = ms(p, "w_updated") ?: return if (hasData(p)) "Signed out — open the app" else "Open the app to sign in"
        val ago = System.currentTimeMillis() - u
        return when {
            s(p, "w_online") != "1" -> "Inverter offline · ${clock(u)}"
            ago > STALE_MS -> "Not updated since ${clock(u)}"
            else -> "Updated ${clock(u)}"
        }
    }

    fun gridColor(state: String) = when (state) {
        "on" -> GRID_ON
        "off" -> DANGER
        else -> MUTED
    }

    fun gridWord(state: String) = when (state) {
        "on" -> "On"
        "off" -> "Off"
        else -> "—"
    }

    /** "since 14:20 · 2h 5m" for the current grid state. */
    fun gridSince(p: SharedPreferences): String {
        val since = ms(p, "w_grid_since") ?: return ""
        return "since ${clock(since)} · ${duration(System.currentTimeMillis() - since)}"
    }

    /** Short next-change line: "back ~18:30 · in 2h 5m" or "off ~21:00". */
    fun nextChange(p: SharedPreferences): String {
        if (s(p, "w_fc_status") != "ready") return ""
        val at = ms(p, "w_fc_at") ?: return ""
        val state = s(p, "w_fc_state")
        if (s(p, "w_fc_overdue") == "1") return if (state == "on") "overdue — usually back by now" else "usually off by now"
        val word = if (state == "on") "back" else "off"
        return "$word ~${dayWord(at)}${clock(at)} · in ${duration(at - System.currentTimeMillis())}"
    }

    fun openApp(context: Context): PendingIntent =
        HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java)

    fun refresh(context: Context): PendingIntent =
        HomeWidgetBackgroundIntent.getBroadcast(context, Uri.parse("piq6://refresh"))

    private fun mix(a: Int, b: Int, t: Float): Int {
        fun ch(shift: Int) = (((a shr shift) and 0xFF) + (((b shr shift) and 0xFF) - ((a shr shift) and 0xFF)) * t).toInt()
        return Color.argb(255, ch(16), ch(8), ch(0))
    }

    fun ints(p: SharedPreferences, key: String): List<Int> =
        s(p, key).split(',').mapNotNull { it.trim().toIntOrNull() }

    // --- bitmaps (RemoteViews can't draw shapes, so charts are images) ---

    /** Rounded level bar, e.g. battery %. */
    fun bar(fraction: Float, color: Int, w: Int = 400, h: Int = 18): Bitmap {
        val bmp = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
        val c = Canvas(bmp)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG)
        val r = h / 2f
        paint.color = BORDER
        c.drawRoundRect(RectF(0f, 0f, w.toFloat(), h.toFloat()), r, r, paint)
        val fw = (w * fraction.coerceIn(0f, 1f))
        if (fw > 0) {
            paint.color = color
            c.drawRoundRect(RectF(0f, 0f, fw.coerceAtLeast(h.toFloat()), h.toFloat()), r, r, paint)
        }
        return bmp
    }

    /** One cell per hour (0..100 = % of the hour with grid, -1 = no data), oldest first. */
    fun hourCells(values: List<Int>, w: Int = 720, h: Int = 40): Bitmap {
        val bmp = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
        if (values.isEmpty()) return bmp
        val c = Canvas(bmp)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG)
        val gap = 3f
        val cw = (w - gap * (values.size - 1)) / values.size
        values.forEachIndexed { i, v ->
            paint.color = if (v < 0) NO_DATA else mix(GRID_OFF, GRID_ON, v / 100f)
            val x = i * (cw + gap)
            c.drawRoundRect(RectF(x, 0f, x + cw, h.toFloat()), 4f, 4f, paint)
        }
        return bmp
    }

    /** Expected next 24 h: "on:90,off:60,..." minutes, drawn as one strip. */
    fun blocks(spec: String, w: Int = 720, h: Int = 40): Bitmap {
        val bmp = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
        val parts = spec.split(',').mapNotNull {
            val kv = it.split(':')
            if (kv.size == 2) kv[0] to (kv[1].toIntOrNull() ?: 0) else null
        }.filter { it.second > 0 }
        val total = parts.sumOf { it.second }
        if (total == 0) return bmp
        val c = Canvas(bmp)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG)
        // Clip to a rounded strip.
        val clip = Path().apply { addRoundRect(RectF(0f, 0f, w.toFloat(), h.toFloat()), 8f, 8f, Path.Direction.CW) }
        c.clipPath(clip)
        var x = 0f
        for ((state, minutes) in parts) {
            val bw = w * minutes / total.toFloat()
            paint.color = when (state) {
                "on" -> GRID_ON
                "off" -> GRID_OFF
                else -> NO_DATA
            }
            c.drawRect(x, 0f, x + bw + 1, h.toFloat(), paint)
            x += bw
        }
        return bmp
    }

    /** Last hours: solar + load (watts, shared scale) and battery % (dashed, own scale). */
    fun trend(battery: List<Int>, solar: List<Int>, load: List<Int>, w: Int = 720, h: Int = 220): Bitmap {
        val bmp = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
        val c = Canvas(bmp)
        val grid = Paint().apply { color = BORDER; strokeWidth = 2f; pathEffect = DashPathEffect(floatArrayOf(6f, 6f), 0f) }
        for (i in 1..3) c.drawLine(0f, h * i / 4f, w.toFloat(), h * i / 4f, grid)
        val maxW = (solar + load).maxOrNull()?.coerceAtLeast(100) ?: 100

        fun line(values: List<Int>, max: Int, color: Int, fill: Boolean, dashed: Boolean) {
            if (values.size < 2) return
            val path = Path()
            values.forEachIndexed { i, v ->
                val x = w * i / (values.size - 1f)
                val y = h - 4 - (h - 8) * (v.coerceIn(0, max) / max.toFloat())
                if (i == 0) path.moveTo(x, y) else path.lineTo(x, y)
            }
            if (fill) {
                val area = Path(path).apply { lineTo(w.toFloat(), h.toFloat()); lineTo(0f, h.toFloat()); close() }
                c.drawPath(area, Paint(Paint.ANTI_ALIAS_FLAG).apply { this.color = color; alpha = 45 })
            }
            c.drawPath(path, Paint(Paint.ANTI_ALIAS_FLAG).apply {
                this.color = color
                style = Paint.Style.STROKE
                strokeWidth = if (dashed) 3f else 4f
                strokeJoin = Paint.Join.ROUND
                if (dashed) pathEffect = DashPathEffect(floatArrayOf(10f, 7f), 0f)
            })
        }
        line(solar, maxW, SOLAR, fill = true, dashed = false)
        line(load, maxW, LOAD, fill = true, dashed = false)
        line(battery, 100, BATTERY, fill = false, dashed = true)
        return bmp
    }
}
