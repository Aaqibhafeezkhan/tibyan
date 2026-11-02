package app.tibyan.tibyan

import android.content.Context

/** The Huawei AppGallery build: no Google Play services (docs/HUAWEI.md). */
object Gms {
  @Suppress("UNUSED_PARAMETER")
  fun available(context: Context): Boolean = false
}
