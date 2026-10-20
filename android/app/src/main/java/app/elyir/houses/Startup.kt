// SPDX-License-Identifier: Apache-2.0
/*
 How the app starts (design/boot/ in the hub's repository, J, and the app's half decided 19 October 2026): elyir
 written by hand, the dot of the i lighting like a lamp and gliding into the house, then breathing there until the
 Houses app is ready. All of it the first time the app opens; the house breathing on every start after.

 The numbers are the wall's own (assets/startup.json, copied by tools/startup.sh from the hub's startup/sequence.json),
 and `Startup.frame` is the boot splash's refresh() in startup/plymouth.mjs, line for line as ios/Houses/Startup.swift
 has it, so the wall and both phones stay one picture. Kept free of Android so it can be tested on its own.
 */
package app.elyir.houses

import org.json.JSONArray
import org.json.JSONObject
import kotlin.math.PI
import kotlin.math.max
import kotlin.math.min
import kotlin.math.sin

class Sequence(json: String) {
    class Space(val width: Double, val height: Double)
    class Colors(val ink: String, val lamp: List<Double>, val unlit: List<Double>, val panel: List<Double>)
    class Name(val d: String, val viewBox: List<Double>, val scale: Double, val stroke: Double, val left: Double, val top: Double, val tittleSize: Double, val tittle: List<Double>)
    class House(val roof: String, val walls: String, val stroke: Double, val size: Double, val left: Double, val top: Double, val lampSize: Double, val lamp: List<Double>)
    class Time(val write: Double, val dotted: Double, val lit: Double, val hold: Double, val nameOut: Double, val leave: Double, val houseIn: Double, val land: Double, val ending: Double, val readyAfter: Double)
    class Breath(val period: Double, val low: Double)

    val SPACE: Space
    val COLOR: Colors
    val NAME: Name
    val HOUSE: House
    val TIME: Time
    val BREATH: Breath

    init {
        val o = JSONObject(json)
        fun JSONObject.list(key: String): List<Double> = getJSONArray(key).let { a: JSONArray -> List(a.length()) { a.getDouble(it) } }
        o.getJSONObject("SPACE").run { SPACE = Space(getDouble("width"), getDouble("height")) }
        o.getJSONObject("COLOR").run { COLOR = Colors(getString("ink"), list("lamp"), list("unlit"), list("panel")) }
        o.getJSONObject("NAME").run {
            NAME = Name(getString("d"), list("viewBox"), getDouble("scale"), getDouble("stroke"), getDouble("left"), getDouble("top"), getDouble("tittleSize"), list("tittle"))
        }
        o.getJSONObject("HOUSE").run {
            HOUSE = House(getString("roof"), getString("walls"), getDouble("stroke"), getDouble("size"), getDouble("left"), getDouble("top"), getDouble("lampSize"), list("lamp"))
        }
        o.getJSONObject("TIME").run {
            TIME = Time(getDouble("write"), getDouble("dotted"), getDouble("lit"), getDouble("hold"), getDouble("nameOut"), getDouble("leave"), getDouble("houseIn"), getDouble("land"), getDouble("ending"), getDouble("readyAfter"))
        }
        o.getJSONObject("BREATH").run { BREATH = Breath(getDouble("period"), getDouble("low")) }
    }
}

object Startup {
    /** One moment, in the boards' space (1440x900). Opacities are 0..1. */
    data class Frame(
        var written: Double = 0.0, var name: Double = 0.0,
        var house: Double = 0.0, var houseScale: Double = 1.0,
        var dotX: Double = 0.0, var dotY: Double = 0.0, var dotSize: Double = 0.0,
        var unlit: Double = 0.0, var lit: Double = 0.0, var dotGlow: Double = 0.0,
        var houseGlow: Double = 0.0, var houseGlowSize: Double = 0.0,
        var out: Double = 0.0,
    )

    fun clamp01(v: Double) = min(max(v, 0.0), 1.0)
    fun ramp(t: Double, a: Double, b: Double) = clamp01((t - a) / (b - a))
    fun ease(x: Double) = x * x * (3 - 2 * x)
    fun breath(t: Double, period: Double) = 0.5 + 0.5 * sin(t / period * 2 * PI - PI / 2)

    /** `t` seconds into J; `endingAt` once the app is ready and the ending has begun. */
    fun frame(t: Double, endingAt: Double?, s: Sequence): Frame {
        val T = s.TIME; val N = s.NAME; val H = s.HOUSE
        val f = Frame()
        f.out = endingAt?.let { ease(ramp(t, it, it + T.ending)) } ?: 0.0
        f.written = ease(clamp01(t / T.write))
        f.name = 1 - ease(ramp(t, T.hold, T.hold + T.nameOut))

        val inn = ease(ramp(t, T.houseIn - 0.2, T.houseIn + 0.8))
        f.houseScale = (0.96 + 0.04 * inn) * (1 + 0.18 * f.out)
        f.house = inn * (1 - f.out)

        val appear = ease(ramp(t, T.dotted, T.dotted + 0.3)) * (1 - f.out)
        var k = ease(ramp(t, T.lit, T.lit + 0.8)) * (s.BREATH.low + (1 - s.BREATH.low) * breath(t, s.BREATH.period))
        if (endingAt != null) k = 1.0
        val move = ease(ramp(t, T.leave, T.land))
        val cx = H.left + H.size / 2; val cy = H.top + H.size / 2
        val x = N.tittle[0] + (H.lamp[0] - N.tittle[0]) * move
        val y = N.tittle[1] + (H.lamp[1] - N.tittle[1]) * move
        f.dotX = cx + (x - cx) * (1 + 0.18 * f.out); f.dotY = cy + (y - cy) * (1 + 0.18 * f.out)
        f.dotSize = (N.tittleSize + (H.lampSize - N.tittleSize) * move) * (1 + 0.18 * f.out)
        f.unlit = appear
        f.lit = appear * k

        val landed = ramp(t, T.land, T.land + 0.6)
        f.dotGlow = appear * k * (1 - landed)
        f.houseGlow = k * landed * inn * (1 - f.out)
        f.houseGlowSize = H.size * 1.1 * (1 + 3 * f.out)
        return f
    }

    /** Where a start that has seen J before begins: the house in, the dot landed, the lamp lit. */
    fun settled(s: Sequence) = s.TIME.land + 0.6
}
