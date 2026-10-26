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

  private fun dayKey() = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())

  /** Today's portion and where it starts, if the phone wrote one. */
  fun today(c: Context): Pair<String, String>? {
    val key = dayKey()
    val portion = value(c, "portion_$key")
    return if (portion.isEmpty()) null else portion to value(c, "ref_$key")
  }

  /** Today's portion as the watch screens show it, if one is due. */
  fun wird(c: Context): Wird? {
    val key = dayKey()
    val portion = value(c, "portion_$key")
    if (portion.isEmpty()) return null
    return Wird(
      surah = value(c, "surah_$key"),
      from = value(c, "from_$key").toIntOrNull(),
      to = value(c, "to_$key").toIntOrNull(),
      portion = portion,
    )
  }

  /** The khatma's progress in percent (0 when the phone sent none). */
  fun percent(c: Context): Int = value(c, "progress").toIntOrNull()?.coerceIn(0, 100) ?: 0

  /** Where the misbaha's [session] count stands in the current dhikr. */
  fun tasbih(c: Context, session: Int): TasbihState {
    val texts = value(c, "tasbih_stage_texts").split('\n').filter { it.isNotBlank() }
    val stages = value(c, "tasbih_stages").split(',').mapNotNull { it.trim().toIntOrNull() }
      .filter { it > 0 }
    val dhikr = value(c, "tasbih_dhikr")
    if (stages.isNotEmpty()) {
      val total = stages.sum()
      var n = session % total
      if (n == 0 && session > 0) n = total
      var i = 0
      while (i < stages.size - 1 && n > stages[i]) { n -= stages[i]; i++ }
      return TasbihState(texts.getOrNull(i) ?: dhikr, n, stages[i], i + 1, stages.size)
    }
    val target = value(c, "tasbih_target").toIntOrNull() ?: 0
    if (target <= 0) return TasbihState(dhikr, session, 0, 0, 0)
    var n = session % target
    if (n == 0 && session > 0) n = target
    return TasbihState(dhikr, n, target, 0, 0)
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

/** Today's portion: [from] and [to] are pages; [portion] the phone's own line. */
data class Wird(val surah: String, val from: Int?, val to: Int?, val portion: String)

/**
 * The count shown: [count] of [target] (0 for an open count) in [label];
 * for a dhikr said in stages, stage [stage] of [stages].
 */
data class TasbihState(
  val label: String,
  val count: Int,
  val target: Int,
  val stage: Int,
  val stages: Int,
)

/** Keeps the phone's data as it changes, and redraws the tile. */
class StateListenerService : WearableListenerService() {
  override fun onDataChanged(events: DataEventBuffer) {
    for (event in events) {
      if (event.type == DataEvent.TYPE_CHANGED) WatchData.save(applicationContext, event.dataItem)
    }
  }
}
