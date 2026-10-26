package app.tibyan.tibyan.wear

import android.app.PendingIntent
import android.content.Intent
import androidx.wear.watchface.complications.data.ComplicationData
import androidx.wear.watchface.complications.data.ComplicationType
import androidx.wear.watchface.complications.data.LongTextComplicationData
import androidx.wear.watchface.complications.data.PlainComplicationText
import androidx.wear.watchface.complications.data.RangedValueComplicationData
import androidx.wear.watchface.complications.data.ShortTextComplicationData

import androidx.wear.watchface.complications.datasource.ComplicationRequest
import androidx.wear.watchface.complications.datasource.SuspendingComplicationDataSourceService

/**
 * Today's portion on the watch face: a ranged value (the khatma's percent,
 * which faces draw as a ring) with the percent as text, or the surah and
 * pages as short or long text. A tap opens the app.
 */
class WirdComplicationService : SuspendingComplicationDataSourceService() {

  override fun getPreviewData(type: ComplicationType): ComplicationData? =
    build(type, getString(R.string.wird_title), getString(R.string.page_range, Look.number(22), Look.number(24)), 62, null)

  override suspend fun onComplicationRequest(request: ComplicationRequest): ComplicationData? {
    val w = WatchData.wird(this)
    val portion = when {
      !WatchData.hasData(this) -> getString(R.string.open_phone)
      w == null -> WatchData.value(this, "idle")
      w.from != null && w.to != null && w.from != w.to ->
        getString(R.string.page_range, Look.number(w.from), Look.number(w.to))
      w.from != null -> getString(R.string.page_one, Look.number(w.from))
      else -> w.portion
    }
    val title = w?.surah?.ifEmpty { null } ?: getString(R.string.wird_title)
    val tap = PendingIntent.getActivity(
      this,
      0,
      Intent(this, TasbihActivity::class.java),
      PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
    )
    return build(request.complicationType, title, portion, WatchData.percent(this), tap)
  }

  private fun build(
    type: ComplicationType,
    title: String,
    portion: String,
    percent: Int,
    tap: PendingIntent?,
  ): ComplicationData? {
    fun plain(s: String) = PlainComplicationText.Builder(s).build()
    val description = plain("$title، $portion، ${getString(R.string.khatma_percent, Look.percent(percent))}")
    return when (type) {
      ComplicationType.RANGED_VALUE ->
        RangedValueComplicationData.Builder(percent.toFloat(), 0f, 100f, description)
          .setText(plain(Look.percent(percent)))
          .setTitle(plain(title))
          .setTapAction(tap)
          .build()
      ComplicationType.SHORT_TEXT ->
        ShortTextComplicationData.Builder(plain(Look.percent(percent)), description)
          .setTitle(plain(title))
          .setTapAction(tap)
          .build()
      ComplicationType.LONG_TEXT ->
        LongTextComplicationData.Builder(plain(portion), description)
          .setTitle(plain(title))
          .setTapAction(tap)
          .build()
      else -> null
    }
  }
}
