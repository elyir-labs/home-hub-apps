// SPDX-License-Identifier: Apache-2.0
package app.elyir.houses

import org.json.JSONArray
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * What the widget says for each moment (design/widget/, A small and C medium), and the contract with the Houses app
 * and the house that it is built on. The same cases as ios/HousesTests/WidgetTests.swift.
 */
class WidgetTest {
    private val home = HouseRecord("maple-court", "Home", "https://maple-court.elyir.app", "192-168-1-53.maple-court.home.elyir.app", "pass")
    private val elm = HouseRecord("elm", "Elm Street", "https://elm.elyir.app", null, "pass2")
    private val now = 1_800_000_000_000L

    private fun glance(said: List<String> = listOf("On in 5 rooms", "2 people home"), needs: String? = null, count: Int = 0) =
        Glance("Maple Court", "78°", "partlycloudy", said, needs, count, now)

    private fun list(vararg rows: JSONObject) =
        JSONObject().put("type", "houses:list").put("houses", JSONArray(rows.toList())).toString()

    private fun row(id: String, name: String, origin: String, token: String, lan: Any? = null) =
        JSONObject().put("id", id).put("name", name).put("origin", origin).put("token", token).also { if (lan != null) it.put("lan", lan) }

    // The Houses app's messages

    @Test fun theListArrivesWithEachHousesPass() {
        val body = list(
            row("maple-court", "Home", "https://maple-court.elyir.app", "pass", "192-168-1-53.maple-court.home.elyir.app"),
            row("elm", "Elm Street", "https://elm.elyir.app", "pass2", JSONObject.NULL),
        )
        assertEquals(HousesMessage.List(listOf(home, elm)), HousesMessage.parse(body))
    }

    @Test fun aHouseWithoutAPassOrAnAddressIsLeftOut() {
        val body = list(
            row("a", "A", "https://a.elyir.app", ""),
            row("b", "B", "javascript:alert(1)", "t"),
            row("../c", "C", "https://c.elyir.app", "t"),
            row("d", "D", "https://d.elyir.app", "t", ""),
        )
        assertEquals(HousesMessage.List(listOf(HouseRecord("d", "D", "https://d.elyir.app", null, "t"))), HousesMessage.parse(body))
    }

    @Test fun theHouseOpenedIsSaidByItsID() {
        assertEquals(HousesMessage.Opened("elm"), HousesMessage.parse("""{"type":"houses:opened","id":"elm"}"""))
        assertNull(HousesMessage.parse("""{"type":"houses:opened","id":"elm/../x"}"""))
        assertNull(HousesMessage.parse("""{"type":"something-else"}"""))
        assertNull(HousesMessage.parse("houses:list"))
    }

    @Test fun onlyTheHousesAppsOwnPageIsBelieved() {
        assertTrue(Shell.trusts(mainFrame = true, host = "houses.elyir.app"))
        assertFalse(Shell.trusts(mainFrame = false, host = "houses.elyir.app"))
        assertFalse(Shell.trusts(mainFrame = true, host = "maple-court.elyir.app"))
        assertFalse(Shell.trusts(mainFrame = true, host = null))
        assertTrue(Shell.trusts(mainFrame = true, host = "10.0.2.2", home = "http://10.0.2.2:5179/"))
    }

    @Test fun theWebViewHearsOnlyTheHousesAppsOrigin() {
        assertEquals("https://houses.elyir.app", Shell.origin())
        assertEquals("http://10.0.2.2:5179", Shell.origin("http://10.0.2.2:5179/?try=1"))
    }

    // Opening a house

    @Test fun aTapOnTheWidgetOpensThatHouse() {
        assertEquals("houses://open/elm", HouseLink.url("elm"))
        assertEquals("elm", HouseLink.id("houses://open/elm"))
        assertNull(HouseLink.id("houses://open/"))
        assertNull(HouseLink.id("https://open/elm"))
        assertNull(HouseLink.id(null))
        assertEquals("houses://open/", HouseLink.url(null))
    }

