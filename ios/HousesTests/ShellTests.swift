// SPDX-License-Identifier: Apache-2.0
import XCTest
@testable import Houses

final class ShellTests: XCTestCase {
    func testOpensTheHousesAppSayingItIsTheIOSShellAndTheStorefront() {
        XCTAssertEqual(Shell.start(storefront: "USA").absoluteString, "https://houses.elyir.app/?shell=ios&store=US")
    }

    func testAStorefrontItCannotNameIsLeftOffSoThePageTreatsItAsNotTheUS() {
        XCTAssertEqual(Shell.start(storefront: "CAN").absoluteString, "https://houses.elyir.app/?shell=ios")
        XCTAssertEqual(Shell.start(storefront: nil).absoluteString, "https://houses.elyir.app/?shell=ios")
        XCTAssertEqual(Shell.start(storefront: "gb").absoluteString, "https://houses.elyir.app/?shell=ios&store=GB")
    }

    func testTheHousesAppAndEveryHouseInsideItStay() {
        XCTAssertFalse(Shell.opensOutside(URL(string: "https://houses.elyir.app/add")!, mainFrame: true))
        XCTAssertFalse(Shell.opensOutside(URL(string: "https://maple-court.elyir.app/?app=1")!, mainFrame: false))
        XCTAssertFalse(Shell.opensOutside(URL(string: "https://192-168-1-53.maple-court.home.elyir.app/?app=1")!, mainFrame: false))
        XCTAssertFalse(Shell.opensOutside(URL(string: "https://hub.elyir.com/try/?app=1&shell=ios")!, mainFrame: false))
        XCTAssertFalse(Shell.opensOutside(URL(string: "about:blank")!, mainFrame: false))
    }

    func testPayingAndEveryOtherPageLeaveForTheBrowser() {
        XCTAssertTrue(Shell.opensOutside(URL(string: "https://pay.example/start?house=jordan")!, mainFrame: true))
        XCTAssertTrue(Shell.opensOutside(URL(string: "https://github.com/elyir-labs/home-hub/blob/main/relay/README.md")!, mainFrame: true))
        XCTAssertTrue(Shell.opensOutside(URL(string: "https://maple-court.elyir.app/")!, mainFrame: true))
        XCTAssertTrue(Shell.opensOutside(URL(string: "mailto:hello@elyir.com")!, mainFrame: false))
    }

    func testADevServerIsHomeWhenTheSimulatorIsPointedAtOne() {
        let dev = URL(string: "http://localhost:5174/")!
        XCTAssertFalse(Shell.opensOutside(URL(string: "http://localhost:5174/add")!, mainFrame: true, home: dev))
        XCTAssertTrue(Shell.opensOutside(URL(string: "http://localhost:8399/")!, mainFrame: true, home: dev))
        XCTAssertEqual(Shell.start(at: dev, storefront: "USA").absoluteString, "http://localhost:5174/?shell=ios&store=US")
    }
}
