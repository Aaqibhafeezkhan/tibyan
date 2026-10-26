package app.tibyan.tibyan.wear

import android.app.Activity
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.VibrationEffect
import android.os.Vibrator
import android.util.TypedValue
import android.view.GestureDetector
import android.view.Gravity
import android.view.HapticFeedbackConstants
import android.view.InputDevice
import android.view.MotionEvent
import android.view.View
import android.view.ViewConfiguration
import android.view.ViewGroup.LayoutParams.MATCH_PARENT
import android.view.ViewGroup.LayoutParams.WRAP_CONTENT
import android.view.accessibility.AccessibilityNodeInfo
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.LinearLayout
import kotlin.math.abs

/**
 * The watch app: «ورد اليوم» and the misbaha, one above the other (swipe
 * up for the misbaha). On the misbaha a tap anywhere or a turn of the
 * crown/bezel counts; a swipe down (or a long press) shows the secondary
 * actions: start over and back to today's portion. Counts go to the
 * phone, which adds them to its current dhikr (docs/WATCH.md).
 */
class TasbihActivity : Activity() {
  private lateinit var root: FrameLayout
  private lateinit var ring: RingView
  private lateinit var content: FrameLayout
  private lateinit var sheet: LinearLayout
  private var misbaha = false
  private var rotary = 0f
  private val handler = Handler(Looper.getMainLooper())
  private val send = Runnable { WatchData.sendTotal(this) }

  override fun onCreate(savedInstanceState: Bundle?) {
    super.onCreate(savedInstanceState)
    misbaha = intent.getBooleanExtra(EXTRA_MISBAHA, false)
    ring = RingView(this)
    content = FrameLayout(this)
    sheet = buildSheet()
    root = FrameLayout(this).apply {
      setBackgroundResource(R.drawable.watch_background)
      addView(ring, FrameLayout.LayoutParams(MATCH_PARENT, MATCH_PARENT))
      addView(content, FrameLayout.LayoutParams(MATCH_PARENT, MATCH_PARENT))
      addView(sheet, FrameLayout.LayoutParams(MATCH_PARENT, MATCH_PARENT))
      isFocusable = true
      isFocusableInTouchMode = true
    }
    val gestures = GestureDetector(this, object : GestureDetector.SimpleOnGestureListener() {
      override fun onDown(e: MotionEvent) = true

      override fun onSingleTapUp(e: MotionEvent): Boolean {
        if (sheet.visibility == View.VISIBLE) {
          sheet.visibility = View.GONE
        } else if (misbaha) {
          count()
        }
        return true
      }

      override fun onLongPress(e: MotionEvent) {
        if (misbaha) showSheet()
      }

      override fun onFling(a: MotionEvent?, e: MotionEvent, vx: Float, vy: Float): Boolean {
        if (abs(vy) < abs(vx)) return false
        when {
          !misbaha && vy < 0 -> page(true)
          misbaha && vy > 0 -> showSheet()
        }
        return true
      }
    })
    root.setOnTouchListener { v, e ->
      gestures.onTouchEvent(e)
      if (e.action == MotionEvent.ACTION_UP && misbaha) v.performClick()
      true
    }
    root.setOnClickListener { /* counted by the tap above; for TalkBack see below */ }
    root.setOnGenericMotionListener { _, e -> rotate(e) }
    root.accessibilityDelegate = object : View.AccessibilityDelegate() {
      override fun onInitializeAccessibilityNodeInfo(host: View, info: AccessibilityNodeInfo) {
        super.onInitializeAccessibilityNodeInfo(host, info)
        info.addAction(AccessibilityNodeInfo.AccessibilityAction(
          ACTION_PAGE, getString(if (misbaha) R.string.to_wird else R.string.tasbih_title)))
        if (misbaha) {
          info.addAction(AccessibilityNodeInfo.AccessibilityAction(
            AccessibilityNodeInfo.ACTION_CLICK, getString(R.string.tasbih_count)))
          info.addAction(AccessibilityNodeInfo.AccessibilityAction(
            ACTION_RESET, getString(R.string.tasbih_reset)))
        }
      }

      override fun performAccessibilityAction(host: View, action: Int, args: Bundle?): Boolean =
        when (action) {
          ACTION_PAGE -> { page(!misbaha); true }
          ACTION_RESET -> { reset(); true }
          AccessibilityNodeInfo.ACTION_CLICK -> { if (misbaha) count(); true }
          else -> super.performAccessibilityAction(host, action, args)
        }
    }
    setContentView(root)
  }

