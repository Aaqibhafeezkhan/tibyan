package app.tibyan.tibyan

import android.app.Activity
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.res.Configuration
import android.os.Bundle
import android.view.View
import android.widget.Button
import android.widget.LinearLayout
import android.widget.RadioButton
import android.widget.RadioGroup
import android.widget.TextView
import es.antonborri.home_widget.HomeWidgetProvider
import java.util.Locale

/**
 * A widget's look and mode: «كما في التطبيق» (the default), or a look of
 * its own (هندسي، ليلي ذهبي، مخطوطة) in light or night. Kept per widget in
 * the widget data (`wcfg_<id>` = `style|mode`), read by WidgetLooks.
 * Asked when a widget is placed (optional on Android 12 and later) and
 * from the launcher's widget settings. In the app's language.
 */
class WidgetConfigureActivity : Activity() {
  private var id = AppWidgetManager.INVALID_APPWIDGET_ID

  override fun onCreate(savedInstanceState: Bundle?) {
    super.onCreate(savedInstanceState)
    id = intent?.extras?.getInt(AppWidgetManager.EXTRA_APPWIDGET_ID, id) ?: id
    // Placed without a choice: «كما في التطبيق».
    setResult(RESULT_OK, Intent().putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, id))
    if (id == AppWidgetManager.INVALID_APPWIDGET_ID) return finish()

    val prefs = getSharedPreferences(ActionsWidgetProvider.PREFERENCES, Context.MODE_PRIVATE)
    val lang = prefs.getString("lang", null) ?: "ar"
    val words = createConfigurationContext(
        Configuration(resources.configuration).apply { setLocale(Locale(lang)) },
    )
    fun t(res: Int) = words.getString(res)
    val now = (prefs.getString(WidgetLooks.configKey(id), null) ?: "app|app").split("|")

    title = t(R.string.wl_config_title)
    val pad = (16 * resources.displayMetrics.density).toInt()
    val root = LinearLayout(this).apply {
      orientation = LinearLayout.VERTICAL
      setPadding(pad, pad, pad, pad)
      layoutDirection = if (lang.startsWith("ar")) View.LAYOUT_DIRECTION_RTL else View.LAYOUT_DIRECTION_LTR
    }
    fun group(label: Int, options: List<Pair<String, Int>>, chosen: String): RadioGroup {
      root.addView(TextView(this).apply {
        text = t(label)
        textSize = 15f
        setPadding(0, pad / 2, 0, pad / 4)
      })
      val g = RadioGroup(this)
      options.forEachIndexed { i, (key, res) ->
        g.addView(RadioButton(this).apply {
          this.id = View.generateViewId()
          text = t(res)
          tag = key
          isChecked = key == chosen || (i == 0 && options.none { it.first == chosen })
        })
      }
      root.addView(g)
      return g
    }
    val looks = group(
        R.string.wl_config_look,
        listOf(
            "app" to R.string.wl_config_app,
            "handasi" to R.string.wl_look_handasi,
            "layli" to R.string.wl_look_layli,
            "makhtuta" to R.string.wl_look_makhtuta,
        ),
        now.getOrElse(0) { "app" },
    )
    val modes = group(
        R.string.wl_config_mode,
        listOf(
            "app" to R.string.wl_config_app,
            "light" to R.string.wl_mode_light,
            "night" to R.string.wl_mode_night,
        ),
        now.getOrElse(1) { "app" },
    )
    root.addView(Button(this).apply {
      text = t(R.string.wl_config_done)
      setOnClickListener {
        fun chosen(g: RadioGroup) = g.findViewById<View>(g.checkedRadioButtonId)?.tag as? String ?: "app"
        prefs.edit().putString(WidgetLooks.configKey(id), "${chosen(looks)}|${chosen(modes)}").apply()
        redrawAll()
        finish()
      }
    })
    setContentView(root)
  }

  /** Draws this widget again, whichever of the app's widgets it is. */
  private fun redrawAll() {
    val manager = AppWidgetManager.getInstance(this)
    val providers: List<HomeWidgetProvider> = listOf(
        VerseWidgetProvider(),
        KhatmaWidgetProvider(),
        TasbihWidgetProvider(),
        ActionsWidgetProvider(),
    )
    for (p in providers) {
      val ids = manager.getAppWidgetIds(ComponentName(this, p.javaClass))
      if (id in ids) redraw(this, p, intArrayOf(id))
    }
  }
}
