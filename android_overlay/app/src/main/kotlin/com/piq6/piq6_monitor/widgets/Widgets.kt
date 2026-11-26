package com.piq6.piq6_monitor.widgets

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.view.View
import android.widget.RemoteViews
import com.piq6.piq6_monitor.R
import es.antonborri.home_widget.HomeWidgetProvider

/** Base: draws every instance of a widget from the saved data; tap opens the app. */
abstract class Piq6Widget : HomeWidgetProvider() {
    abstract val layout: Int
    abstract fun bind(context: Context, v: RemoteViews, p: SharedPreferences)

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        for (id in appWidgetIds) {
            val v = RemoteViews(context.packageName, layout)
            v.setOnClickPendingIntent(R.id.widget_root, Kit.openApp(context))
            try {
                bind(context, v, widgetData)
            } catch (_: Exception) {
                // Never leave a widget blank because of one bad value.
            }
            appWidgetManager.updateAppWidget(id, v)
        }
    }

    protected fun footer(v: RemoteViews, p: SharedPreferences) {
        v.setTextViewText(R.id.updated, Kit.updatedText(p))
        v.setTextColor(R.id.updated, if (Kit.isStale(p)) Kit.SOLAR else Kit.FAINT)
    }

    protected fun refreshButton(context: Context, v: RemoteViews) {
        v.setOnClickPendingIntent(R.id.refresh, Kit.refresh(context))
    }

    protected fun batteryColor(p: SharedPreferences) = if (Kit.s(p, "w_low") == "1") Kit.DANGER else Kit.BATTERY
}

/** 2x2 — battery level, charging / draining, alert colour. */
class BatteryWidget : Piq6Widget() {
    override val layout = R.layout.widget_battery

    override fun bind(context: Context, v: RemoteViews, p: SharedPreferences) {
        val pct = Kit.s(p, "w_battery").toIntOrNull()
        val color = batteryColor(p)
        v.setTextViewText(R.id.bat_value, pct?.let { "$it%" } ?: "—")
        v.setTextColor(R.id.bat_value, color)
        v.setImageViewBitmap(R.id.bat_bar, Kit.bar((pct ?: 0) / 100f, color))
        val flow = Kit.s(p, "w_batt_flow")
        v.setTextViewText(R.id.bat_detail, listOf(Kit.s(p, "w_batt_volts"), flow).filter { it.isNotEmpty() }.joinToString(" · "))
        val low = Kit.s(p, "w_low") == "1"
        v.setTextViewText(R.id.bat_label, if (low) "Battery low · alert ${Kit.s(p, "w_threshold", "25")}%" else "Battery")
        v.setTextColor(R.id.bat_label, if (low) Kit.DANGER else Kit.MUTED)
        footer(v, p)
    }
}

/** 2x2 — grid on/off, how long, when it should change. */
class GridWidget : Piq6Widget() {
    override val layout = R.layout.widget_grid

    override fun bind(context: Context, v: RemoteViews, p: SharedPreferences) {
        val state = Kit.s(p, "w_grid", "unknown")
        v.setTextViewText(R.id.grid_value, Kit.gridWord(state))
        v.setTextColor(R.id.grid_value, Kit.gridColor(state))
        v.setTextViewText(R.id.grid_volts, Kit.s(p, "w_grid_volts"))
        val since = Kit.gridSince(p)
        v.setTextViewText(R.id.grid_since, since)
        v.setViewVisibility(R.id.grid_since, if (since.isEmpty()) View.GONE else View.VISIBLE)
        val next = Kit.nextChange(p)
        v.setTextViewText(R.id.grid_next, next)
        v.setViewVisibility(R.id.grid_next, if (next.isEmpty()) View.GONE else View.VISIBLE)
        footer(v, p)
    }
}

/** 2x2 — solar vs load right now, and where the difference goes. */
class PowerWidget : Piq6Widget() {
    override val layout = R.layout.widget_power

    override fun bind(context: Context, v: RemoteViews, p: SharedPreferences) {
        v.setTextViewText(R.id.solar_value, "${Kit.s(p, "w_solar", "0")} W")
        v.setTextViewText(R.id.load_value, "${Kit.s(p, "w_load", "0")} W")
        v.setTextViewText(R.id.power_net, Kit.s(p, "w_net"))
        v.setTextColor(R.id.power_net, if (Kit.s(p, "w_net_sign") == "1") Kit.BATTERY else Kit.SOLAR)
        footer(v, p)
    }
}

/** 4x2 — the four live tiles from the app's overview, with refresh. */
class OverviewWidget : Piq6Widget() {
    override val layout = R.layout.widget_overview

