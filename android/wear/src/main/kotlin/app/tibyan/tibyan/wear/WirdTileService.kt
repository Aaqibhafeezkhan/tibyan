package app.tibyan.tibyan.wear

import androidx.wear.protolayout.ActionBuilders
import androidx.wear.protolayout.ColorBuilders.argb
import androidx.wear.protolayout.DimensionBuilders.degrees
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
 * The «ورد اليوم» tile in the «ليل هندسي» look: the teal Girih ground,
 * the khatma's progress as a gold ring, today's surah and pages (or the
 * calm idle line) and the current dhikr; a tap opens the misbaha.
 */
class WirdTileService : TileService() {
  override fun onTileRequest(
    requestParams: RequestBuilders.TileRequest,
  ): ListenableFuture<TileBuilders.Tile> {
    val column = LayoutElementBuilders.Column.Builder()
      .setHorizontalAlignment(LayoutElementBuilders.HORIZONTAL_ALIGN_CENTER)
    val percent = WatchData.percent(this)
    if (!WatchData.hasData(this)) {
      column.addContent(text(getString(R.string.app_name), 20f, CREAM, bold = true))
      column.addContent(gap(4f))
      column.addContent(text(getString(R.string.open_phone), 13f, DIM, lines = 4))
    } else {
      column.addContent(text(getString(R.string.wird_title), 12f, GOLD, bold = true))
      val w = WatchData.wird(this)
      if (w != null) {
        column.addContent(text(w.surah.ifEmpty { w.portion }, 20f, CREAM, lines = 1, bold = true))
        if (w.from != null && w.to != null) {
          val range = if (w.from == w.to) getString(R.string.page_one, Look.number(w.from))
          else getString(R.string.page_range, Look.number(w.from), Look.number(w.to))
          column.addContent(text(range, 13f, DIM, lines = 1))
        }
      } else {
        column.addContent(text(WatchData.value(this, "idle"), 14f, CREAM, lines = 3))
      }
      column.addContent(gap(2f))
      column.addContent(text(Look.percent(percent), 16f, GOLD, lines = 1, bold = true))
      val dhikr = WatchData.value(this, "tasbih_dhikr")
      column.addContent(gap(4f))
      column.addContent(text(dhikr.ifEmpty { getString(R.string.tasbih_open) }, 11f, DIM, lines = 1))
    }
    val open = ModifiersBuilders.Clickable.Builder()
      .setId("tasbih")
      .setOnClick(
        ActionBuilders.LaunchAction.Builder()
          .setAndroidActivity(
            ActionBuilders.AndroidActivity.Builder()
              .setPackageName(packageName)
              .setClassName(TasbihActivity::class.java.name)
              .addKeyToExtraMapping(
                TasbihActivity.EXTRA_MISBAHA,
                ActionBuilders.AndroidBooleanExtra.Builder().setValue(true).build(),
              )
              .build(),
          ).build(),
      ).build()
    val root = LayoutElementBuilders.Box.Builder()
      .setWidth(expand())
      .setHeight(expand())
      .setModifiers(ModifiersBuilders.Modifiers.Builder().setClickable(open).build())
      .addContent(
        LayoutElementBuilders.Image.Builder()
          .setResourceId(BACKGROUND)
          .setWidth(expand())
          .setHeight(expand())
          .setContentScaleMode(LayoutElementBuilders.CONTENT_SCALE_MODE_CROP)
          .build(),
      )
      .addContent(ring(360f, TRACK))
      .addContent(ring(360f * percent / 100f, GOLD))
      .addContent(
        LayoutElementBuilders.Box.Builder()
          .setWidth(expand())
          .setHeight(expand())
          .setModifiers(
            ModifiersBuilders.Modifiers.Builder()
              .setPadding(ModifiersBuilders.Padding.Builder().setAll(dp(30f)).build())
              .build(),
          )
          .addContent(column.build())
          .build(),
      )
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
    ResourceBuilders.Resources.Builder()
      .setVersion(RESOURCES)
      .addIdToImageMapping(
        BACKGROUND,
        ResourceBuilders.ImageResource.Builder()
          .setAndroidResourceByResId(
            ResourceBuilders.AndroidImageResourceByResId.Builder()
              .setResourceId(R.drawable.tile_background)
              .build(),
          ).build(),
      ).build(),
  )

  /** The ring on the edge, [sweep] degrees from the top. */
  private fun ring(sweep: Float, color: Int) = LayoutElementBuilders.Box.Builder()
    .setWidth(expand())
    .setHeight(expand())
    .setModifiers(
      ModifiersBuilders.Modifiers.Builder()
        .setPadding(ModifiersBuilders.Padding.Builder().setAll(dp(6f)).build())
        .build(),
    )
    .addContent(
      LayoutElementBuilders.Arc.Builder()
        .setAnchorAngle(degrees(0f))
        .setAnchorType(LayoutElementBuilders.ARC_ANCHOR_START)
        .addContent(
          LayoutElementBuilders.ArcLine.Builder()
            .setLength(degrees(sweep.coerceIn(0f, 360f)))
            .setThickness(dp(6f))
            .setColor(argb(color))
            .build(),
        ).build(),
    ).build()

  private fun gap(h: Float) = LayoutElementBuilders.Spacer.Builder().setHeight(dp(h)).build()

  private fun text(s: String, size: Float, color: Int, lines: Int = 2, bold: Boolean = false) =
    LayoutElementBuilders.Text.Builder()
      .setText(s)
      .setMaxLines(lines)
      .setFontStyle(
        LayoutElementBuilders.FontStyle.Builder()
          .setSize(sp(size))
          .setColor(argb(color))
          .setWeight(
            if (bold) LayoutElementBuilders.FONT_WEIGHT_BOLD else LayoutElementBuilders.FONT_WEIGHT_NORMAL,
          )
          .build(),
      ).build()

  private companion object {
    const val RESOURCES = "2"
    const val BACKGROUND = "background"
    val CREAM = Look.CREAM
    val DIM = Look.DIM
    val GOLD = Look.GOLD
    val TRACK = Look.TRACK
  }
}