  override fun onResume() {
    super.onResume()
    root.requestFocus()
    show()
    WatchData.refresh(this) { show() }
  }

  override fun onPause() {
    handler.removeCallbacks(send)
    WatchData.sendTotal(this)
    super.onPause()
  }

  private fun page(toMisbaha: Boolean) {
    misbaha = toMisbaha
    sheet.visibility = View.GONE
    show()
  }

  /** A turn of the crown or bezel: one count per notch. */
  private fun rotate(e: MotionEvent): Boolean {
    if (e.action != MotionEvent.ACTION_SCROLL ||
      !e.isFromSource(InputDevice.SOURCE_ROTARY_ENCODER)
    ) return false
    if (!misbaha) {
      page(true)
      return true
    }
    rotary += abs(e.getAxisValue(MotionEvent.AXIS_SCROLL)) *
      ViewConfiguration.get(this).scaledVerticalScrollFactor
    val notch = resources.displayMetrics.density * 24
    while (rotary >= notch) {
      rotary -= notch
      count()
    }
    return true
  }

  private fun count() {
    val counts = WatchData.counts(this)
    val session = counts.getInt("session", 0) + 1
    counts.edit()
      .putInt("session", session)
      .putLong("total", counts.getLong("total", 0) + 1)
      .apply()
    val state = WatchData.tasbih(this, session)
    if (state.target > 0 && state.count == state.target) {
      // A round (or stage) done: a distinct double pulse.
      getSystemService(Vibrator::class.java)
        ?.vibrate(VibrationEffect.createPredefined(VibrationEffect.EFFECT_DOUBLE_CLICK))
    } else {
      root.performHapticFeedback(HapticFeedbackConstants.CLOCK_TICK)
    }
    show()
    // Counts in a row go to the phone together.
    handler.removeCallbacks(send)
    handler.postDelayed(send, 1500)
  }

  private fun reset() {
    WatchData.counts(this).edit().putInt("session", 0).apply()
    sheet.visibility = View.GONE
    show()
  }

  private fun showSheet() {
    sheet.visibility = View.VISIBLE
  }

  private fun show() {
    content.removeAllViews()
    val column = LinearLayout(this).apply {
      orientation = LinearLayout.VERTICAL
      gravity = Gravity.CENTER
      val pad = (resources.displayMetrics.widthPixels * 0.14f).toInt()
      setPadding(pad, pad / 2, pad, pad / 2)
    }
    content.addView(column, FrameLayout.LayoutParams(MATCH_PARENT, MATCH_PARENT))
    when {
      !WatchData.hasData(this) -> empty(column)
      misbaha -> misbaha(column)
      else -> wird(column)
    }
  }

  private fun empty(column: LinearLayout) {
    ring.progress = 0f
    ring.visibility = View.GONE
    val size = (resources.displayMetrics.widthPixels * 0.42f).toInt()
    column.addView(ImageView(this).apply {
      setImageResource(R.mipmap.ic_launcher_foreground)
      importantForAccessibility = View.IMPORTANT_FOR_ACCESSIBILITY_NO
    }, LinearLayout.LayoutParams(size, size).apply { gravity = Gravity.CENTER_HORIZONTAL })
    column.addView(Look.text(this, 14f, Look.DIM, lines = 4).apply {
      text = getString(R.string.open_phone)
    })
    root.contentDescription = getString(R.string.open_phone)
  }