    override fun bind(context: Context, v: RemoteViews, p: SharedPreferences) {
        refreshButton(context, v)
        val pct = Kit.s(p, "w_battery").toIntOrNull()
        val bColor = batteryColor(p)
        v.setTextViewText(R.id.ov_bat, pct?.let { "$it%" } ?: "—")
        v.setTextColor(R.id.ov_bat, bColor)
        v.setTextViewText(R.id.ov_bat_sub, Kit.s(p, "w_batt_flow"))
        v.setImageViewBitmap(R.id.ov_bat_bar, Kit.bar((pct ?: 0) / 100f, bColor, 200, 12))

        val state = Kit.s(p, "w_grid", "unknown")
        v.setTextViewText(R.id.ov_grid, Kit.gridWord(state))
        v.setTextColor(R.id.ov_grid, Kit.gridColor(state))
        val since = Kit.ms(p, "w_grid_since")?.let { Kit.duration(System.currentTimeMillis() - it) }
        v.setTextViewText(R.id.ov_grid_sub, since ?: Kit.s(p, "w_grid_volts"))

        v.setTextViewText(R.id.ov_solar, Kit.s(p, "w_solar", "0"))
        v.setTextViewText(R.id.ov_solar_sub, "W · ${Kit.s(p, "w_pv_volts")}")
        v.setTextViewText(R.id.ov_load, Kit.s(p, "w_load", "0"))
        v.setTextViewText(R.id.ov_load_sub, "W · ${Kit.s(p, "w_load_pct")}")
        footer(v, p)
    }
}

/** 4x2 — next grid change, last 24 h and expected next 24 h. */
class ForecastWidget : Piq6Widget() {
    override val layout = R.layout.widget_forecast

    override fun bind(context: Context, v: RemoteViews, p: SharedPreferences) {
        refreshButton(context, v)
        val status = Kit.s(p, "w_fc_status")
        val at = Kit.ms(p, "w_fc_at")
        val state = Kit.s(p, "w_fc_state")
        val headline: String
        var detail = ""
        var color = Kit.TEXT
        when {
            status == "learning" -> {
                headline = Kit.s(p, "w_fc_learning", "Learning your grid schedule…")
            }
            at == null -> {
                headline = if (status.isEmpty()) "Open the app to load the forecast" else "No forecast right now"
            }
            Kit.s(p, "w_fc_overdue") == "1" -> {
                headline = if (state == "on") "Grid overdue — usually back by now" else "Grid usually off by now"
                color = Kit.gridColor(state)
            }
            else -> {
                val word = if (state == "on") "back" else "off"
                headline = "Grid $word at ${Kit.dayWord(at)}${Kit.clock(at)} · in ${Kit.duration(at - System.currentTimeMillis())}"
                color = Kit.gridColor(state)
                val e = Kit.ms(p, "w_fc_earliest")
                val l = Kit.ms(p, "w_fc_latest")
                if (e != null && l != null) detail = "Likely ${Kit.clock(e)}–${Kit.clock(l)}"
                Kit.ms(p, "w_fc_then_on")?.let { detail += " · then back ~${Kit.dayWord(it)}${Kit.clock(it)}" }
            }
        }
        val conf = Kit.s(p, "w_fc_conf")
        if (status == "ready" && conf.isNotEmpty()) detail = if (detail.isEmpty()) conf else "$detail · $conf"
        v.setTextViewText(R.id.fc_headline, headline)
        v.setTextColor(R.id.fc_headline, color)
        v.setTextViewText(R.id.fc_detail, detail)
        v.setViewVisibility(R.id.fc_detail, if (detail.isEmpty()) View.GONE else View.VISIBLE)

        v.setImageViewBitmap(R.id.fc_past, Kit.hourCells(Kit.ints(p, "w_past24")))
        val next = Kit.s(p, "w_next24")
        v.setImageViewBitmap(R.id.fc_next, Kit.blocks(next))
        v.setViewVisibility(R.id.fc_next_row, if (next.isEmpty()) View.GONE else View.VISIBLE)
        val today = Kit.s(p, "w_today_on")
        val cuts = Kit.s(p, "w_cuts24")
        v.setTextViewText(
            R.id.fc_stats,
            if (today.isEmpty()) "" else "Grid today $today · $cuts cut${if (cuts == "1") "" else "s"} in 24 h",
        )
        footer(v, p)
    }
}

/** 4x2 — last 4 hours of solar, load and battery, plus battery rate. */
class TrendWidget : Piq6Widget() {
    override val layout = R.layout.widget_trend

    override fun bind(context: Context, v: RemoteViews, p: SharedPreferences) {
        refreshButton(context, v)
        val batt = Kit.ints(p, "w_trend_batt")
        v.setImageViewBitmap(R.id.trend_chart, Kit.trend(batt, Kit.ints(p, "w_trend_solar"), Kit.ints(p, "w_trend_load")))
        val start = Kit.ms(p, "w_trend_start")
        val end = Kit.ms(p, "w_trend_end")
        v.setTextViewText(R.id.trend_from, start?.let { Kit.clock(it) } ?: "")
        v.setTextViewText(R.id.trend_to, end?.let { Kit.clock(it) } ?: "")
        val rate = Kit.s(p, "w_trend_rate")
        val pct = Kit.s(p, "w_battery")
        v.setTextViewText(
            R.id.trend_summary,
            when {
                batt.size < 2 -> "Waiting for readings…"
                rate.isNotEmpty() -> "$rate · now $pct%"
                else -> "Battery now $pct%"
            },
        )
        footer(v, p)
    }
}
