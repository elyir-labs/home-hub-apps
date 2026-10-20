// SPDX-License-Identifier: Apache-2.0
/*
 What the shell owes the Houses app (docs/apps.md in the hub's repository, "What the shell owes the page"):
 where it opens, what it says about the store it came from, and which links leave for the system browser.
 Kept free of Android so the rules can be tested on their own, and the same rules as ios/Houses/Shell.swift.
 */
package app.elyir.houses

import java.net.URI
import java.net.URISyntaxException

object Shell {
    const val HOUSES = "https://houses.elyir.app/"

    /** The address the app opens. A storefront it cannot read counts as not the US (design/store-app/, C), so it is left off. */
    fun start(base: String = HOUSES, storefront: String?): String {
        val fragment = base.substringAfter('#', "")
        val address = base.substringBefore('#')
        val query = listOfNotNull(
            address.substringAfter('?', "").takeIf { it.isNotEmpty() },
            "shell=android",
            storefront?.let(::twoLetters)?.let { "store=$it" },
        ).joinToString("&")
        return address.substringBefore('?') + "?" + query + (if (fragment.isEmpty()) "" else "#$fragment")
    }

    /** Play names the country in two letters already; the three-letter form is kept so both shells read the same. */
    fun twoLetters(storefront: String): String? {
        val code = storefront.uppercase()
        if (code.length == 2) return code
        return mapOf("USA" to "US")[code]
    }

    /**
     * Whether a navigation leaves the app for the system browser. The Houses app and the houses it frames stay;
     * a page opened toward anywhere else (paying, a help page) goes out, and so does anything that isn't the web.
     */
    fun opensOutside(url: String, mainFrame: Boolean, home: String = HOUSES): Boolean {
        val to = parse(url) ?: return mainFrame
        val scheme = to.scheme?.lowercase()
        if (scheme != "https" && scheme != "http") return scheme != "about"
        if (!mainFrame) return false
        val at = parse(home) ?: return true
        return to.host?.lowercase() != at.host?.lowercase() || to.port != at.port
    }

    private fun parse(url: String): URI? = try { URI(url) } catch (_: URISyntaxException) { null }
}
