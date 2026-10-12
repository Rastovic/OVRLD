package com.rastovic.ovrld

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.graphics.Color
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider
import java.util.Calendar

/**
 * The app publishes all seven days of the active plan; the widget picks
 * today's itself. So it turns over at midnight (updatePeriodMillis) even if
 * the app is never opened.
 */
internal object Today {
    const val INK = 0xFF101011.toInt()
    const val SURFACE = 0xFF19191B.toInt()
    const val BONE = 0xFFEBE6DC.toInt()
    const val MUTE = 0xFF8D887F.toInt()
    private val DAYS = arrayOf("MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN")
    private val MONTHS = arrayOf("JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC")

    fun index(offset: Int = 0): Int {
        val c = Calendar.getInstance()
        c.add(Calendar.DAY_OF_YEAR, offset)
        return (c.get(Calendar.DAY_OF_WEEK) + 5) % 7 // Monday = 0
    }

    fun dateLabel(): String {
        val c = Calendar.getInstance()
        return "${DAYS[index()]} ${c.get(Calendar.DAY_OF_MONTH)} ${MONTHS[c.get(Calendar.MONTH)]}"
    }

    fun todayKey(): String {
        val c = Calendar.getInstance()
        return String.format(
            java.util.Locale.ROOT, "%04d-%02d-%02d",
            c.get(Calendar.YEAR), c.get(Calendar.MONTH) + 1, c.get(Calendar.DAY_OF_MONTH),
        )
    }

    /** Ink on light colours, bone on dark ones - same rule as the app. */
    fun on(color: Int): Int {
        fun ch(v: Int): Double {
            val c = v / 255.0
            return if (c <= 0.03928) c / 12.92 else Math.pow((c + 0.055) / 1.055, 2.4)
        }
        val l = 0.2126 * ch(Color.red(color)) + 0.7152 * ch(Color.green(color)) + 0.0722 * ch(Color.blue(color))
        return if (l > 0.18) INK else BONE
    }

    fun kind(d: SharedPreferences, i: Int) = d.getString("d${i}_kind", "rest") ?: "rest"
    fun word(d: SharedPreferences, i: Int) = d.getString("d${i}_word", "REST") ?: "REST"
    fun title(d: SharedPreferences, i: Int) = d.getString("d${i}_title", "REST") ?: "REST"
    fun sub(d: SharedPreferences, i: Int) = d.getString("d${i}_sub", "") ?: ""
    fun color(d: SharedPreferences, i: Int) = d.getInt("d${i}_color", 0xFF6B6862.toInt())
    fun doneToday(d: SharedPreferences) = d.getString("done_day", "") == todayKey()
    fun hasPlan(d: SharedPreferences) = d.getBoolean("has_plan", false)
}

class TodayWidgetSmall : HomeWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray, data: SharedPreferences) {
        val i = Today.index()
        val rest = Today.kind(data, i) == "rest"
        val done = Today.doneToday(data)
        for (id in ids) {
            val v = RemoteViews(context.packageName, R.layout.widget_small)
            val bg = if (rest || !Today.hasPlan(data)) Today.SURFACE else Today.color(data, i)
            val fg = if (rest || !Today.hasPlan(data)) Today.BONE else Today.on(bg)
            v.setInt(R.id.bg, "setColorFilter", bg)
            v.setViewVisibility(R.id.border, if (rest) View.VISIBLE else View.GONE)
            v.setTextViewText(R.id.top, if (done) "DONE ✓" else if (rest) Today.dateLabel() else "TODAY")
            v.setTextColor(R.id.top, if (rest) Today.MUTE else fg)
            if (!Today.hasPlan(data)) {
                v.setTextViewText(R.id.word, "OVRLD")
                v.setTextViewText(R.id.sub, "Open to plan your week")
            } else {
                v.setTextViewText(R.id.word, Today.word(data, i))
                v.setTextViewText(
                    R.id.sub,
                    if (rest) "Next: ${Today.word(data, Today.index(1)).lowercase()}" else Today.sub(data, i),
                )
            }
            v.setViewVisibility(R.id.word, if (rest) View.GONE else View.VISIBLE)
            v.setViewVisibility(R.id.word_thin, if (rest) View.VISIBLE else View.GONE)
            v.setTextViewText(R.id.word_thin, "REST")
            v.setTextColor(R.id.word, fg)
            v.setTextColor(R.id.sub, if (rest) Today.MUTE else fg)
            v.setOnClickPendingIntent(R.id.root, HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java))
            manager.updateAppWidget(id, v)
        }
    }
}

class TodayWidgetWide : HomeWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray, data: SharedPreferences) {
        val i = Today.index()
        val rest = Today.kind(data, i) == "rest"
        val color = Today.color(data, i)
        val lineIds = intArrayOf(R.id.l0, R.id.l1, R.id.l2, R.id.l3)
        val detailIds = intArrayOf(R.id.d0, R.id.d1, R.id.d2, R.id.d3)
        val rowIds = intArrayOf(R.id.r0, R.id.r1, R.id.r2, R.id.r3)
        for (id in ids) {
            val v = RemoteViews(context.packageName, R.layout.widget_wide)
            v.setTextViewText(R.id.date, if (Today.doneToday(data)) "DONE ✓" else Today.dateLabel())
            if (!Today.hasPlan(data)) {
                v.setTextViewText(R.id.title, "OVRLD")
                v.setTextColor(R.id.title, Today.BONE)
                v.setTextViewText(R.id.sub, "Open the app to plan your week")
            } else {
                v.setTextViewText(R.id.title, if (rest) "REST DAY" else Today.title(data, i))
                v.setTextColor(R.id.title, if (rest) Today.BONE else color)
                v.setTextViewText(
                    R.id.sub,
                    if (rest) "Tomorrow: ${Today.title(data, Today.index(1)).lowercase()}" else Today.sub(data, i),
                )
            }
            val lines = if (rest) emptyList() else (data.getString("d${i}_lines", "") ?: "").split("\n").filter { it.isNotBlank() }
            for (k in 0 until 4) {
                if (k < lines.size) {
                    val parts = lines[k].split("|")
                    v.setViewVisibility(rowIds[k], View.VISIBLE)
                    v.setTextViewText(lineIds[k], parts[0])
                    v.setTextViewText(detailIds[k], parts.getOrElse(1) { "" })
                } else {
                    v.setViewVisibility(rowIds[k], View.GONE)
                }
            }
            v.setInt(R.id.stripe, "setColorFilter", if (rest) 0xFF6B6862.toInt() else color)
            v.setOnClickPendingIntent(R.id.root, HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java))
            manager.updateAppWidget(id, v)
        }
    }
}
