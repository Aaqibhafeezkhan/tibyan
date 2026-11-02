package app.tibyan.tibyan

import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.IBinder
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel

/**
 * «الساعة» in the Huawei AppGallery build: the Wear OS Data Layer needs
 * Google Play services, so the watch channel answers and does nothing
 * (docs/HUAWEI.md). The gms source set has the real bridge.
 */
class WatchBridge(@Suppress("UNUSED_PARAMETER") context: Context, messenger: BinaryMessenger) {
  init {
    MethodChannel(messenger, "app.tibyan/watch").setMethodCallHandler { call, result ->
      if (call.method == "push") result.success(null) else result.notImplemented()
    }
  }

  companion object {
    @Volatile var onPending: (() -> Unit)? = null
  }
}

/** Declared in the shared manifest; never bound without Google Play services. */
class WatchListenerService : Service() {
  override fun onBind(intent: Intent?): IBinder? = null
}
