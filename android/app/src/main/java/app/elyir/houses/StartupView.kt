// SPDX-License-Identifier: Apache-2.0
/*
 J over the Houses app until it has opened onto it, drawn frame by frame from Startup.frame as StartupView in
 ios/Houses/Startup.swift draws it. `ready` is the Houses app's first page; `unreachable` brings up the one sentence.
 */
package app.elyir.houses

import android.annotation.SuppressLint
import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Matrix
import android.graphics.Paint
import android.graphics.Path
import android.graphics.PathMeasure
import android.graphics.RadialGradient
import android.graphics.Shader
import android.os.SystemClock
import android.util.TypedValue
import android.view.Gravity
import android.view.View
import android.widget.FrameLayout
import android.widget.TextView
import kotlin.math.min

@SuppressLint("ViewConstructor")
class StartupView(
    context: Context,
    private val s: Sequence,
    private val full: Boolean,
    private val done: () -> Unit,
) : FrameLayout(context) {

    var ready = false
        set(value) { field = value; if (value) unreachable = false }

    var unreachable = false
        set(value) {
            if (field == value) return
            field = value
            sentence.animate().alpha(if (value && !ready) 1f else 0f).setDuration(400).start()
        }

    private val began = SystemClock.uptimeMillis()
    private var endingAt: Double? = null
    private var over = false

    private val name = path(s.NAME.d)
    private val nameLength = lengths(name)
    private val roof = path(s.HOUSE.roof)
    private val walls = path(s.HOUSE.walls)
    private val ink = Color.parseColor(s.COLOR.ink)

    private val stroke = Paint(Paint.ANTI_ALIAS_FLAG).apply {
        style = Paint.Style.STROKE; strokeCap = Paint.Cap.ROUND; strokeJoin = Paint.Join.ROUND
    }
    private val fill = Paint(Paint.ANTI_ALIAS_FLAG)
    private val scratch = Path()
    private val trimmed = Path()
    private val place = Matrix()

    private val sentence = TextView(context).apply {
        setText(R.string.unreachable)
        setTextSize(TypedValue.COMPLEX_UNIT_SP, 15f)
        setTextColor(context.getColor(R.color.quiet))
        gravity = Gravity.CENTER
        maxWidth = dp(300)
        alpha = 0f
        accessibilityLiveRegion = View.ACCESSIBILITY_LIVE_REGION_POLITE
    }

    init {
        setWillNotDraw(false)
        addView(sentence, LayoutParams(LayoutParams.WRAP_CONTENT, LayoutParams.WRAP_CONTENT, Gravity.TOP or Gravity.CENTER_HORIZONTAL).apply {
            leftMargin = dp(16); rightMargin = dp(16)
        })
    }

    override fun onLayout(changed: Boolean, left: Int, top: Int, right: Int, bottom: Int) {
        super.onLayout(changed, left, top, right, bottom)
        val (k, _, oy) = fit()
        val center = oy + (s.HOUSE.top + s.HOUSE.size) * k + dp(40)
        sentence.translationY = (center - sentence.height / 2.0).toFloat()
    }

    override fun onDraw(canvas: Canvas) {
        if (over) return
        val elapsed = (SystemClock.uptimeMillis() - began) / 1000.0
        val t = if (full) elapsed else Startup.settled(s) + elapsed
        if (ready && t >= s.TIME.readyAfter && endingAt == null) endingAt = t
        endingAt?.let { if (t >= it + s.TIME.ending) { over = true; post(done); return } }

        val f = Startup.frame(t, endingAt, s)
        val fadeIn = if (full) 1.0 else Startup.ease(Startup.clamp01(elapsed / 0.3))
        canvas.drawColor(Color.BLACK)
        canvas.drawColor(rgb(s.COLOR.panel, f.out))
        val layer = if (fadeIn < 1) canvas.saveLayerAlpha(null, (fadeIn * 255).toInt()) else null
        draw(canvas, f)
        layer?.let(canvas::restoreToCount)
        postInvalidateOnAnimation()
    }

    private fun draw(canvas: Canvas, f: Startup.Frame) {
        val N = s.NAME; val H = s.HOUSE; val C = s.COLOR
        val (k, ox, oy) = fit()
        fun x(v: Double) = (ox + v * k).toFloat()
        fun y(v: Double) = (oy + v * k).toFloat()

        if (f.name > 0 && f.written > 0) {
            trim(name, nameLength, f.written, trimmed)
            place.setTranslate(-N.viewBox[0].toFloat(), -N.viewBox[1].toFloat())
            place.postScale((N.scale * k).toFloat(), (N.scale * k).toFloat())
            place.postTranslate(x(N.left), y(N.top))
            trimmed.transform(place, scratch)
            stroke.color = withAlpha(ink, f.name)
            stroke.strokeWidth = (N.stroke * N.scale * k).toFloat()
            canvas.drawPath(scratch, stroke)
        }

        val cx = x(H.left + H.size / 2); val cy = y(H.top + H.size / 2)
        if (f.houseGlow > 0) {
            val r = (f.houseGlowSize * k / 2).toFloat()
            fill.shader = RadialGradient(x(f.dotX), y(f.dotY), r,
                intArrayOf(rgb(C.lamp, f.houseGlow * 0.55), rgb(C.lamp, 0.0)), floatArrayOf(0f, 0.68f), Shader.TileMode.CLAMP)
            canvas.drawCircle(x(f.dotX), y(f.dotY), r, fill)
            fill.shader = null
        }
        if (f.house > 0) {
            val size = (H.size * f.houseScale * k).toFloat()
            place.setScale(size / 512, size / 512)
            place.postTranslate(cx - size / 2, cy - size / 2)
            stroke.color = withAlpha(ink, f.house)
            stroke.strokeWidth = (H.stroke * size / 512).toFloat()
            roof.transform(place, scratch); canvas.drawPath(scratch, stroke)
            walls.transform(place, scratch); canvas.drawPath(scratch, stroke)
        }
        if (f.unlit > 0) {
            val dx = x(f.dotX); val dy = y(f.dotY); val r = (f.dotSize * k / 2).toFloat()
            if (f.dotGlow > 0) {
                val g = r * (32 + 180) / 32
                val c = rgb(C.lamp, f.dotGlow * 0.45)
                fill.shader = RadialGradient(dx, dy, g, intArrayOf(c, c, rgb(C.lamp, 0.0)), floatArrayOf(0f, r / g, 1f), Shader.TileMode.CLAMP)
                canvas.drawCircle(dx, dy, g, fill)
                fill.shader = null
            }
            fill.color = rgb(C.unlit, f.unlit); canvas.drawCircle(dx, dy, r, fill)
            fill.color = rgb(C.lamp, f.lit); canvas.drawCircle(dx, dy, r, fill)
        }
    }

    /** The boards' 1440x900 space fitted to the screen: its scale and where it starts. */
    private fun fit(): Triple<Double, Double, Double> {
        val k = min(width / s.SPACE.width, height / s.SPACE.height)
        return Triple(k, (width - s.SPACE.width * k) / 2, (height - s.SPACE.height * k) / 2)
    }

    private fun dp(v: Int) = (v * resources.displayMetrics.density).toInt()

    private companion object {
        fun path(d: String) = Path().apply {
            for (seg in SvgPath.parse(d)) when (seg) {
                is Segment.Move -> moveTo(seg.x.toFloat(), seg.y.toFloat())
                is Segment.Line -> lineTo(seg.x.toFloat(), seg.y.toFloat())
                is Segment.Cubic -> cubicTo(seg.x1.toFloat(), seg.y1.toFloat(), seg.x2.toFloat(), seg.y2.toFloat(), seg.x.toFloat(), seg.y.toFloat())
                Segment.Close -> close()
            }
        }

        fun lengths(path: Path): List<Float> {
            val measure = PathMeasure(path, false)
            return buildList { do add(measure.length) while (measure.nextContour()) }
        }

        /** The first `fraction` of the path's whole length, as SwiftUI's trimmedPath(from: 0, to:) has it. */
        fun trim(path: Path, lengths: List<Float>, fraction: Double, into: Path) {
            into.reset()
            var left = (lengths.sum() * fraction).toFloat()
            val measure = PathMeasure(path, false)
            for (length in lengths) {
                if (left <= 0) break
                measure.getSegment(0f, min(left, length), into, true)
                left -= length
                if (!measure.nextContour()) break
            }
        }

        fun rgb(c: List<Double>, alpha: Double = 1.0) =
            Color.argb((Startup.clamp01(alpha) * 255).toInt(), c[0].toInt(), c[1].toInt(), c[2].toInt())

        fun withAlpha(color: Int, alpha: Double) = (color and 0xffffff) or ((Startup.clamp01(alpha) * 255).toInt() shl 24)
    }
}
