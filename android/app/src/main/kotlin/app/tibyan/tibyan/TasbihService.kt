package app.tibyan.tibyan

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.media.VolumeProvider
import android.media.session.MediaSession
import android.media.session.PlaybackState
import android.os.Build
import android.os.IBinder
import android.os.VibrationEffect
import android.os.Vibrator

/**
 * «العدّ والشاشة مقفلة» (Android only, off by default): while the misbaha
 * is open, a foreground service with a visible notification holds a media
 * session whose volume is "remote", so the volume buttons reach it even
 * with the screen locked, and each press counts instead of changing the
 * volume. The notification shows the count and has its own count button.
 * Counts wait in [PREFS] until the app takes them (`takePending`).
 */
class TasbihService : Service() {
  private var session: MediaSession? = null
  private var title = ""
  private var text = ""
  private var shown = 0

  override fun onBind(intent: Intent?): IBinder? = null

  override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
    if (intent?.action == ACTION_COUNT) {
      count()
      return START_NOT_STICKY
    }
    title = intent?.getStringExtra(EXTRA_TITLE) ?: title
    text = intent?.getStringExtra(EXTRA_TEXT) ?: text
    shown = 0
    channel()
    val n = notification()
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
      startForeground(NOTIFICATION, n, ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PLAYBACK)
    } else {
      startForeground(NOTIFICATION, n)
    }
    startSession()
    return START_NOT_STICKY
  }

  private fun startSession() {
    if (session != null) return
    val s = MediaSession(this, "TibyanTasbih")
    s.setPlaybackToRemote(
        object : VolumeProvider(VOLUME_CONTROL_RELATIVE, 50, 25) {
          override fun onAdjustVolume(direction: Int) {
            if (direction != 0) count()
          }
        },
    )
    s.setPlaybackState(
        PlaybackState.Builder()
            .setState(PlaybackState.STATE_PLAYING, 0, 1f)
            .build(),
    )
    s.isActive = true
    session = s
  }

  private fun count() {
    val prefs = getSharedPreferences(PREFS, Context.MODE_PRIVATE)
    prefs.edit().putInt(PENDING, prefs.getInt(PENDING, 0) + 1).apply()
    shown++
    vibrate()
    getSystemService(NotificationManager::class.java)?.notify(NOTIFICATION, notification())
  }

  private fun vibrate() {
    val v = getSystemService(Vibrator::class.java) ?: return
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
      v.vibrate(VibrationEffect.createPredefined(VibrationEffect.EFFECT_TICK))
    } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
      v.vibrate(VibrationEffect.createOneShot(15, 80))
    }
  }

  private fun channel() {
    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
    val c = NotificationChannel(
        CHANNEL,
        getString(R.string.tasbih_channel),
        NotificationManager.IMPORTANCE_LOW,
    )
    c.setShowBadge(false)
    getSystemService(NotificationManager::class.java)?.createNotificationChannel(c)
  }

  private fun notification(): Notification {
    val open = PendingIntent.getActivity(
        this,
        0,
        packageManager.getLaunchIntentForPackage(packageName),
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
    )
    val plus = PendingIntent.getService(
        this,
        1,
        Intent(this, TasbihService::class.java).setAction(ACTION_COUNT),
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
    )
    val b = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
      Notification.Builder(this, CHANNEL)
    } else {
      @Suppress("DEPRECATION")
      Notification.Builder(this)
    }
    return b.setSmallIcon(R.drawable.ic_stat_tibyan)
        .setContentTitle(if (shown > 0) "$title · ${digits(shown)}" else title)
        .setContentText(text)
        .setOngoing(true)
        .setOnlyAlertOnce(true)
        .setContentIntent(open)
        .setVisibility(Notification.VISIBILITY_PUBLIC)
        .addAction(
            Notification.Action.Builder(null, getString(R.string.tasbih_count), plus).build(),
        )
        .build()
  }

  private fun digits(n: Int): String {
    val lang = getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
        .getString("lang", null) ?: "ar"
    return if (lang.startsWith("ar")) arabicDigits(n) else "$n"
  }

  override fun onDestroy() {
    session?.release()
    session = null
    super.onDestroy()
  }

  companion object {
    const val EXTRA_TITLE = "title"
    const val EXTRA_TEXT = "text"
    const val ACTION_COUNT = "app.tibyan.tibyan.TASBIH_COUNT"
    const val PREFS = "tasbih_service"
    const val PENDING = "pending"
    const val CHANNEL = "tasbih"
    const val NOTIFICATION = 7330

    /** The counts made since the last call; the counter is emptied. */
    fun takePending(context: Context): Int {
      val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
      val n = prefs.getInt(PENDING, 0)
      if (n != 0) prefs.edit().putInt(PENDING, 0).apply()
      return n
    }
  }
}

/** [n] in Arabic-Indic digits. */
fun arabicDigits(n: Int): String =
    n.toString().map { if (it.isDigit()) (0x0660 + (it - '0')).toChar() else it }.joinToString("")
