package app.tibyan.tibyan

import android.content.Context
import com.google.android.gms.common.ConnectionResult
import com.google.android.gms.common.GoogleApiAvailability

/**
 * Whether Google Play services can be used on this device. The Play build
 * can still be sideloaded on a phone without them (Huawei): every Google
 * call checks this first (docs/HUAWEI.md).
 */
object Gms {
  fun available(context: Context): Boolean = try {
    GoogleApiAvailability.getInstance()
      .isGooglePlayServicesAvailable(context) == ConnectionResult.SUCCESS
  } catch (e: Throwable) {
    false
  }
}