  private fun wird(column: LinearLayout) {
    ring.visibility = View.VISIBLE
    val percent = WatchData.percent(this)
    ring.progress = percent / 100f
    column.addView(Look.text(this, 13f, Look.GOLD, Look.ui(this, 600), 1).apply {
      text = getString(R.string.wird_title)
    })
    val w = WatchData.wird(this)
    val parts = mutableListOf(getString(R.string.wird_title))
    if (w == null) {
      column.addView(Look.text(this, 16f, lines = 3).apply {
        text = WatchData.value(this@TasbihActivity, "idle")
        parts += text.toString()
      })
    } else {
      column.addView(Look.text(this, 24f, face = Look.ui(this, 700), lines = 1).apply {
        text = w.surah.ifEmpty { w.portion }
        parts += text.toString()
        setAutoSizeTextTypeUniformWithConfiguration(14, 24, 1, TypedValue.COMPLEX_UNIT_SP)
      })
      if (w.from != null && w.to != null) {
        val range = if (w.from == w.to) getString(R.string.page_one, Look.number(w.from))
        else getString(R.string.page_range, Look.number(w.from), Look.number(w.to))
        column.addView(Look.text(this, 15f, Look.DIM, Look.digits(this), 1).apply {
          text = range
          parts += range
        })
      }
    }
    column.addView(Look.text(this, 20f, Look.GOLD, Look.digits(this), 1).apply {
      text = Look.percent(percent)
      setPadding(0, (4 * resources.displayMetrics.density).toInt(), 0, 0)
      parts += getString(R.string.khatma_percent, text)
    })
    column.addView(Look.text(this, 11f, Look.DIM, lines = 1).apply {
      text = getString(R.string.swipe_misbaha)
      setPadding(0, (8 * resources.displayMetrics.density).toInt(), 0, 0)
    })
    root.contentDescription = parts.joinToString("، ")
  }

  private fun misbaha(column: LinearLayout) {
    ring.visibility = View.VISIBLE
    val session = WatchData.counts(this).getInt("session", 0)
    val s = WatchData.tasbih(this, session)
    ring.progress = if (s.target > 0) s.count / s.target.toFloat() else 0f
    if (s.stages > 1) {
      column.addView(Look.text(this, 13f, Look.GOLD, Look.digits(this), 1).apply {
        text = getString(R.string.stage, Look.number(s.stage), Look.number(s.stages))
      })
    }
    column.addView(Look.text(this, 14f, Look.DIM, lines = 2).apply {
      text = s.label.ifEmpty { getString(R.string.tasbih_title) }
    })
    column.addView(Look.text(this, 58f, face = Look.digits(this), lines = 1).apply {
      text = Look.number(s.count)
    })
    if (s.target > 0) {
      column.addView(Look.text(this, 14f, Look.GOLD, Look.digits(this), 1).apply {
        text = getString(R.string.of_target, Look.number(s.target))
      })
    }
    root.contentDescription = listOfNotNull(
      s.label.ifEmpty { getString(R.string.tasbih_title) },
      if (s.target > 0) getString(R.string.count_of, Look.number(s.count), Look.number(s.target))
      else Look.number(s.count),
    ).joinToString("، ")
  }

  /** «ابدأ من جديد» and «ورد اليوم», off the main surface. */
  private fun buildSheet(): LinearLayout = LinearLayout(this).apply {
    orientation = LinearLayout.VERTICAL
    gravity = Gravity.CENTER
    visibility = View.GONE
    setBackgroundColor(0xE6020C0B.toInt())
    val pad = (12 * resources.displayMetrics.density).toInt()
    fun action(label: Int, run: () -> Unit) = Look.text(context, 16f, Look.CREAM, Look.ui(context, 600), 1).apply {
      text = getString(label)
      setPadding(pad * 2, pad, pad * 2, pad)
      background = android.graphics.drawable.GradientDrawable().apply {
        cornerRadius = 100f
        setStroke((1.5f * resources.displayMetrics.density).toInt(), Look.GOLD)
      }
      isClickable = true
      setOnClickListener { run() }
    }
    addView(action(R.string.tasbih_reset) { reset() }, LinearLayout.LayoutParams(WRAP_CONTENT, WRAP_CONTENT))
    addView(View(context), LinearLayout.LayoutParams(1, pad))
    addView(action(R.string.to_wird) { page(false) }, LinearLayout.LayoutParams(WRAP_CONTENT, WRAP_CONTENT))
    isClickable = true
    setOnClickListener { visibility = View.GONE }
  }

  companion object {
    const val EXTRA_MISBAHA = "misbaha"
    private val ACTION_PAGE = View.generateViewId()
    private val ACTION_RESET = View.generateViewId()
  }
}
