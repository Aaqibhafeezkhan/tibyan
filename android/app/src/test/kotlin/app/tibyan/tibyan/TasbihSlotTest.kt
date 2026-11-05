package app.tibyan.tibyan

import org.junit.Assert.assertEquals
import org.junit.Test

class TasbihSlotTest {
  @Test
  fun emptyUntilTheAppWritesADhikr() {
    // The picture's title already names the widget: no second «المسبحة».
    assertEquals("", TasbihWidgetProvider.dhikrSlot(null))
    assertEquals("", TasbihWidgetProvider.dhikrSlot(""))
  }

  @Test
  fun theWrittenDhikrAsIs() {
    val written = "dhikr-from-the-app"
    assertEquals(written, TasbihWidgetProvider.dhikrSlot(written))
  }
}
