package app.tibyan.tibyan

import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.IBinder
import com.huawei.wearengine.HiWear
import com.huawei.wearengine.auth.AuthCallback
import com.huawei.wearengine.auth.Permission
import com.huawei.wearengine.device.Device
import com.huawei.wearengine.p2p.Message
import com.huawei.wearengine.p2p.SendCallback
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale

/**
 * «الساعة» in the Huawei AppGallery build: the same `app.tibyan/watch`
 * contract as the Wear OS bridge (src/gms), over Huawei Wear Engine to the
 * Huawei watch app (`wear_huawei/`, docs/HUAWEI-WATCH.md).
 *
 * Phone → watch: one P2P message, a JSON object of the same keys the Wear
 * OS item `/tibyan/state` carries (only the next few days of portions, a
 * lite wearable message must stay small).
 * One-way only: nothing comes back from the watch. Its misbaha counts on
 * the watch alone (Wear Engine cannot deliver to a phone app that is not
 * running, so a watch → phone sync would lose counts). The watch keeps the
 * last state it received and shows it while the phone app is closed; the
 * phone resends it each time Tibyan opens and whenever the khatma or the
 * dhikr changes.
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
    // Tibyan opened: resend the last state so the watch is up to date.
    push(context, emptyMap())
  }

  companion object {
    /** The Huawei watch app's bundle name (wear_huawei/entry/src/main/config.json). */
    const val WATCH_PACKAGE = "app.tibyan.watch"

    /**
     * The watch app's fingerprint from AppGallery Connect (a public id, not a
     * secret). Empty until Ahmed creates the watch app there; then the
     * bridge stays silent (docs/HUAWEI-WATCH.md, step 4).
     */
    const val WATCH_FINGERPRINT = ""

    private const val PREFS = "TibyanWatch"
    private const val DAYS_SENT = 3

    /** Shared with the Wear OS bridge (MainActivity); never called here. */
    @Volatile var onPending: (() -> Unit)? = null

    @Volatile private var permitted = false

    private fun p2p(context: Context) = HiWear.getP2pClient(context)
      .setPeerPkgName(WATCH_PACKAGE)
      .setPeerFingerPrint(WATCH_FINGERPRINT)

    /** The connected watches, after the user allowed Tibyan in Huawei Health. */
    private fun connect(context: Context, then: (List<Device>) -> Unit) {
      if (WATCH_FINGERPRINT.isEmpty()) return
      try {
        val withDevices = {
          HiWear.getDeviceClient(context).bondedDevices
            .addOnSuccessListener { list ->
              val devices = list.filter { it.isConnected }
              then(devices)
            }
        }
        if (permitted) {
          withDevices()
          return
        }
        HiWear.getAuthClient(context).checkPermission(Permission.DEVICE_MANAGER)
          .addOnSuccessListener { ok ->
            if (ok == true) {
              permitted = true
              withDevices()
            } else {
              HiWear.getAuthClient(context).requestPermission(object : AuthCallback {
                override fun onOk(permissions: Array<out Permission>?) {
                  permitted = true
                  withDevices()
                }

                override fun onCancel() {}
              }, Permission.DEVICE_MANAGER)
            }
          }
      } catch (e: Throwable) {
        // No Huawei Health / Wear Engine on this phone: no watch.
      }
    }

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
      // Nothing yet (first run): keep whatever the watch already has.
      if (saved.length() == 0) return
      val payload = forWatch(saved).toString().toByteArray(Charsets.UTF_8)
      connect(context) { devices ->
        for (d in devices) {
          try {
            p2p(context).send(
              d,
              Message.Builder().setPayload(payload).build(),
              object : SendCallback {
                override fun onSendResult(code: Int) {}
                override fun onSendProgress(progress: Long) {}
              },
            )
          } catch (e: Throwable) {
            // The watch app is not installed or the link dropped.
          }
        }
      }
    }

    /** Undated keys plus the dated ones (`*_yyyy-MM-dd`) of the next days. */
    internal fun forWatch(saved: JSONObject): JSONObject {
      val format = SimpleDateFormat("yyyy-MM-dd", Locale.US)
      val day = Calendar.getInstance()
      val days = (0 until DAYS_SENT).map {
        val s = format.format(day.time)
        day.add(Calendar.DAY_OF_YEAR, 1)
        s
      }.toSet()
      val dated = Regex("_(\\d{4}-\\d{2}-\\d{2})$")
      val out = JSONObject()
      for (k in saved.keys()) {
        val m = dated.find(k)
        if (m == null || m.groupValues[1] in days) out.put(k, saved.get(k))
      }
      return out
    }

  }
}

/** Declared in the shared manifest for Wear OS; never bound in this build. */
class WatchListenerService : Service() {
  override fun onBind(intent: Intent?): IBinder? = null
}
