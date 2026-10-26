package app.tibyan.tibyan.wear

import android.app.PendingIntent
import android.content.Intent
import androidx.wear.watchface.complications.data.ComplicationData
import androidx.wear.watchface.complications.data.ComplicationType
import androidx.wear.watchface.complications.data.LongTextComplicationData
import androidx.wear.watchface.complications.data.PlainComplicationText
import androidx.wear.watchface.complications.data.ShortTextComplicationData
import androidx.wear.watchface.complications.datasource.ComplicationRequest
import androidx.wear.watchface.complications.datasource.SuspendingComplicationDataSourceService

/**
 * Complication data source showing today's wird progress from the khatma
 * (the portion e.g. "ص ١ - ٤" and title "الختمة"). Tapping opens the
 * misbaha/app.
 */
class WirdComplicationService : SuspendingComplicationDataSourceService() {

  override fun getPreviewData(type: ComplicationType): ComplicationData? {
    val title = getString(R.string.wird_title)
    val portion = "ص ١ - ٤"
    return createComplicationData(type, title, portion, null)
  }

  override suspend fun onComplicationRequest(request: ComplicationRequest): ComplicationData? {
    val today = WatchData.today(this)
    val title = WatchData.value(this, "title").ifEmpty { getString(R.string.wird_title) }
    val portion =
        today?.first
            ?: WatchData.value(this, "idle").ifEmpty { getString(R.string.open_phone) }

    val intent = Intent(this, TasbihActivity::class.java)
    val tapAction =
        PendingIntent.getActivity(
            this,
            0,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

    return createComplicationData(request.complicationType, title, portion, tapAction)
  }

  private fun createComplicationData(
      type: ComplicationType,
      title: String,
      portion: String,
      tapAction: PendingIntent?,
  ): ComplicationData? {
    val text = PlainComplicationText.Builder(portion).build()
    val titleText = PlainComplicationText.Builder(title).build()

    return when (type) {
      ComplicationType.SHORT_TEXT -> {
        ShortTextComplicationData.Builder(text, text)
            .setTitle(titleText)
            .setTapAction(tapAction)
            .build()
      }
      ComplicationType.LONG_TEXT -> {
        LongTextComplicationData.Builder(text, text)
            .setTitle(titleText)
            .setTapAction(tapAction)
            .build()
      }
      else -> null
    }
  }
}
