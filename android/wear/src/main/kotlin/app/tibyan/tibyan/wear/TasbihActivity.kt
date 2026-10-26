package app.tibyan.tibyan.wear

import android.app.Activity
import android.graphics.Color
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.TypedValue
import android.view.Gravity
import android.view.HapticFeedbackConstants
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView
import java.text.NumberFormat

/**
 * The watch's misbaha: tap to count. Counts go to the phone, which adds
 * them to its current dhikr; today's portion shows above.
 */
class TasbihActivity : Activity() {
  private lateinit var wird: TextView
  private lateinit var dhikr: TextView
  private lateinit var counter: Button
  private val handler = Handler(Looper.getMainLooper())
  private val send = Runnable { WatchData.sendTotal(this) }

  override fun onCreate(savedInstanceState: Bundle?) {
    super.onCreate(savedInstanceState)
    val pad = dp(14)
    wird = TextView(this).apply {
      gravity = Gravity.CENTER
      setTextSize(TypedValue.COMPLEX_UNIT_SP, 12f)
      setTextColor(Color.LTGRAY)
      maxLines = 2
    }
    dhikr = TextView(this).apply {
      gravity = Gravity.CENTER
      setTextSize(TypedValue.COMPLEX_UNIT_SP, 14f)
      setTextColor(Color.WHITE)
      maxLines = 2
    }
    counter = Button(this).apply {
      setTextSize(TypedValue.COMPLEX_UNIT_SP, 34f)
      setBackgroundColor(Color.rgb(184, 148, 74))
      setTextColor(Color.BLACK)
      setOnClickListener { count() }
    }
    val reset = TextView(this).apply {
      text = getString(R.string.tasbih_reset)
      gravity = Gravity.CENTER
      setTextColor(Color.LTGRAY)
      setPadding(0, dp(6), 0, 0)
      setOnClickListener {
        WatchData.counts(this@TasbihActivity).edit().putInt("session", 0).apply()
        show()
      }
    }
    setContentView(LinearLayout(this).apply {
      orientation = LinearLayout.VERTICAL
      gravity = Gravity.CENTER
      setPadding(pad, pad, pad, pad)
      setBackgroundColor(Color.BLACK)
      addView(wird)
      addView(dhikr)
      addView(counter, LinearLayout.LayoutParams(dp(110), dp(70)).apply {
        gravity = Gravity.CENTER_HORIZONTAL
        topMargin = dp(6)
      })
      addView(reset)
    })
  }

  override fun onResume() {
    super.onResume()
    show()
    WatchData.refresh(this) { show() }
  }

  override fun onPause() {
    handler.removeCallbacks(send)
    WatchData.sendTotal(this)
    super.onPause()
  }

  private fun count() {
    val counts = WatchData.counts(this)
    counts.edit()
      .putInt("session", counts.getInt("session", 0) + 1)
      .putLong("total", counts.getLong("total", 0) + 1)
      .apply()
    counter.performHapticFeedback(HapticFeedbackConstants.VIRTUAL_KEY)
    show()
    // Taps in a row go to the phone together.
    handler.removeCallbacks(send)
    handler.postDelayed(send, 1500)
  }

  private fun show() {
    val today = WatchData.today(this)
    wird.text = when {
      !WatchData.hasData(this) -> getString(R.string.open_phone)
      today != null -> today.first
      else -> WatchData.value(this, "idle")
    }
    dhikr.text = WatchData.value(this, "tasbih_dhikr").ifEmpty { getString(R.string.tasbih_title) }
    val n = WatchData.counts(this).getInt("session", 0)
    counter.text = NumberFormat.getIntegerInstance().format(n)
    counter.contentDescription = "${getString(R.string.tasbih_count)} $n"
  }

  private fun dp(v: Int) = (v * resources.displayMetrics.density).toInt()
}
