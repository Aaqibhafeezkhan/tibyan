package app.tibyan.tibyan

import android.appwidget.AppWidgetManager
import android.content.Context
import android.os.Bundle
import android.content.SharedPreferences
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * «آية اليوم»: one verse a day. The app draws it from the whole mushaf
 * (verse_of_day.dart) and writes a month ahead (`vod_text_yyyy-MM-dd`,
 * `vod_ref_…`, `vod_uri_…`), so the day changes over without the app. A tap
 * opens the verse in the mushaf. Always right to left: the verse is Arabic.
 */
class VerseWidgetProvider : HomeWidgetProvider() {
  override fun onUpdate(
      context: Context,
      appWidgetManager: AppWidgetManager,
      appWidgetIds: IntArray,
      widgetData: SharedPreferences,
  ) {
    var day = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())
    // Past the days written (the app not opened for a month): the last one.
    if (widgetData.getString("vod_text_$day", null) == null) {
      widgetData.getString("vod_days", null)?.split(",")?.lastOrNull()?.let { day = it }
    }
    val text = widgetData.getString("vod_text_$day", null)
    val reference = widgetData.getString("vod_ref_$day", null)
    val uri = widgetData.getString("vod_uri_$day", null)
    val listen = widgetData.getString("vod_listen_$day", null)

    for (id in appWidgetIds) {
      // In the app's look, when the app has drawn it.
      val look =
          WidgetLooks.build(
              context,
              widgetData,
              appWidgetManager,
              id,
              "verse",
              mapOf(
                  "text" to (text ?: context.inAppLanguage(widgetData).getString(R.string.khatma_widget_open)),
                  "ref" to reference,
                  "surah" to widgetData.getString("vod_surah_$day", null),
                  "num" to widgetData.getString("vod_num_$day", null),
              ),
          ) { if (it == WidgetLooks.Shape.small) R.layout.wl_foot_full else R.layout.wl_foot_end }
      if (look != null) {
        val open = open(context, uri ?: "tibyan://action/continue?homeWidget")
        look.views.setOnClickPendingIntent(R.id.wl_main, open)
        if (look.shape == WidgetLooks.Shape.medium) look.views.setOnClickPendingIntent(R.id.wl_main2, open)
        look.views.setOnClickPendingIntent(R.id.wl_button, open(context, listen ?: uri ?: "tibyan://action/listen?homeWidget"))
        appWidgetManager.updateAppWidget(id, look.views)
        continue
      }
      val views = RemoteViews(context.packageName, R.layout.verse_widget)
      views.applyDirection(R.id.verse_root, widgetData, alwaysRtl = true)
      views.setTextViewText(
          R.id.verse_title,
          widgetData.getString("vod_title", null) ?: context.getString(R.string.verse_widget_label),
      )
      views.setTextViewText(R.id.verse_text, text ?: context.inAppLanguage(widgetData).getString(R.string.khatma_widget_open))
      if (reference.isNullOrEmpty()) {
        views.setViewVisibility(R.id.verse_reference, View.GONE)
      } else {
        views.setViewVisibility(R.id.verse_reference, View.VISIBLE)
        views.setTextViewText(R.id.verse_reference, reference)
      }
      views.setOnClickPendingIntent(
          R.id.verse_root,
          HomeWidgetLaunchIntent.getActivity(
              context,
              MainActivity::class.java,
              Uri.parse(uri ?: "tibyan://action/continue?homeWidget"),
          ),
      )
      appWidgetManager.updateAppWidget(id, views)
    }
  }

  private fun open(context: Context, uri: String) =
      HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java, Uri.parse(uri))

  // Resized: the nearer picture for the new size.
  override fun onAppWidgetOptionsChanged(
      context: Context,
      appWidgetManager: AppWidgetManager,
      appWidgetId: Int,
      newOptions: Bundle,
  ) = redraw(context, this, intArrayOf(appWidgetId))
}
