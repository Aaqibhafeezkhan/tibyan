package app.tibyan.tibyan

import android.content.Context
import android.os.Handler
import android.os.Looper
import com.google.android.gms.wearable.DataEvent
import com.google.android.gms.wearable.DataEventBuffer
import com.google.android.gms.wearable.DataMapItem
import com.google.android.gms.wearable.PutDataMapRequest
import com.google.android.gms.wearable.Wearable
import com.google.android.gms.wearable.WearableListenerService
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject

/**
 * «الساعة» (`app.tibyan/watch`): what the Wear OS app shows (today's portion
 * from the khatma widget keys, the current dhikr) goes to it as one Data
 * Layer item, `/tibyan/state`. Counts made on the watch come back as the
 * item `/tibyan/taps` (a running total per watch) and join the misbaha's
 * pending counts, like the home screen widget's (docs/WATCH.md).
 */
class WatchBridge(private val context: Context, messenger: BinaryMessenger) {
  init {
    MethodChannel(messenger, "app.tibyan/watch").setMethodCallHandler { call, result ->
      if (call.method != "push") {
        result.notImplemented()
        return@setMethodCallHandler
      }
      @Suppress("UNCHECKED_CAST")
      push(context, (call.arguments as? Map<String, String>) ?: emptyMap())
      result.success(null)
    }
  }

  companion object {
    const val STATE = "/tibyan/state"
    const val TAPS = "/tibyan/taps"
    private const val PREFS = "TibyanWatch"

    /** Called on the main thread when the watch added counts (app running). */
    @Volatile var onPending: (() -> Unit)? = null

    fun push(context: Context, entries: Map<String, String>) {
      val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
      val saved = JSONObject(prefs.getString("context", null) ?: "{}")
      // A new set of days replaces the old ones; the tap links stay here.
      if (entries.containsKey("days")) {
        saved.keys().asSequence().toList()
          .filter { it.startsWith("portion_") || it.startsWith("ref_") }
          .forEach { saved.remove(it) }
      }
      for ((k, v) in entries) if (!k.startsWith("uri_")) saved.put(k, v)
      prefs.edit().putString("context", saved.toString()).apply()
      val request = PutDataMapRequest.create(STATE).apply {
        for (k in saved.keys()) dataMap.putString(k, saved.getString(k))
      }.asPutDataRequest().setUrgent()
      try {
        Wearable.getDataClient(context).putDataItem(request)
      } catch (e: Exception) {
        // No Google Play services: no watch.
      }
    }

    /** Adds the watch's new counts (since the last total seen) to pending. */
    fun takeTaps(context: Context, source: String, total: Long) {
      val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
      val key = "seen_$source"
      val seen = prefs.getLong(key, 0)
      // A smaller total: the watch app was reinstalled and counts afresh.
      val added = if (total >= seen) total - seen else total
      prefs.edit().putLong(key, total).apply()
      if (added <= 0) return
      val widget = context.getSharedPreferences(
        TasbihWidgetProvider.PREFERENCES, Context.MODE_PRIVATE,
      )
      widget.edit().putInt(
        TasbihWidgetProvider.PENDING,
        widget.getInt(TasbihWidgetProvider.PENDING, 0) + added.toInt(),
      ).apply()
      Handler(Looper.getMainLooper()).post { onPending?.invoke() }
    }
  }
}

/** Wakes for the watch's counts, even when the app is closed. */
class WatchListenerService : WearableListenerService() {
  override fun onDataChanged(events: DataEventBuffer) {
    for (event in events) {
      if (event.type != DataEvent.TYPE_CHANGED) continue
      val item = event.dataItem
      if (item.uri.path != WatchBridge.TAPS) continue
      val total = DataMapItem.fromDataItem(item).dataMap.getLong("total")
      WatchBridge.takeTaps(applicationContext, item.uri.host ?: "", total)
    }
  }
}
