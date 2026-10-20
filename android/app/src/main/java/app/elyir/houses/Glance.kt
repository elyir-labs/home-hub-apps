// SPDX-License-Identifier: Apache-2.0
/*
 What the widget says (design/widget/ in the hub's repository, A as the small size and C as the medium, decided
 20 October 2026), kept free of Android and the network so every case can be tested on its own: the houses the
 Houses app hands over, how a house answers /glance, which house a widget shows, and the words for each moment.
 The same rules and words as ios/Shared/Glance.swift.
 */
package app.elyir.houses

import org.json.JSONArray
import org.json.JSONException
import org.json.JSONObject
import java.net.URI
import java.net.URISyntaxException

/** One house as the Houses app keeps it. `token` is this phone's pass for the house. */
data class HouseRecord(val id: String, val name: String, val origin: String, val lan: String?, val token: String) {
    fun json(): JSONObject = JSONObject().put("id", id).put("name", name).put("origin", origin)
        .put("lan", lan ?: JSONObject.NULL).put("token", token)

    companion object {
        fun listJson(houses: List<HouseRecord>): String = JSONArray(houses.map { it.json() }).toString()

        fun parseList(json: String?): List<HouseRecord> {
            val rows = try { JSONArray(json ?: return emptyList()) } catch (_: JSONException) { return emptyList() }
            return (0 until rows.length()).mapNotNull { rows.optJSONObject(it)?.let(::record) }
        }

        /** A house without a pass, a web address or a proper id is left out. */
        fun record(row: JSONObject): HouseRecord? {
            val id = row.text("id")?.takeIf(HouseLink::isID) ?: return null
            val name = row.text("name") ?: return null
            val origin = row.text("origin") ?: return null
            val at = try { URI(origin) } catch (_: URISyntaxException) { return null }
            if (at.scheme?.lowercase() !in setOf("https", "http") || at.host.isNullOrEmpty()) return null
            val token = row.text("token")?.takeIf { it.isNotEmpty() } ?: return null
            return HouseRecord(id, name, origin, row.text("lan")?.takeIf { it.isNotEmpty() }, token)
        }
    }
}

/** How a house answers `GET /glance`. `at` is in epoch milliseconds. */
data class Glance(
    val name: String? = null,
    val temp: String? = null,
    val sky: String? = null,
    val said: List<String> = emptyList(),
    val needs: String? = null,
    val count: Int = 0,
    val at: Long? = null,
) {
    /** Kept the way the house says it, in seconds. */
    fun json(): JSONObject = JSONObject().put("name", name ?: JSONObject.NULL).put("temp", temp ?: JSONObject.NULL)
        .put("sky", sky ?: JSONObject.NULL).put("said", JSONArray(said)).put("needs", needs ?: JSONObject.NULL)
        .put("count", count).put("at", at?.let { it / 1000.0 } ?: JSONObject.NULL)

    companion object {
        fun parse(json: String): Glance = from(JSONObject(json))

        fun from(o: JSONObject): Glance {
            val said = o.optJSONArray("said")?.let { a -> (0 until a.length()).mapNotNull { a.opt(it) as? String } } ?: emptyList()
            // The house says seconds; a value that can only be milliseconds is read as such.
            val at = if (o.isNull("at")) null else o.optDouble("at").takeIf { !it.isNaN() }?.let {
                if (it > 1e11) it.toLong() else (it * 1000).toLong()
            }
            return Glance(o.text("name"), o.text("temp"), o.text("sky"), said, o.text("needs"), o.optInt("count", 0), at)
        }
    }
}

private fun JSONObject.text(key: String): String? = if (isNull(key)) null else opt(key) as? String

/** The last glance a house gave, and when this phone got it (epoch milliseconds). */
data class Kept(val glance: Glance, val got: Long) {
    fun json(): String = JSONObject().put("glance", glance.json()).put("got", got).toString()

    companion object {
        fun parse(json: String?): Kept? = try {
            json?.let { JSONObject(it) }?.let { Kept(Glance.from(it.getJSONObject("glance")), it.getLong("got")) }
        } catch (_: JSONException) { null }
    }
}

/** The two things people say to a whole house, as the panel's routines row has them. */
enum class HouseScene(val title: String, val done: String) {
    asleep("Bedtime", "Good night. The house is off."),
    away("Everything off", "Everything is off.");

    val path: String get() = "home/intent/$name"
}

/** A tap on one of the medium widget's two buttons, kept until the refresh after it. */
data class Tap(val id: String, val scene: HouseScene, val ok: Boolean, val at: Long) {
    fun json(): String = JSONObject().put("id", id).put("scene", scene.name).put("ok", ok).put("at", at).toString()

    companion object {
        fun parse(json: String?): Tap? = try {
            json?.let { JSONObject(it) }?.let { Tap(it.getString("id"), HouseScene.valueOf(it.getString("scene")), it.getBoolean("ok"), it.getLong("at")) }
        } catch (_: Exception) { null }
    }
}

/** What the Houses app tells the shell about its list. */
sealed class HousesMessage {
    data class List(val houses: kotlin.collections.List<HouseRecord>) : HousesMessage()
    data class Opened(val id: String) : HousesMessage()

    companion object {
        fun parse(body: String): HousesMessage? {
            val o = try { JSONObject(body) } catch (_: JSONException) { return null }
            return when (o.text("type")) {
                "houses:list" -> o.optJSONArray("houses")?.let { rows ->
                    List((0 until rows.length()).mapNotNull { rows.optJSONObject(it)?.let { row -> HouseRecord.record(row) } })
                }
                "houses:opened" -> o.text("id")?.takeIf(HouseLink::isID)?.let(::Opened)
                else -> null
            }
        }
    }
}

