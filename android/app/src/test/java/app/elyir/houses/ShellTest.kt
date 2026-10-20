// SPDX-License-Identifier: Apache-2.0
package app.elyir.houses

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/** The same cases as ios/HousesTests/ShellTests.swift, saying android where iOS says ios. */
class ShellTest {
    @Test fun opensTheHousesAppSayingItIsTheAndroidShellAndTheStorefront() {
        assertEquals("https://houses.elyir.app/?shell=android&store=US", Shell.start(storefront = "US"))
        assertEquals("https://houses.elyir.app/?shell=android&store=US", Shell.start(storefront = "USA"))
    }

    @Test fun aStorefrontItCannotNameIsLeftOffSoThePageTreatsItAsNotTheUS() {
        assertEquals("https://houses.elyir.app/?shell=android", Shell.start(storefront = "CAN"))
        assertEquals("https://houses.elyir.app/?shell=android", Shell.start(storefront = null))
        assertEquals("https://houses.elyir.app/?shell=android", Shell.start(storefront = ""))
        assertEquals("https://houses.elyir.app/?shell=android&store=GB", Shell.start(storefront = "gb"))
    }

    @Test fun theHousesAppAndEveryHouseInsideItStay() {
        assertFalse(Shell.opensOutside("https://houses.elyir.app/add", mainFrame = true))
        assertFalse(Shell.opensOutside("https://maple-court.elyir.app/?app=1", mainFrame = false))
        assertFalse(Shell.opensOutside("https://192-168-1-53.maple-court.home.elyir.app/?app=1", mainFrame = false))
        assertFalse(Shell.opensOutside("https://hub.elyir.com/try/?app=1&shell=android", mainFrame = false))
        assertFalse(Shell.opensOutside("about:blank", mainFrame = false))
    }

    @Test fun payingAndEveryOtherPageLeaveForTheBrowser() {
        assertTrue(Shell.opensOutside("https://pay.example/start?house=jordan", mainFrame = true))
        assertTrue(Shell.opensOutside("https://github.com/elyir-labs/home-hub/blob/main/relay/README.md", mainFrame = true))
        assertTrue(Shell.opensOutside("https://maple-court.elyir.app/", mainFrame = true))
        assertTrue(Shell.opensOutside("mailto:hello@elyir.com", mainFrame = false))
    }

    @Test fun aDevServerIsHomeWhenTheEmulatorIsPointedAtOne() {
        val dev = "http://10.0.2.2:5174/"
        assertFalse(Shell.opensOutside("http://10.0.2.2:5174/add", mainFrame = true, home = dev))
        assertTrue(Shell.opensOutside("http://10.0.2.2:8399/", mainFrame = true, home = dev))
        assertEquals("http://10.0.2.2:5174/?shell=android&store=US", Shell.start(dev, "US"))
    }

    @Test fun aHomeThatAlreadyHasAQueryKeepsIt() {
        assertEquals("http://10.0.2.2:5177/?try=1&shell=android&store=US#top", Shell.start("http://10.0.2.2:5177/?try=1#top", "US"))
    }
}
