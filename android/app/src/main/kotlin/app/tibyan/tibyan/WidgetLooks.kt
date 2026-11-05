package app.tibyan.tibyan

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.RectF
import android.graphics.Typeface
import android.os.Build
import android.text.Layout
import android.text.StaticLayout
import android.text.TextDirectionHeuristics
import android.text.TextPaint
import android.text.TextUtils
import android.view.View
import android.widget.RemoteViews
import org.json.JSONObject
import java.io.File

/**
 * The widgets in the app's interface look («شكل الواجهة»). The app draws
 * each widget's frame as a picture (lib/features/home_widgets/widget_art.dart)
 * and writes, beside it, a spec of slots: where the day's text goes, in
 * which face, size and colour. Here the day's text is drawn into the
 * picture, so the day rolls over without the app.
 *
 * Which look: the widget's own choice (WidgetConfigureActivity,
 * `wcfg_<id>` = `style|mode`), or the app's (`wl_app`) for «كما في التطبيق».
 * With no picture yet (the app not opened since the update), the widget
 * keeps its plain layout.
 */
object WidgetLooks {
  enum class Shape { small, medium }

  /** A widget ready to show: its views and what it was built for. */
  class Look(val views: RemoteViews, val shape: Shape)

  fun configKey(id: Int) = "wcfg_$id"

  /** `layli_night`: the look widget [id] shows. */
  fun variant(data: SharedPreferences, id: Int): String {
    val app = (data.getString("wl_app", null) ?: "handasi_light").split("_")
    val cfg = data.getString(configKey(id), null)?.split("|")
    val style = cfg?.getOrNull(0)?.takeIf { it != "app" } ?: app[0]
    val mode = cfg?.getOrNull(1)?.takeIf { it != "app" } ?: app.getOrElse(1) { "light" }
    return "${style}_$mode"
  }

