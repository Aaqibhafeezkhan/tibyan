package app.tibyan.tibyan.wear

import androidx.wear.protolayout.ActionBuilders
import androidx.wear.protolayout.ColorBuilders.argb
import androidx.wear.protolayout.DimensionBuilders.dp
import androidx.wear.protolayout.DimensionBuilders.expand
import androidx.wear.protolayout.DimensionBuilders.sp
import androidx.wear.protolayout.LayoutElementBuilders
import androidx.wear.protolayout.ModifiersBuilders
import androidx.wear.protolayout.ResourceBuilders
import androidx.wear.protolayout.TimelineBuilders
import androidx.wear.tiles.RequestBuilders
import androidx.wear.tiles.TileBuilders
import androidx.wear.tiles.TileService
import com.google.common.util.concurrent.Futures
import com.google.common.util.concurrent.ListenableFuture

/**
 * The «ورد اليوم» tile: the khatma's portion for today (or its calm idle
 * line) and the current dhikr; a tap opens the misbaha.
 */
class WirdTileService : TileService() {
  override fun onTileRequest(
    requestParams: RequestBuilders.TileRequest,
  ): ListenableFuture<TileBuilders.Tile> {
    val today = WatchData.today(this)
    val column = LayoutElementBuilders.Column.Builder()
      .setHorizontalAlignment(LayoutElementBuilders.HORIZONTAL_ALIGN_CENTER)
      .addContent(text(getString(R.string.wird_title), 12f, GREY))
    if (!WatchData.hasData(this)) {
      column.addContent(text(getString(R.string.open_phone), 13f, WHITE, lines = 3))
    } else {
      column.addContent(text(WatchData.value(this, "title"), 13f, GOLD))
      if (today != null) {
        column.addContent(text(today.first, 16f, WHITE))
        if (today.second.isNotEmpty()) column.addContent(text(today.second, 12f, GREY))
      } else {
        column.addContent(text(WatchData.value(this, "idle"), 14f, WHITE, lines = 3))
      }
      column.addContent(LayoutElementBuilders.Spacer.Builder().setHeight(dp(6f)).build())
      column.addContent(
        text(
          WatchData.value(this, "tasbih_dhikr").ifEmpty { getString(R.string.tasbih_open) },
          12f,
          GOLD,
          lines = 1,
        ),
      )
    }
    val open = ModifiersBuilders.Clickable.Builder()
      .setId("tasbih")
      .setOnClick(
        ActionBuilders.LaunchAction.Builder()
          .setAndroidActivity(
            ActionBuilders.AndroidActivity.Builder()
              .setPackageName(packageName)
              .setClassName(TasbihActivity::class.java.name)
              .build(),
          ).build(),
      ).build()
    val root = LayoutElementBuilders.Box.Builder()
      .setWidth(expand())
      .setHeight(expand())
      .setModifiers(ModifiersBuilders.Modifiers.Builder().setClickable(open).build())
      .addContent(column.build())
      .build()
    val tile = TileBuilders.Tile.Builder()
      .setResourcesVersion(RESOURCES)
      .setTileTimeline(TimelineBuilders.Timeline.fromLayoutElement(root))
      // The day changes at midnight: look again every half hour.
      .setFreshnessIntervalMillis(30 * 60 * 1000L)
      .build()
    return Futures.immediateFuture(tile)
  }

  override fun onTileResourcesRequest(
    requestParams: RequestBuilders.ResourcesRequest,
  ): ListenableFuture<ResourceBuilders.Resources> = Futures.immediateFuture(
    ResourceBuilders.Resources.Builder().setVersion(RESOURCES).build(),
  )

  private fun text(s: String, size: Float, color: Int, lines: Int = 2) =
    LayoutElementBuilders.Text.Builder()
      .setText(s)
      .setMaxLines(lines)
      .setFontStyle(
        LayoutElementBuilders.FontStyle.Builder()
          .setSize(sp(size))
          .setColor(argb(color))
          .build(),
      ).build()

  private companion object {
    const val RESOURCES = "1"
    const val WHITE = 0xFFFFFFFF.toInt()
    const val GREY = 0xFFBDBDBD.toInt()
    const val GOLD = 0xFFD4B26A.toInt()
  }
}
