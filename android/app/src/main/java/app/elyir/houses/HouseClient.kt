// SPDX-License-Identifier: Apache-2.0
/*
 The widget asks the house itself, with the pass the Houses app holds for it, and never a server of ours: its Wi-Fi
 name at home, its own address away. Blocking calls, made from a worker or a broadcast's own thread.
 */
package app.elyir.houses

import java.net.HttpURLConnection
import java.net.URL

object HouseClient {
    private const val WAIT_MILLIS = 7_000

    fun base(house: HouseRecord): String {
        val lan = Base.lan(house) ?: return house.origin
        val answered = try {
            ask(Base.url(lan, "alive"), null, "GET", Base.LAN_WAIT_MILLIS) { it == 200 }
        } catch (_: Exception) { false }
        return Base.choose(house, answered)
    }

    /** The house's glance, or null when it could not be had. */
    fun glance(house: HouseRecord): Glance? = try {
        val conn = open(Base.url(base(house), "glance"), house.token, "GET", WAIT_MILLIS)
        try {
            if (conn.responseCode != 200) null
            else Glance.parse(conn.inputStream.bufferedReader().use { it.readText() })
        } finally { conn.disconnect() }
    } catch (_: Exception) { null }

    /** Bedtime or Everything off; whether the house said it ran. */
    fun run(scene: HouseScene, house: HouseRecord): Boolean = try {
        ask(Base.url(base(house), scene.path), house.token, "POST", WAIT_MILLIS) { it in 200..299 }
    } catch (_: Exception) { false }

    private fun ask(url: String, token: String?, method: String, wait: Int, ok: (Int) -> Boolean): Boolean {
        val conn = open(url, token, method, wait)
        return try {
            if (method == "POST") { conn.doOutput = true; conn.setFixedLengthStreamingMode(0); conn.outputStream.close() }
            ok(conn.responseCode)
        } finally { conn.disconnect() }
    }

    private fun open(url: String, token: String?, method: String, wait: Int) =
        (URL(url).openConnection() as HttpURLConnection).apply {
            requestMethod = method
            connectTimeout = wait
            readTimeout = wait
            useCaches = false
            instanceFollowRedirects = false
            setRequestProperty("Accept", "application/json")
            token?.let { setRequestProperty("Authorization", "Bearer $it") }
        }
}
