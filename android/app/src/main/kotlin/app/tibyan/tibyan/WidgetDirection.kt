package app.tibyan.tibyan

import android.content.SharedPreferences
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