  /** The nearer of the two shapes drawn, by the widget's size now. */
  fun shape(manager: AppWidgetManager, id: Int): Shape {
    val o = manager.getAppWidgetOptions(id)
    val w = o.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 0)
    val h = o.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT, 0)
    return if (w <= 0 || h <= 0 || w.toFloat() / h >= 1.5f) Shape.medium else Shape.small
  }

  /**
   * The picture of [face] for widget [id] with [texts] drawn into its
   * slots (`bar`: the progress, 0 … 1, as text), in [layout]; null when the
   * app has not drawn it yet.
   */
  fun build(
      context: Context,
      data: SharedPreferences,
      manager: AppWidgetManager,
      id: Int,
      face: String,
      texts: Map<String, String?>,
      layout: (Shape) -> Int,
  ): Look? {
    val shape = shape(manager, id)
    val spec = spec(data, face, shape, variant(data, id)) ?: return null
    val bitmap = draw(context, spec, texts) ?: return null
    val views = RemoteViews(context.packageName, layout(shape))
    views.setImageViewBitmap(R.id.wl_image, bitmap)
    views.setInt(
        R.id.wl_root,
        "setLayoutDirection",
        if (spec.optBoolean("rtl", true)) View.LAYOUT_DIRECTION_RTL else View.LAYOUT_DIRECTION_LTR,
    )
    return Look(views, shape)
  }

  /** The spec of the look asked for; else the same style's light or night. */
  private fun spec(data: SharedPreferences, face: String, shape: Shape, variant: String): JSONObject? {
    val style = variant.substringBefore("_")
    val night = variant.endsWith("night") || variant.endsWith("black")
    val tries = listOf(variant, if (night) "${style}_night" else "${style}_light", "handasi_light")
    for (v in tries) {
      val raw = data.getString("wl_${face}_${shape.name}_$v", null) ?: continue
      return try {
        JSONObject(raw)
      } catch (_: Exception) {
        null
      }
    }
    return null
  }

  private var ui: Typeface? = null
  private var quran: Typeface? = null

  private fun face(context: Context, quranFace: Boolean, weight: Int): Typeface {
    val base =
        if (quranFace) {
          quran ?: load(context, "flutter_assets/assets/fonts/kfgqpc/uthmanic_hafs_v20.ttf").also { quran = it }
        } else {
          ui ?: load(context, "flutter_assets/assets/fonts/ofl/changa/Changa[wght].ttf").also { ui = it }
        }
    if (quranFace || Build.VERSION.SDK_INT < Build.VERSION_CODES.P) return base
    return Typeface.create(base, weight.coerceIn(1, 1000), false)
  }

  private fun load(context: Context, asset: String): Typeface =
      try {
        Typeface.createFromAsset(context.assets, asset)
      } catch (_: Exception) {
        Typeface.DEFAULT
      }

  private fun draw(context: Context, spec: JSONObject, texts: Map<String, String?>): Bitmap? {
    val file = spec.optString("file")
    // home_widget's saveFile: the app's support directory, `home_widget/`.
    val dir = File(context.filesDir, "home_widget")
    val path = File(dir, file).takeIf { it.exists() } ?: return null
    val frame = BitmapFactory.decodeFile(path.path) ?: return null
    val bitmap = frame.copy(Bitmap.Config.ARGB_8888, true)
    frame.recycle()
    val canvas = Canvas(bitmap)
    val w = bitmap.width.toFloat()
    val h = bitmap.height.toFloat()
    val slots = spec.optJSONArray("slots") ?: return bitmap
    for (i in 0 until slots.length()) {
      val s = slots.getJSONObject(i)
      val id = s.optString("id")
      val text = texts[id]
      if (text.isNullOrEmpty()) continue
      val r = RectF(
          (s.optDouble("x") * w).toFloat(),
          (s.optDouble("y") * h).toFloat(),
          ((s.optDouble("x") + s.optDouble("w")) * w).toFloat(),
          ((s.optDouble("y") + s.optDouble("h")) * h).toFloat(),
      )
      if (id == "bar") {
        bar(
            canvas,
            r,
            text.toFloatOrNull() ?: 0f,
            color(s.optString("color")),
            color(s.optString("track")),
            spec.optBoolean("rtl", true),
        )
        continue
      }
      text(
          canvas,
          r,
          text,
          face(context, s.optString("font") == "quran", s.optInt("weight", 400)),
          (s.optDouble("size") * h).toFloat(),
          (s.optDouble("min") * h).toFloat(),
          color(s.optString("color")),
          s.optString("align") == "center",
          s.optInt("lines", 1),
          spec.optBoolean("rtl", true),
      )
    }
    return bitmap
  }

  private fun color(hex: String): Int =
      try {
        Color.parseColor(hex)
      } catch (_: Exception) {
        Color.WHITE
      }

  private fun bar(canvas: Canvas, r: RectF, value: Float, fill: Int, track: Int, rtl: Boolean) {
    val p = Paint(Paint.ANTI_ALIAS_FLAG)
    val radius = r.height() / 2
    p.color = track
    canvas.drawRoundRect(r, radius, radius, p)
    p.color = fill
    val v = value.coerceIn(0f, 1f)
    if (v <= 0f) return
    // The bar fills from the reading side.
    val done = r.width() * v
    val part = if (rtl) RectF(r.right - done, r.top, r.right, r.bottom) else RectF(r.left, r.top, r.left + done, r.bottom)
    canvas.drawRoundRect(part, radius, radius, p)
  }

  /** [text] in [r], shrunk from [size] toward [min] until it fits. */
  private fun text(
      canvas: Canvas,
      r: RectF,
      text: String,
      face: Typeface,
      size: Float,
      min: Float,
      color: Int,
      center: Boolean,
      lines: Int,
      rtl: Boolean,
  ) {
    val paint = TextPaint(Paint.ANTI_ALIAS_FLAG).apply {
      typeface = face
      this.color = color
    }
    var s = size
    var layout: StaticLayout
    while (true) {
      paint.textSize = s
      layout = StaticLayout.Builder
          .obtain(text, 0, text.length, paint, r.width().toInt().coerceAtLeast(1))
          .setAlignment(if (center) Layout.Alignment.ALIGN_CENTER else Layout.Alignment.ALIGN_NORMAL)
          .setTextDirection(if (rtl) TextDirectionHeuristics.RTL else TextDirectionHeuristics.LTR)
          .setLineSpacing(0f, 1.05f)
          .setIncludePad(false)
          .build()
      val fits = layout.height <= r.height() && layout.lineCount <= lines
      if (fits || s <= min) break
      s = (s * 0.92f).coerceAtLeast(min)
    }
    if (layout.lineCount > lines || layout.height > r.height()) {
      // At the least size and still too long: the last lines end in «…».
      layout = StaticLayout.Builder
          .obtain(text, 0, text.length, paint, r.width().toInt().coerceAtLeast(1))
          .setAlignment(if (center) Layout.Alignment.ALIGN_CENTER else Layout.Alignment.ALIGN_NORMAL)
          .setTextDirection(if (rtl) TextDirectionHeuristics.RTL else TextDirectionHeuristics.LTR)
          .setIncludePad(false)
          .setEllipsize(TextUtils.TruncateAt.END)
          .setMaxLines(lines.coerceAtMost((r.height() / (paint.fontSpacing)).toInt().coerceAtLeast(1)))
          .build()
    }
    canvas.save()
    canvas.translate(r.left, r.top + ((r.height() - layout.height) / 2).coerceAtLeast(0f))
    canvas.clipRect(0f, -2f, r.width(), r.height() + 2f)
    layout.draw(canvas)
    canvas.restore()
  }
}
