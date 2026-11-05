package app.tibyan.tibyan

/**
 * How a widget's picture sits in a widget of another shape: whole, never
 * stretched, centred, the rest filled with the look's ground. The app draws
 * two shapes (square and wide); a widget resized to anything else keeps
 * them undistorted.
 */
object WidgetFit {
  /**
   * The share of a [width]×[height] widget left empty on each side, across
   * and down, around a picture whose width is [aspect] times its height.
   */
  fun margins(aspect: Float, width: Float, height: Float): Pair<Float, Float> {
    if (aspect <= 0f || width <= 0f || height <= 0f) return 0f to 0f
    val widget = width / height
    return if (widget > aspect) {
      (1f - aspect / widget) / 2f to 0f
    } else {
      0f to (1f - widget / aspect) / 2f
    }
  }

  /** The size of the canvas that holds a [w]×[h] picture with [margins]. */
  fun canvas(w: Int, h: Int, margins: Pair<Float, Float>): Pair<Int, Int> =
      Math.round(w / (1f - 2f * margins.first)) to Math.round(h / (1f - 2f * margins.second))
}
