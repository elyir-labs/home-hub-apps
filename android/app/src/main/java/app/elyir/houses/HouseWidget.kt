// SPDX-License-Identifier: Apache-2.0
/*
 A house on the home screen (design/widget/ in the hub's repository, decided 20 October 2026): one widget, how the
 house is in the small size and the same with Bedtime and Everything off in the medium. The picker offers both sizes
 as their own entries, and either one drawn wide enough becomes the medium. It asks the house about every quarter of
 an hour, and a tap anywhere but a button opens that house in the app.
 */
package app.elyir.houses

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.util.SizeF
import android.view.View
import android.widget.RemoteViews

abstract class HouseWidget : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        Widgets.drawKept(context, ids)
        Work.refresh(context)
    }

    override fun onAppWidgetOptionsChanged(context: Context, manager: AppWidgetManager, id: Int, options: Bundle) {
        Widgets.drawKept(context, intArrayOf(id))
    }

    override fun onDeleted(context: Context, ids: IntArray) {
        val store = HouseStore.of(context)
        ids.forEach { store.pick(it, null) }
    }

    override fun onEnabled(context: Context) = Work.refresh(context)

    override fun onDisabled(context: Context) {
        if (Widgets.all(context).isEmpty()) Work.stop(context)
    }
}

class SmallHouse : HouseWidget()
class MediumHouse : HouseWidget()

/** Bedtime or Everything off from the medium size. Not exported: only the widget's own buttons reach it. */
class SceneTap : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val house = intent.getStringExtra(HOUSE)?.takeIf(HouseLink::isID) ?: return
        val scene = HouseScene.entries.firstOrNull { it.name == intent.getStringExtra(SCENE) } ?: return
        Work.run(context, house, scene)
    }

    companion object {
        const val HOUSE = "house"
        const val SCENE = "scene"
    }
}

object Widgets {
    /** Wide enough for the two buttons. */
    private const val MEDIUM_WIDTH_DP = 250f

    fun all(context: Context): IntArray {
        val manager = AppWidgetManager.getInstance(context)
        return listOf(SmallHouse::class.java, MediumHouse::class.java)
            .flatMap { manager.getAppWidgetIds(ComponentName(context, it)).asList() }.toIntArray()
    }

    /** Draws from what is kept, without asking any house; quick enough for the main thread. */
    fun drawKept(context: Context, ids: IntArray = all(context)) {
        val store = HouseStore.of(context)
        val now = System.currentTimeMillis()
        for (id in ids) {
            val house = store.house(id)
            draw(context, id, Face.make(house, null, house?.let { store.kept(it.id) }, house?.let { store.tap(it.id) }, now))
        }
    }

    fun draw(context: Context, id: Int, face: Face) {
        val manager = AppWidgetManager.getInstance(context)
        val small = views(context, id, face, wide = false)
        val medium = views(context, id, face, wide = true)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            manager.updateAppWidget(id, RemoteViews(mapOf(SizeF(0f, 0f) to small, SizeF(MEDIUM_WIDTH_DP, 0f) to medium)))
        } else {
            val width = manager.getAppWidgetOptions(id).getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 0)
            val wide = if (width > 0) width >= MEDIUM_WIDTH_DP else isMedium(context, manager, id)
            manager.updateAppWidget(id, if (wide) medium else small)
        }
    }

    private fun isMedium(context: Context, manager: AppWidgetManager, id: Int) =
        manager.getAppWidgetInfo(id)?.provider == ComponentName(context, MediumHouse::class.java)

    private fun views(context: Context, widget: Int, face: Face, wide: Boolean): RemoteViews {
        val v = RemoteViews(context.packageName, if (wide) R.layout.widget_medium else R.layout.widget_small)
        val ink = context.getColor(R.color.ink)
        val muted = context.getColor(R.color.quiet)
        val lamp = context.getColor(R.color.lamp)

        v.setOnClickPendingIntent(android.R.id.background, open(context, widget, face.id))
        val sky = Sky.of(face.sky)
        v.setViewVisibility(R.id.weather, if (face.temp != null) View.VISIBLE else View.GONE)
        v.setTextViewText(R.id.temp, face.temp.orEmpty())
        v.setViewVisibility(R.id.sky, if (sky != null) View.VISIBLE else View.GONE)
        sky?.let { v.setImageViewResource(R.id.sky, skyPicture(it)) }

        v.setViewVisibility(R.id.none, if (face.hasHouse) View.GONE else View.VISIBLE)
        v.setTextViewText(R.id.none, Words.NO_HOUSES)
        val house = if (face.hasHouse) View.VISIBLE else View.GONE
        v.setViewVisibility(R.id.name, house)
        v.setTextViewText(R.id.name, face.name)

        val said = face.said.takeIf { wide }
        v.setViewVisibility(R.id.line, if (face.hasHouse && said == null) View.VISIBLE else View.GONE)
        v.setTextViewText(R.id.line, if (wide) face.line else face.lines.joinToString("\n"))
        v.setTextColor(R.id.line, if (face.tone == Face.Tone.Needs) lamp else muted)
        if (!wide) v.setInt(R.id.line, "setMaxLines", if (face.age == null) 3 else 2)
        v.setViewVisibility(R.id.age, if (face.hasHouse && said == null && face.age != null) View.VISIBLE else View.GONE)
        v.setTextViewText(R.id.age, face.age.orEmpty())

        if (wide) {
            v.setViewVisibility(R.id.said, if (said != null) View.VISIBLE else View.GONE)
            v.setTextViewText(R.id.said, said?.text.orEmpty())
            v.setTextColor(R.id.said, if (said?.failed == true) lamp else ink)
            v.setViewVisibility(R.id.scenes, if (face.id != null) View.VISIBLE else View.GONE)
            face.id?.let { id ->
                v.setOnClickPendingIntent(R.id.bedtime, scene(context, id, HouseScene.asleep))
                v.setOnClickPendingIntent(R.id.everything_off, scene(context, id, HouseScene.away))
            }
        }
        return v
    }

    private fun skyPicture(sky: Sky) = when (sky) {
        Sky.Sun -> R.drawable.sky_sun
        Sky.Moon -> R.drawable.sky_moon
        Sky.Partly -> R.drawable.sky_partly
        Sky.Cloud -> R.drawable.sky_cloud
        Sky.Rain -> R.drawable.sky_rain
        Sky.Snow -> R.drawable.sky_snow
        Sky.Storm -> R.drawable.sky_storm
        Sky.Fog -> R.drawable.sky_fog
    }

    /** Opens the app on this house; the address makes each widget's intent its own. */
    private fun open(context: Context, widget: Int, id: String?): PendingIntent {
        val intent = Intent(context, Houses::class.java)
            .setAction(Intent.ACTION_VIEW)
            .setData(Uri.parse(HouseLink.url(id)))
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        return PendingIntent.getActivity(context, widget, intent, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
    }

    private fun scene(context: Context, id: String, scene: HouseScene): PendingIntent {
        val intent = Intent(context, SceneTap::class.java)
            .setData(Uri.parse(HouseLink.url(id) + "#" + scene.name))
            .putExtra(SceneTap.HOUSE, id)
            .putExtra(SceneTap.SCENE, scene.name)
        return PendingIntent.getBroadcast(context, 0, intent, PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
    }
}
