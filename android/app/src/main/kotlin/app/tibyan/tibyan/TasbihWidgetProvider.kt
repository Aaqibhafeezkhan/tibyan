package app.tibyan.tibyan

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.net.Uri
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * «المسبحة» on the home screen: the dhikr being counted, today's count of
 * it, and a button that counts without opening the app. The count waits in
 * `tasbih_pending` (home_widget's preferences) until the app adds it to the
 * log; the dhikr opens the misbaha.
 */
class TasbihWidgetProvider : HomeWidgetProvider() {
  override fun onUpdate(
      context: Context,
      appWidgetManager: AppWidgetManager,
      appWidgetIds: IntArray,
      widgetData: SharedPreferences,
  ) {
    val count = (widgetData.getString("tasbih_count", null)?.toIntOrNull() ?: 0) +
        widgetData.getInt(PENDING, 0)
    val ar = (widgetData.getString("lang", null) ?: "ar").startsWith("ar")
    val stage = stageLabel(widgetData, ar)
    for (id in appWidgetIds) {
      val views = RemoteViews(context.packageName, R.layout.tasbih_widget)
      views.applyDirection(R.id.tasbih_root, widgetData)
      views.setTextViewText(
          R.id.tasbih_dhikr,
          widgetData.getString("tasbih_dhikr", null) ?: context.getString(R.string.tasbih_widget_label),
      )
      views.setTextViewText(
          R.id.tasbih_count,
          stage ?: if (ar) arabicDigits(count) else "$count",
      )
      views.setOnClickPendingIntent(
          R.id.tasbih_dhikr,
          HomeWidgetLaunchIntent.getActivity(
              context,
              MainActivity::class.java,
              Uri.parse("tibyan://action/tasbih?homeWidget"),
          ),
      )
      views.setOnClickPendingIntent(
          R.id.tasbih_button,
          PendingIntent.getBroadcast(
              context,
              0,
              Intent(context, TasbihWidgetProvider::class.java).setAction(COUNT),
              PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
          ),
      )
      appWidgetManager.updateAppWidget(id, views)
    }
  }

  override fun onReceive(context: Context, intent: Intent) {
    if (intent.action != COUNT) return super.onReceive(context, intent)
    val prefs = context.getSharedPreferences(PREFERENCES, Context.MODE_PRIVATE)
    prefs.edit().putInt(PENDING, prefs.getInt(PENDING, 0) + 1).apply()
    val v = context.getSystemService(Vibrator::class.java)
    if (v != null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
      v.vibrate(VibrationEffect.createPredefined(VibrationEffect.EFFECT_TICK))
    }
    val manager = AppWidgetManager.getInstance(context)
    val ids = manager.getAppWidgetIds(ComponentName(context, TasbihWidgetProvider::class.java))
    onUpdate(context, manager, ids, prefs)
  }

  /**
   * For a dhikr said in stages (`tasbih_stages`: `33,33,33,1`), the stage
   * and the count in it as the widget counts: «٢/٤ · ١٢/٣٣». The round's
   * count is what the app last wrote plus the widget's own counts.
   */
  private fun stageLabel(data: SharedPreferences, ar: Boolean): String? {
    val stages = (data.getString("tasbih_stages", null) ?: "")
        .split(",").mapNotNull { it.trim().toIntOrNull() }
    if (stages.isEmpty()) return null
    val total = stages.sum()
    var at = (data.getInt("tasbih_round", 0) + data.getInt(PENDING, 0)) % total
    var i = 0
    while (at >= stages[i]) {
      at -= stages[i]
      i++
    }
    fun d(n: Int) = if (ar) arabicDigits(n) else "$n"
    return "${d(i + 1)}/${d(stages.size)} · ${d(at)}/${d(stages[i])}"
  }

  private fun arabicDigits(n: Int): String =
      n.toString().map { (0x0660 + (it - '0')).toChar() }.joinToString("")

  companion object {
    const val COUNT = "app.tibyan.tibyan.TASBIH_WIDGET_COUNT"
    const val PREFERENCES = "HomeWidgetPreferences"
    const val PENDING = "tasbih_pending"
  }
}
