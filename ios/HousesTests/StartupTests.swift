// SPDX-License-Identifier: Apache-2.0
import SwiftUI
import XCTest
@testable import Houses

/// The moments of J, as the wall's splash has them (startup/plymouth.mjs in the hub's repository).
final class StartupTests: XCTestCase {
    let s = Sequence.shipped

    func testTheNumbersAreTheWallsOwn() {
        XCTAssertEqual(s.SPACE.width, 1440)
        XCTAssertEqual(s.TIME.readyAfter, 6.2, accuracy: 0.001)
        XCTAssertEqual(s.BREATH.period, 6.4, accuracy: 0.001)
    }

    func testAtTheFirstFrameNothingIsDrawnYet() {
        let f = Startup.frame(0, endingAt: nil, s)
        XCTAssertEqual(f.written, 0); XCTAssertEqual(f.house, 0); XCTAssertEqual(f.unlit, 0); XCTAssertEqual(f.lit, 0)
    }

    func testTheNameIsWrittenThenGoesAndTheDotLightsOnTheI() {
        let written = Startup.frame(s.TIME.write, endingAt: nil, s)
        XCTAssertEqual(written.written, 1); XCTAssertEqual(written.name, 1)
        XCTAssertEqual(written.dot, CGPoint(x: s.NAME.tittle[0], y: s.NAME.tittle[1]))
        XCTAssertGreaterThan(Startup.frame(s.TIME.lit + 0.8, endingAt: nil, s).lit, 0.7)
        XCTAssertEqual(Startup.frame(s.TIME.hold + s.TIME.nameOut, endingAt: nil, s).name, 0)
    }

    func testTheDotLandsAsTheHousesLampAndTheHouseIsIn() {
        let f = Startup.frame(Startup.settled(s), endingAt: nil, s)
        XCTAssertEqual(f.dot.x, s.HOUSE.lamp[0], accuracy: 0.001); XCTAssertEqual(f.dot.y, s.HOUSE.lamp[1], accuracy: 0.001)
        XCTAssertEqual(f.dotSize, s.HOUSE.lampSize, accuracy: 0.001)
        XCTAssertEqual(f.house, 1, accuracy: 0.001); XCTAssertEqual(f.dotGlow, 0, accuracy: 0.001)
        XCTAssertGreaterThan(f.houseGlow, 0)
    }

    func testTheLampBreathesOnceEverySixPointFourSeconds() {
        let a = Startup.frame(20, endingAt: nil, s).lit, b = Startup.frame(20 + s.BREATH.period, endingAt: nil, s).lit
        XCTAssertEqual(a, b, accuracy: 0.0001)
        let lows = stride(from: 10.0, to: 10 + s.BREATH.period, by: 0.05).map { Startup.frame($0, endingAt: nil, s).lit }
        XCTAssertEqual(lows.min()!, s.BREATH.low, accuracy: 0.01)
    }

    func testTheEndingOpensTheHouseOntoThePanel() {
        let at = 8.0
        let done = Startup.frame(at + s.TIME.ending, endingAt: at, s)
        XCTAssertEqual(done.out, 1); XCTAssertEqual(done.house, 0); XCTAssertEqual(done.unlit, 0)
        XCTAssertEqual(done.houseScale, 1.18, accuracy: 0.001)
    }

    func testThePathReaderDrawsTheHouseInItsOwnSquare() {
        let roof = SVGPath.path(s.HOUSE.roof).boundingRect, walls = SVGPath.path(s.HOUSE.walls).boundingRect
        XCTAssertEqual(roof, CGRect(x: 112, y: 120, width: 288, height: 128))
        XCTAssertEqual(walls, CGRect(x: 148, y: 226, width: 216, height: 170))
        XCTAssertFalse(SVGPath.path(s.NAME.d).isEmpty)
    }
}
