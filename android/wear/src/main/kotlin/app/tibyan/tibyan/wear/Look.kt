package app.tibyan.tibyan.wear

import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.RectF
import android.graphics.Typeface
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.widget.TextView
import java.text.NumberFormat

/**
 * The «ليل هندسي» look (handoff 07): teal night with the Girih
 * (res/drawable/watch_background.xml, from tools/watch/make_watch_art.py),
 * a gold progress ring on the edge, cream text, Changa for words and
 * IBM Plex Sans Arabic for numbers (both OFL, in assets/fonts).
 */
object Look {
  val CREAM = Color.rgb(0xF4, 0xEC, 0xD8)
  val DIM = Color.argb(158, 0xF4, 0xEC, 0xD8)
  val GOLD = Color.rgb(0xD9, 0xB2, 0x66)
  val TRACK = Color.argb(41, 0xD9, 0xB2, 0x66)

  private val fonts = HashMap<String, Typeface>()

  /** Changa at [weight] (a variable font). */
  fun ui(c: Context, weight: Int = 500): Typeface = fonts.getOrPut("ui$weight") {
    Typeface.Builder(c.assets, "fonts/Changa.ttf")
      .setFontVariationSettings("'wght' $weight")
      .build()
  }

  fun digits(c: Context): Typeface = fonts.getOrPut("digits") {
    Typeface.createFromAsset(c.assets, "fonts/IBMPlexSansArabic-SemiBold.ttf")
  }

  /** In the reader's digits (Arabic-Indic in Arabic). */
  fun number(n: Int): String = NumberFormat.getIntegerInstance().format(n)

  fun percent(n: Int): String = NumberFormat.getPercentInstance().format(n / 100.0)

  fun text(
    c: Context,
    sp: Float,
    color: Int = CREAM,
    face: Typeface = ui(c),
    lines: Int = 2,
  ) = TextView(c).apply {
    gravity = Gravity.CENTER
    textAlignment = View.TEXT_ALIGNMENT_CENTER
    setTextSize(TypedValue.COMPLEX_UNIT_SP, sp)
    setTextColor(color)
    typeface = face
    maxLines = lines
    // Tabular figures so a count does not shift as it grows.
    fontFeatureSettings = "tnum"
    includeFontPadding = false
  }
}

/**
 * The gold ring on a round screen's edge (a thin bar at the bottom of a
 * square one) showing [progress] from 0 to 1.
 */
class RingView(c: Context) : View(c) {
  var progress = 0f
    set(v) {
      field = v.coerceIn(0f, 1f)
      invalidate()
    }

  private val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
    style = Paint.Style.STROKE
    strokeCap = Paint.Cap.ROUND
  }
  private val box = RectF()

  init {
    importantForAccessibility = IMPORTANT_FOR_ACCESSIBILITY_NO
  }

  override fun onDraw(canvas: Canvas) {
    val w = width.toFloat()
    val h = height.toFloat()
    if (resources.configuration.isScreenRound) {
      val stroke = w * 0.032f
      val inset = w * 0.037f + stroke / 2
      paint.strokeWidth = stroke
      box.set(inset, inset, w - inset, h - inset)
      paint.color = Look.TRACK
      canvas.drawOval(box, paint)
      if (progress > 0f) {
        paint.color = Look.GOLD
        canvas.drawArc(box, -90f, 360f * progress, false, paint)
      }
    } else {
      val stroke = h * 0.02f
      val y = h - stroke * 3
      val x0 = w * 0.15f
      val x1 = w * 0.85f
      paint.strokeWidth = stroke
      paint.color = Look.TRACK
      canvas.drawLine(x0, y, x1, y, paint)
      if (progress > 0f) {
        paint.color = Look.GOLD
        // From the reading side: right to left in Arabic.
        if (layoutDirection == LAYOUT_DIRECTION_RTL) {
          canvas.drawLine(x1, y, x1 - (x1 - x0) * progress, y, paint)
        } else {
          canvas.drawLine(x0, y, x0 + (x1 - x0) * progress, y, paint)
        }
      }
    }
  }
}
