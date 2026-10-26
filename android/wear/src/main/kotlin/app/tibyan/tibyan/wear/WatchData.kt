package app.tibyan.tibyan.wear

import android.content.Context
import android.content.SharedPreferences
import androidx.wear.tiles.TileService
import com.google.android.gms.wearable.DataEvent
import com.google.android.gms.wearable.DataEventBuffer
import com.google.android.gms.wearable.DataItem
import com.google.android.gms.wearable.DataMapItem
import com.google.android.gms.wearable.PutDataMapRequest
import com.google.android.gms.wearable.Wearable
import com.google.android.gms.wearable.WearableListenerService
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * The phone's data on the watch (the `/tibyan/state` item, kept here for
 * when the phone is away) and the counts sent back as `/tibyan/taps`.
 */
object WatchData {
  private const val STATE = "/tibyan/state"
  private const val TAPS = "/tibyan/taps"

  private fun state(c: Context): SharedPreferences =
      c.getSharedPreferences("state", Context.MODE_PRIVATE)

  fun counts(c: Context): SharedPreferences =
      c.getSharedPreferences("counts", Context.MODE_PRIVATE)

  fun value(c: Context, key: String): String = state(c).getString(key, null) ?: ""

  fun hasData(c: Context): Boolean = state(c).all.isNotEmpty()

  /** Today's portion and where it starts, if the phone wrote one. */
  fun today(c: Context): Pair<String, String>? {
    val key = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())
    val portion = value(c, "portion_$key")
    return if (portion.isEmpty()) null else portion to value(c, "ref_$key")
  }

  fun save(c: Context, item: DataItem) {
    if (item.uri.path != STATE) return
    val map = DataMapItem.fromDataItem(item).dataMap
    state(c).edit().clear().apply {
      for (k in map.keySet()) putString(k, map.getString(k))
    }.apply()
    TileService.getUpdater(c).requestUpdate(WirdTileService::class.java)
    try {
      androidx.wear.watchface.complications.datasource.ComplicationDataSourceUpdateRequester
          .create(c, android.content.ComponentName(c, WirdComplicationService::class.java))
          .requestUpdateAll()
    } catch (_: Exception) {}
  }

  /** Reads the phone's current item, for a first start or a missed change. */
  fun refresh(c: Context, then: () -> Unit) {
    Wearable.getDataClient(c).dataItems.addOnSuccessListener { items ->
      for (item in items) save(c, item)
      items.release()
      then()
    }
  }

  /** Sends the running total of counts; the phone adds what is new. */
  fun sendTotal(c: Context) {
    val total = counts(c).getLong("total", 0)
    val request = PutDataMapRequest.create(TAPS).apply {
      dataMap.putLong("total", total)
    }.asPutDataRequest().setUrgent()
    Wearable.getDataClient(c).putDataItem(request)
  }
}

/** Keeps the phone's data as it changes, and redraws the tile. */
class StateListenerService : WearableListenerService() {
  override fun onDataChanged(events: DataEventBuffer) {
    for (event in events) {
      if (event.type == DataEvent.TYPE_CHANGED) WatchData.save(applicationContext, event.dataItem)
    }
  }
}
