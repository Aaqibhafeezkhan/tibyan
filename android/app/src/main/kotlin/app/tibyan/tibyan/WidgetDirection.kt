package app.tibyan.tibyan

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.content.res.Configuration
import java.util.Locale
import es.antonborri.home_widget.HomeWidgetProvider
import android.view.View
import android.widget.RemoteViews

/**
 * Every widget reads in the app's language (`lang`, written by the app),
 * not the device's: Arabic is laid out right to left even on a phone set
 * to English, and the reverse.
 */
fun RemoteViews.applyDirection(rootId: Int, widgetData: SharedPreferences, alwaysRtl: Boolean = false) {
  val rtl = alwaysRtl || (widgetData.getString("lang", null) ?: "ar").startsWith("ar")
  setInt(rootId, "setLayoutDirection", if (rtl) View.LAYOUT_DIRECTION_RTL else View.LAYOUT_DIRECTION_LTR)
}

/** Draws [ids] of [provider] again from the widget data (a resize, a new look). */
fun redraw(context: Context, provider: HomeWidgetProvider, ids: IntArray) {
  provider.onUpdate(
      context,
      AppWidgetManager.getInstance(context),
      ids,
      context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE),
  )
}

/** The app's language as it last wrote it (`lang`), Arabic by default. */
fun appLanguage(widgetData: SharedPreferences): String = widgetData.getString("lang", null) ?: "ar"

/** Whether [lang] reads right to left. */
fun isRtlLanguage(lang: String): Boolean = lang.startsWith("ar")

/**
 * [this] with its resources in the app's language, not the device's: the
 * widgets' own words («المسبحة», «افتح تبيان») follow the app.
 */
fun Context.inAppLanguage(widgetData: SharedPreferences): Context =
    createConfigurationContext(
        Configuration(resources.configuration).apply { setLocale(Locale(appLanguage(widgetData))) },
    )
