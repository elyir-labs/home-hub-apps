// SPDX-License-Identifier: Apache-2.0
/*
 Which house a widget shows, asked when it is added and again from the launcher's own Reconfigure. With one house or
 none there is nothing to ask, so it is set at once. Otherwise the houses are listed with the one opened last marked,
 and a tap on one is the answer.
 */
package app.elyir.houses

import android.app.Activity
import android.appwidget.AppWidgetManager
import android.content.Intent
import android.content.res.ColorStateList
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.graphics.drawable.RippleDrawable
import android.os.Bundle
import android.util.TypedValue
import android.view.Gravity
import android.view.ViewGroup.LayoutParams.MATCH_PARENT
import android.view.ViewGroup.LayoutParams.WRAP_CONTENT
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView

class HousePicker : Activity() {
    private var widget = AppWidgetManager.INVALID_APPWIDGET_ID

    override fun onCreate(state: Bundle?) {
        super.onCreate(state)
        widget = intent.getIntExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, AppWidgetManager.INVALID_APPWIDGET_ID)
        setResult(RESULT_CANCELED, answer())
        if (widget == AppWidgetManager.INVALID_APPWIDGET_ID) return finish()

        val store = HouseStore.of(this)
        val houses = store.houses()
        if (houses.size <= 1) return choose(store, houses.firstOrNull()?.id)
        val suggested = Face.choose(houses, store.picked(widget), store.opened)?.id

        val list = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(24), dp(56), dp(24), dp(24))
        }
        list.addView(TextView(this).apply {
            text = getString(R.string.widget_pick)
            setTextColor(getColor(R.color.ink))
            setTextSize(TypedValue.COMPLEX_UNIT_SP, 22f)
            setPadding(dp(4), 0, dp(4), dp(20))
        })
        for (house in houses) {
            list.addView(row(house.name, house.id == suggested) { choose(store, house.id) },
                LinearLayout.LayoutParams(MATCH_PARENT, dp(56)).apply { bottomMargin = dp(10) })
        }
        window.statusBarColor = getColor(R.color.night)
        window.navigationBarColor = getColor(R.color.night)
        setContentView(ScrollView(this).apply {
            setBackgroundColor(getColor(R.color.night))
            isFillViewport = true
            addView(list, MATCH_PARENT, WRAP_CONTENT)
        })
    }

    private fun row(name: String, suggested: Boolean, tap: () -> Unit) = TextView(this).apply {
        text = name
        setTextColor(getColor(R.color.ink))
        setTextSize(TypedValue.COMPLEX_UNIT_SP, 17f)
        if (suggested) typeface = Typeface.create("sans-serif-medium", Typeface.NORMAL)
        gravity = Gravity.CENTER_VERTICAL
        setPadding(dp(20), 0, dp(20), 0)
        val pill = GradientDrawable().apply {
            cornerRadius = dp(28).toFloat()
            setColor(if (suggested) 0x1Fe9b872 else 0x1Affffff)
            setStroke(dp(1), if (suggested) 0x66e9b872 else 0x24ffffff)
        }
        background = RippleDrawable(ColorStateList.valueOf(0x33ffffff), pill, null)
        if (suggested) {
            val lamp = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                setColor(getColor(R.color.lamp))
                setSize(dp(8), dp(8))
            }
            setCompoundDrawablesRelativeWithIntrinsicBounds(null, null, lamp, null)
        }
        setOnClickListener { tap() }
    }

    private fun choose(store: HouseStore, id: String?) {
        store.pick(widget, id)
        Widgets.drawKept(this, intArrayOf(widget))
        Work.refresh(this)
        setResult(RESULT_OK, answer())
        finish()
    }

    private fun answer() = Intent().putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widget)

    private fun dp(v: Int) = (v * resources.displayMetrics.density).toInt()
}
