package app.tibyan.tibyan.wear

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/** TEMPORARY (screenshots only, debug builds): writes sample phone data. */
class SampleData : BroadcastReceiver() {
  override fun onReceive(c: Context, i: Intent) {
    val p = c.getSharedPreferences("state", Context.MODE_PRIVATE).edit().clear()
    if (i.getBooleanExtra("clear", false)) {
      p.apply(); return
    }
    val d = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())
    p.putString("title", "ختمة")
      .putString("progress", "62")
      .putString("portion_$d", "ص ٢٢ - ٢٤")
      .putString("surah_$d", "البقرة")
      .putString("from_$d", "22").putString("to_$d", "24")
      .putString("tasbih_dhikr", "سبحان الله")
      .putString("tasbih_target", "33")
      .apply()
    c.getSharedPreferences("counts", Context.MODE_PRIVATE).edit()
      .putInt("session", i.getIntExtra("session", 11)).apply()
    androidx.wear.tiles.TileService.getUpdater(c).requestUpdate(WirdTileService::class.java)
  }
}