    @Test fun theAppOpensTheHousesAppOnTheHouseTheWidgetAskedFor() {
        assertEquals("https://houses.elyir.app/?shell=android&store=US&open=elm", Shell.start(storefront = "USA", open = "elm"))
        assertEquals("https://houses.elyir.app/?shell=android&open=elm", Shell.start(storefront = null, open = "elm"))
        assertEquals("https://houses.elyir.app/?shell=android&store=US", Shell.start(storefront = "USA", open = null))
        assertEquals("https://houses.elyir.app/?shell=android&store=US", Shell.start(storefront = "USA", open = "a b"))
    }

    // Asking the house

    @Test fun itAsksTheHouseOnItsWiFiNameWhenThatAnswersElseItsOwnAddress() {
        assertEquals("https://192-168-1-53.maple-court.home.elyir.app", Base.choose(home, lanAnswered = true))
        assertEquals("https://maple-court.elyir.app", Base.choose(home, lanAnswered = false))
        assertEquals("https://elm.elyir.app", Base.choose(elm, lanAnswered = true))
        assertEquals("https://maple-court.elyir.app/glance", Base.url(Base.choose(home, lanAnswered = false), "glance"))
        assertEquals("https://maple-court.elyir.app/home/intent/asleep", Base.url(home.origin, HouseScene.asleep.path))
        assertEquals("https://maple-court.elyir.app/home/intent/away", Base.url(home.origin + "/", HouseScene.away.path))
        assertEquals(1_500, Base.LAN_WAIT_MILLIS)
    }

    @Test fun theGlanceReadsAsTheHouseSaysIt() {
        val g = Glance.parse("""{"name":"Maple Court","temp":null,"sky":null,"said":["On in 5 rooms"],"needs":null,"count":0,"at":1800000000}""")
        assertEquals(Glance(name = "Maple Court", said = listOf("On in 5 rooms"), at = now), g)
        assertEquals(now, Glance.parse("""{"said":[],"count":2,"needs":"x","at":1800000000000}""").at)
        assertEquals(glance(), Glance.from(glance().json()))
        assertEquals(Kept(glance(), now), Kept.parse(Kept(glance(), now).json()))
        assertEquals(Tap("elm", HouseScene.away, false, now), Tap.parse(Tap("elm", HouseScene.away, false, now).json()))
    }

    // Which house

    @Test fun aWidgetShowsItsPickedHouseElseTheLastOpenedElseTheFirst() {
        assertEquals("elm", Face.choose(listOf(home, elm), picked = "elm", opened = "maple-court")?.id)
        assertEquals("elm", Face.choose(listOf(home, elm), picked = null, opened = "elm")?.id)
        assertEquals("maple-court", Face.choose(listOf(home, elm), picked = "gone", opened = null)?.id)
        assertNull(Face.choose(emptyList(), picked = "elm", opened = "elm"))
    }

    // What it says

    @Test fun howTheHouseIs() {
        val f = Face.make(home, glance(), null, null, now)
        assertEquals("Home", f.name)
        assertEquals("78°", f.temp); assertEquals("partlycloudy", f.sky)
        assertEquals(listOf("On in 5 rooms", "2 people home"), f.lines)
        assertEquals("On in 5 rooms · 2 people home", f.line)
        assertEquals(Face.Tone.Plain, f.tone); assertNull(f.age); assertNull(f.said)
    }

    @Test fun whatNeedsALookIsSaidInTheLampInsteadOfTheHousesLine() {
        val one = Face.make(elm, glance(needs = "The back door lock needs a look", count = 1), null, null, now)
        assertEquals(listOf("The back door lock needs a look"), one.lines); assertEquals(Face.Tone.Needs, one.tone)
        val three = Face.make(elm, glance(needs = "The back door lock needs a look", count = 3), null, null, now)
        assertEquals(listOf("3 things need a look"), three.lines)
        val unnamed = Face.make(elm, glance(count = 1), null, null, now)
        assertEquals(listOf("Something needs a look"), unnamed.lines)
    }

    @Test fun aHouseThatDoesNotAnswerShowsItsLastGlanceAndHowOldItIs() {
        val f = Face.make(home, null, Kept(glance(), now), null, now + 5 * 60_000)
        assertEquals(listOf("On in 5 rooms", "2 people home"), f.lines)
        assertEquals("5 min ago", f.age)
    }

