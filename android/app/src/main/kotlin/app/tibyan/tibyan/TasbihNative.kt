package app.tibyan.tibyan

import android.content.Context
import android.media.AudioAttributes
import android.media.SoundPool
import io.flutter.FlutterInjector
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * «المسبحة»'s channel (`app.tibyan/tasbih`): the bead's click through a
 * SoundPool (no delay, mixes with other sound) and counting with the
 * volume buttons while the app is open.
 */
class TasbihNative(private val context: Context, messenger: BinaryMessenger) {
  val channel = MethodChannel(messenger, "app.tibyan/tasbih")

  /** The volume buttons count instead of changing the volume. */
  var volumeKeys = false
    private set

  private var pool: SoundPool? = null
  private var clickId = 0
  private var loaded = false

  init {
    channel.setMethodCallHandler { call, result ->
      try {
        when (call.method) {
          "click" -> {
            click()
            result.success(null)
          }
          "setVolumeKeys" -> {
            volumeKeys = call.arguments as? Boolean ?: false
            result.success(null)
          }
          else -> result.notImplemented()
        }
      } catch (e: Throwable) {
        result.success(null)
      }
    }
  }

  /** A volume button press, while [volumeKeys] is on. */
  fun volumeKey() {
    try {
      channel.invokeMethod("volumeKey", null)
    } catch (e: Throwable) {}
  }

  private fun click() {
    try {
      val p = pool ?: load() ?: return
      if (loaded) p.play(clickId, 1f, 1f, 1, 0, 1f)
    } catch (e: Throwable) {}
  }

  private fun load(): SoundPool? =
      try {
        // Flutter's assets may be compressed in the APK: copy the click out
        // once, then load it from the file.
        val file = File(context.cacheDir, "tasbih_click.wav")
        if (!file.exists()) {
          val key = FlutterInjector.instance().flutterLoader()
              .getLookupKeyForAsset("assets/tasbih/click.wav")
          context.assets.open(key).use { input ->
            file.outputStream().use { input.copyTo(it) }
          }
        }
        val p = SoundPool.Builder()
            .setMaxStreams(3)
            .setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_ASSISTANCE_SONIFICATION)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build(),
            )
            .build()
        p.setOnLoadCompleteListener { pool, id, status ->
          try {
            if (status == 0) {
              loaded = true
              pool.play(id, 1f, 1f, 1, 0, 1f)
            }
          } catch (e: Throwable) {}
        }
        clickId = p.load(file.path, 1)
        pool = p
        p
      } catch (e: Throwable) {
        null
      }

  fun dispose() {
    try {
      pool?.release()
    } catch (e: Throwable) {}
    pool = null
  }
}