/** `houses://open/<id>`: what a tap on the widget opens. */
object HouseLink {
    fun url(id: String?): String = "houses://open/" + (id?.takeIf(::isID) ?: "")

    fun id(url: String?): String? {
        val at = try { URI(url ?: return null) } catch (_: URISyntaxException) { return null }
        if (at.scheme?.lowercase() != "houses" || at.host?.lowercase() != "open") return null
        return at.path.orEmpty().trim('/').takeIf(::isID)
    }

    /** A house's id is its label in the zone (`jordan` of jordan.elyir.app). */
    fun isID(s: String): Boolean =
        s.isNotEmpty() && s.length <= 63 && s.all { it.code < 128 && (it.isLetterOrDigit() || it in "-_.") }
}

/**
 * Where to ask a house: its Wi-Fi name if that answers within a second and a half, else its own address. The same
 * rule as the Houses app's `reach()`.
 */
object Base {
    const val LAN_WAIT_MILLIS = 1_500

    fun lan(house: HouseRecord): String? = house.lan?.let { "https://$it" }

    fun choose(house: HouseRecord, lanAnswered: Boolean): String =
        if (lanAnswered) lan(house) ?: house.origin else house.origin

    fun url(base: String, path: String): String = base.trimEnd('/') + "/" + path
}

/** Everything a widget draws, worked out before any view sees it. */
data class Face(
    val id: String?,
    val name: String,
    val temp: String? = null,
    val sky: String? = null,
    val lines: List<String>,
    val tone: Tone = Tone.Plain,
    val age: String? = null,
    val said: Said? = null,
) {
    enum class Tone { Plain, Needs }

    /** What a tap on Bedtime or Everything off came to, until the next refresh. */
    data class Said(val text: String, val failed: Boolean)

    val hasHouse: Boolean get() = id != null

    /** The medium size has one line beside the house; the small one gives each its own. */
    val line: String get() = lines.joinToString(" · ")

    companion object {
        const val REFRESH_MILLIS = 15 * 60 * 1000L

        val noHouses = Face(id = null, name = "", lines = listOf(Words.NO_HOUSES))

        val sample = Face(id = "home", name = "Home", temp = "78°", sky = "partlycloudy", lines = listOf("On in 5 rooms", "2 people home"))

        /** The house a widget shows: the one picked for it, else the one last opened, else the first. */
        fun choose(houses: List<HouseRecord>, picked: String?, opened: String?): HouseRecord? =
            houses.firstOrNull { it.id == picked } ?: houses.firstOrNull { it.id == opened } ?: houses.firstOrNull()

        fun make(house: HouseRecord?, fresh: Glance?, kept: Kept?, tap: Tap?, now: Long): Face {
            house ?: return noHouses
            val glance = fresh ?: kept?.glance
            var face = if (glance != null) {
                Face(
                    id = house.id, name = name(house, glance), temp = glance.temp, sky = glance.sky, lines = Words.lines(glance),
                    tone = if (Words.needs(glance) == null) Tone.Plain else Tone.Needs,
                    age = if (fresh == null && kept != null) Words.age((now - (kept.glance.at ?: kept.got)) / 1000) else null,
                )
            } else {
                Face(id = house.id, name = house.name, lines = listOf(Words.UNREACHABLE))
            }
            if (tap != null && tap.id == house.id && showsTap(tap, now)) {
                face = face.copy(said = Said(if (tap.ok) tap.scene.done else Words.couldNotReach(face.name), !tap.ok))
            }
            return face
        }

        fun showsTap(tap: Tap, now: Long): Boolean {
            val since = now - tap.at
            return since >= -60_000 && since < REFRESH_MILLIS
        }

        private fun name(house: HouseRecord, glance: Glance) = house.name.ifEmpty { glance.name ?: house.id }
    }
}

object Words {
    const val NO_HOUSES = "Open Houses to add your house."
    const val UNREACHABLE = "Can’t reach it right now"

    fun couldNotReach(name: String) = "Couldn’t reach $name."

    /** The same line Houses says for a house: what needs somebody, else what the house says of itself. */
    fun needs(g: Glance): String? = when {
        g.count > 1 -> "${g.count} things need a look"
        g.count == 1 || g.needs != null -> g.needs?.takeIf { it.isNotEmpty() } ?: "Something needs a look"
        else -> null
    }

    fun lines(g: Glance): List<String> = needs(g)?.let(::listOf) ?: g.said.filter { it.isNotEmpty() }.take(2)

    fun age(seconds: Long): String {
        val s = maxOf(0L, seconds)
        return when {
            s < 60 -> "Just now"
            s < 3600 -> "${s / 60} min ago"
            s < 7200 -> "1 hour ago"
            s < 86_400 -> "${s / 3600} hours ago"
            s < 172_800 -> "Yesterday"
            else -> "${s / 86_400} days ago"
        }
    }
}

/** The house's weather as one of the few small pictures the widget draws, from the panel's sky keys (app/src/sky.ts). */
enum class Sky {
    Sun, Moon, Partly, Cloud, Rain, Snow, Storm, Fog;

    companion object {
        fun of(key: String?): Sky? = when (key) {
            "sunny" -> Sun
            "clear-night" -> Moon
            "partlycloudy" -> Partly
            "cloudy", "windy", "windy-variant", "exceptional" -> Cloud
            "rainy", "pouring", "hail" -> Rain
            "snowy", "snowy-rainy" -> Snow
            "lightning", "lightning-rainy" -> Storm
            "fog" -> Fog
            else -> null
        }
    }
}