    @Test fun aHouseNeverReachedSaysSoUnderItsName() {
        val f = Face.make(elm, null, null, null, now)
        assertEquals("Elm Street", f.name); assertEquals(listOf("Can’t reach it right now"), f.lines)
        assertNull(f.temp); assertTrue(f.hasHouse)
    }

    @Test fun withNoHousesItSaysWhereToAddOne() {
        val f = Face.make(null, null, null, null, now)
        assertFalse(f.hasHouse); assertEquals(listOf("Open Houses to add your house."), f.lines)
    }

    @Test fun aTapIsAnsweredInThePanelsOwnWordsUntilTheNextRefresh() {
        val bed = Tap(home.id, HouseScene.asleep, true, now)
        assertEquals(Face.Said("Good night. The house is off.", false), Face.make(home, glance(), null, bed, now).said)
        val off = Tap(home.id, HouseScene.away, true, now)
        assertEquals("Everything is off.", Face.make(home, glance(), null, off, now + 60_000).said?.text)
        val failed = Tap(home.id, HouseScene.away, false, now)
        assertEquals(Face.Said("Couldn’t reach Home.", true), Face.make(home, null, null, failed, now).said)
        assertNull(Face.make(home, glance(), null, bed, now + Face.REFRESH_MILLIS).said)
        assertNull(Face.make(elm, glance(), null, bed, now).said)
    }

    @Test fun theButtonsAreTheRoutinesRowsWords() {
        assertEquals(listOf("Bedtime", "Everything off"), HouseScene.entries.map { it.title })
        assertEquals(15 * 60 * 1000L, Face.REFRESH_MILLIS)
    }

    @Test fun ageIsSaidPlainly() {
        assertEquals("Just now", Words.age(20))
        assertEquals("5 min ago", Words.age(5 * 60 + 10))
        assertEquals("1 hour ago", Words.age(65 * 60))
        assertEquals("5 hours ago", Words.age(5 * 3600))
        assertEquals("Yesterday", Words.age(30 * 3600))
        assertEquals("3 days ago", Words.age(3 * 86400))
        assertEquals("Just now", Words.age(-30))
    }

    @Test fun theWeatherIsOneOfAFewPictures() {
        assertEquals(Sky.Partly, Sky.of("partlycloudy"))
        assertEquals(Sky.Moon, Sky.of("clear-night"))
        assertEquals(Sky.Rain, Sky.of("pouring"))
        assertEquals(Sky.Storm, Sky.of("lightning-rainy"))
        assertNull(Sky.of(null)); assertNull(Sky.of("volcano"))
    }

    // Keeping the list

    @Test fun theListIsKeptSealedAndAHouseThatLeftTakesItsGlanceWithIt() {
        val shelf = object : Shelf {
            val map = mutableMapOf<String, String>()
            override fun get(key: String) = map[key]
            override fun set(key: String, value: String?) { if (value == null) map.remove(key) else map[key] = value }
        }
        val seal = object : Seal {
            override fun close(text: String) = text.reversed()
            override fun open(sealed: String) = sealed.reversed()
        }
        val store = HouseStore(shelf, seal)
        assertTrue(store.save(listOf(home, elm)))
        assertEquals(listOf(home, elm), store.houses())
        assertFalse(store.save(listOf(home, elm)))
        assertFalse("the pass is never kept as it is", shelf.map.values.any { "pass2" in it })

        store.keep(glance(), elm.id, now)
        store.keep(Tap(elm.id, HouseScene.away, true, now))
        store.opened = elm.id
        store.pick(7, elm.id)
        assertEquals(glance(), store.kept(elm.id)?.glance)
        assertEquals(elm, store.house(7))

        assertTrue(store.save(listOf(home)))
        assertEquals(listOf(home), store.houses())
        assertNull(store.kept(elm.id)); assertNull(store.tap(elm.id)); assertNull(store.opened)
        assertEquals("a widget set to a house that left shows the first", home, store.house(7))
    }
}
