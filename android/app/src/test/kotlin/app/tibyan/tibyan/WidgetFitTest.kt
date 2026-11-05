package app.tibyan.tibyan

import org.junit.Assert.assertEquals
import org.junit.Test

class WidgetFitTest {
  private val eps = 1e-4f

  @Test
  fun sameShapeHasNoMargins() {
    val (x, y) = WidgetFit.margins(364f / 170f, 364f, 170f)
    assertEquals(0f, x, eps)
    assertEquals(0f, y, eps)
  }

  @Test
  fun widerWidgetGetsSideMargins() {
    // A square picture in a 2:1 widget: a quarter empty on each side.
    val (x, y) = WidgetFit.margins(1f, 200f, 100f)
    assertEquals(0.25f, x, eps)
    assertEquals(0f, y, eps)
  }

  @Test
  fun tallerWidgetGetsTopAndBottomMargins() {
    // A wide picture (364:170) in a 4×3 widget keeps its aspect.
    val (x, y) = WidgetFit.margins(364f / 170f, 320f, 240f)
    assertEquals(0f, x, eps)
    val shown = 1f - 2f * y
    assertEquals(364f / 170f, 320f / (240f * shown), eps)
  }

  @Test
  fun canvasKeepsThePictureAspect() {
    val m = WidgetFit.margins(1f, 300f, 100f)
    val (w, h) = WidgetFit.canvas(510, 510, m)
    assertEquals(3f, w.toFloat() / h, 0.01f)
  }

  @Test
  fun unknownSizeIsLeftAlone() {
    assertEquals(0f to 0f, WidgetFit.margins(2f, 0f, 0f))
  }
}
