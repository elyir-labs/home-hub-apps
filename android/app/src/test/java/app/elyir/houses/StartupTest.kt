// SPDX-License-Identifier: Apache-2.0
package app.elyir.houses

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File

/** The moments of J, as the wall's splash has them (startup/plymouth.mjs in the hub's repository); ios/HousesTests/StartupTests.swift's cases. */
class StartupTest {
    private val s = Sequence(File("src/main/assets/startup.json").readText())
    private val e = 0.001

    @Test fun theNumbersAreTheWallsOwn() {
        assertEquals(1440.0, s.SPACE.width, 0.0)
        assertEquals(6.2, s.TIME.readyAfter, e)
        assertEquals(6.4, s.BREATH.period, e)
    }

    @Test fun bothPhonesDrawFromTheSameNumbers() {
        assertEquals(File("../../ios/Houses/startup.json").readText(), File("src/main/assets/startup.json").readText())
    }

    @Test fun atTheFirstFrameNothingIsDrawnYet() {
        val f = Startup.frame(0.0, null, s)
        assertEquals(0.0, f.written, 0.0); assertEquals(0.0, f.house, 0.0); assertEquals(0.0, f.unlit, 0.0); assertEquals(0.0, f.lit, 0.0)
    }

    @Test fun theNameIsWrittenThenGoesAndTheDotLightsOnTheI() {
        val written = Startup.frame(s.TIME.write, null, s)
        assertEquals(1.0, written.written, 0.0); assertEquals(1.0, written.name, 0.0)
        assertEquals(s.NAME.tittle[0], written.dotX, 0.0); assertEquals(s.NAME.tittle[1], written.dotY, 0.0)
        assertTrue(Startup.frame(s.TIME.lit + 0.8, null, s).lit > 0.7)
        assertEquals(0.0, Startup.frame(s.TIME.hold + s.TIME.nameOut, null, s).name, 0.0)
    }

    @Test fun theDotLandsAsTheHousesLampAndTheHouseIsIn() {
        val f = Startup.frame(Startup.settled(s), null, s)
        assertEquals(s.HOUSE.lamp[0], f.dotX, e); assertEquals(s.HOUSE.lamp[1], f.dotY, e)
        assertEquals(s.HOUSE.lampSize, f.dotSize, e)
        assertEquals(1.0, f.house, e); assertEquals(0.0, f.dotGlow, e)
        assertTrue(f.houseGlow > 0)
    }

    @Test fun theLampBreathesOnceEverySixPointFourSeconds() {
        val a = Startup.frame(20.0, null, s).lit; val b = Startup.frame(20 + s.BREATH.period, null, s).lit
        assertEquals(a, b, 0.0001)
        val lows = generateSequence(10.0) { it + 0.05 }.takeWhile { it < 10 + s.BREATH.period }.map { Startup.frame(it, null, s).lit }
        assertEquals(s.BREATH.low, lows.min(), 0.01)
    }

    @Test fun theEndingOpensTheHouseOntoThePanel() {
        val at = 8.0
        val done = Startup.frame(at + s.TIME.ending, at, s)
        assertEquals(1.0, done.out, 0.0); assertEquals(0.0, done.house, 0.0); assertEquals(0.0, done.unlit, 0.0)
        assertEquals(1.18, done.houseScale, e)
    }

    @Test fun thePathReaderDrawsTheHouseInItsOwnSquare() {
        assertEquals(Bounds(112.0, 120.0, 288.0, 128.0), SvgPath.bounds(SvgPath.parse(s.HOUSE.roof)))
        assertEquals(Bounds(148.0, 226.0, 216.0, 170.0), SvgPath.bounds(SvgPath.parse(s.HOUSE.walls)))
        assertFalse(SvgPath.parse(s.NAME.d).isEmpty())
    }
}
