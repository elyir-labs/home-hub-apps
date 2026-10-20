// SPDX-License-Identifier: Apache-2.0
import XCTest
@testable import Houses

/// What the widget says for each moment (design/widget/, A small and C medium), and the contract with the Houses app
/// and the house that it is built on.
final class WidgetTests: XCTestCase {
    let home = HouseRecord(id: "maple-court", name: "Home", origin: URL(string: "https://maple-court.elyir.app")!,
                           lan: "192-168-1-53.maple-court.home.elyir.app", token: "pass")
    let elm = HouseRecord(id: "elm", name: "Elm Street", origin: URL(string: "https://elm.elyir.app")!, lan: nil, token: "pass2")
    let now = Date(timeIntervalSince1970: 1_800_000_000)

    func glance(_ said: [String] = ["On in 5 rooms", "2 people home"], needs: String? = nil, count: Int = 0) -> Glance {
        Glance(name: "Maple Court", temp: "78°", sky: "partlycloudy", said: said, needs: needs, count: count, at: now)
    }

    // MARK: the Houses app's messages

    func testTheListArrivesWithEachHousesPass() {
        let body: [String: Any] = ["type": "houses:list", "houses": [
            ["id": "maple-court", "name": "Home", "origin": "https://maple-court.elyir.app", "lan": "192-168-1-53.maple-court.home.elyir.app", "token": "pass"],
            ["id": "elm", "name": "Elm Street", "origin": "https://elm.elyir.app", "lan": NSNull(), "token": "pass2"],
        ]]
        XCTAssertEqual(HousesMessage.parse(body), .list([home, elm]))
    }

    func testAHouseWithoutAPassOrAnAddressIsLeftOut() {
        let body: [String: Any] = ["type": "houses:list", "houses": [
            ["id": "a", "name": "A", "origin": "https://a.elyir.app", "token": ""],
            ["id": "b", "name": "B", "origin": "javascript:alert(1)", "token": "t"],
            ["id": "../c", "name": "C", "origin": "https://c.elyir.app", "token": "t"],
            ["id": "d", "name": "D", "origin": "https://d.elyir.app", "lan": "", "token": "t"],
        ]]
        XCTAssertEqual(HousesMessage.parse(body), .list([HouseRecord(id: "d", name: "D", origin: URL(string: "https://d.elyir.app")!, lan: nil, token: "t")]))
    }

    func testTheHouseOpenedIsSaidByItsID() {
        XCTAssertEqual(HousesMessage.parse(["type": "houses:opened", "id": "elm"]), .opened("elm"))
        XCTAssertNil(HousesMessage.parse(["type": "houses:opened", "id": "elm/../x"]))
        XCTAssertNil(HousesMessage.parse(["type": "something-else"]))
        XCTAssertNil(HousesMessage.parse("houses:list"))
    }

    func testOnlyTheHousesAppsOwnPageIsBelieved() {
        XCTAssertTrue(Shell.trusts(mainFrame: true, host: "houses.elyir.app"))
        XCTAssertFalse(Shell.trusts(mainFrame: false, host: "houses.elyir.app"))
        XCTAssertFalse(Shell.trusts(mainFrame: true, host: "maple-court.elyir.app"))
        XCTAssertFalse(Shell.trusts(mainFrame: true, host: nil))
        XCTAssertTrue(Shell.trusts(mainFrame: true, host: "localhost", home: URL(string: "http://localhost:5178/")!))
    }

    // MARK: opening a house

    func testATapOnTheWidgetOpensThatHouse() {
        XCTAssertEqual(HouseLink.url("elm").absoluteString, "houses://open/elm")
        XCTAssertEqual(HouseLink.id(URL(string: "houses://open/elm")!), "elm")
        XCTAssertNil(HouseLink.id(URL(string: "houses://open/")!))
        XCTAssertNil(HouseLink.id(URL(string: "https://open/elm")!))
        XCTAssertEqual(HouseLink.url(nil).absoluteString, "houses://open/")
    }

    func testTheAppOpensTheHousesAppOnTheHouseTheWidgetAskedFor() {
        XCTAssertEqual(Shell.start(storefront: "USA", open: "elm").absoluteString, "https://houses.elyir.app/?shell=ios&store=US&open=elm")
        XCTAssertEqual(Shell.start(storefront: nil, open: "elm").absoluteString, "https://houses.elyir.app/?shell=ios&open=elm")
        XCTAssertEqual(Shell.start(storefront: "USA", open: nil).absoluteString, "https://houses.elyir.app/?shell=ios&store=US")
        XCTAssertEqual(Shell.start(storefront: "USA", open: "a b").absoluteString, "https://houses.elyir.app/?shell=ios&store=US")
    }

    // MARK: asking the house

    func testItAsksTheHouseOnItsWiFiNameWhenThatAnswersElseItsOwnAddress() {
        XCTAssertEqual(Base.choose(home, lanAnswered: true).absoluteString, "https://192-168-1-53.maple-court.home.elyir.app")
        XCTAssertEqual(Base.choose(home, lanAnswered: false).absoluteString, "https://maple-court.elyir.app")
        XCTAssertEqual(Base.choose(elm, lanAnswered: true).absoluteString, "https://elm.elyir.app")
        XCTAssertEqual(Base.url(Base.choose(home, lanAnswered: false), "glance").absoluteString, "https://maple-court.elyir.app/glance")
        XCTAssertEqual(Base.url(home.origin, HouseScene.asleep.path).absoluteString, "https://maple-court.elyir.app/home/intent/asleep")
        XCTAssertEqual(Base.url(home.origin, HouseScene.away.path).absoluteString, "https://maple-court.elyir.app/home/intent/away")
        XCTAssertEqual(Base.lanWait, 1.5)
    }

    func testTheGlanceReadsAsTheHouseSaysIt() throws {
        let json = #"{"name":"Maple Court","temp":null,"sky":null,"said":["On in 5 rooms"],"needs":null,"count":0,"at":1800000000}"#
        let g = try JSONDecoder().decode(Glance.self, from: Data(json.utf8))
        XCTAssertEqual(g, Glance(name: "Maple Court", said: ["On in 5 rooms"], at: now))
        let ms = try JSONDecoder().decode(Glance.self, from: Data(#"{"said":[],"count":2,"needs":"x","at":1800000000000}"#.utf8))
        XCTAssertEqual(ms.at, now)
        let kept = try JSONDecoder().decode(Glance.self, from: JSONEncoder().encode(glance()))
        XCTAssertEqual(kept, glance())
    }

    // MARK: which house

    func testAWidgetShowsItsPickedHouseElseTheLastOpenedElseTheFirst() {
        XCTAssertEqual(Face.choose([home, elm], picked: "elm", opened: "maple-court")?.id, "elm")
        XCTAssertEqual(Face.choose([home, elm], picked: nil, opened: "elm")?.id, "elm")
        XCTAssertEqual(Face.choose([home, elm], picked: "gone", opened: nil)?.id, "maple-court")
        XCTAssertNil(Face.choose([], picked: "elm", opened: "elm"))
    }

    // MARK: what it says

    func testHowTheHouseIs() {
        let f = Face.make(house: home, fresh: glance(), kept: nil, tap: nil, now: now)
        XCTAssertEqual(f.name, "Home")
        XCTAssertEqual(f.temp, "78°"); XCTAssertEqual(f.sky, "partlycloudy")
        XCTAssertEqual(f.lines, ["On in 5 rooms", "2 people home"])
        XCTAssertEqual(f.line, "On in 5 rooms · 2 people home")
        XCTAssertEqual(f.tone, .plain); XCTAssertNil(f.age); XCTAssertNil(f.said)
    }

    func testWhatNeedsALookIsSaidInTheLampInsteadOfTheHousesLine() {
        let one = Face.make(house: elm, fresh: glance(needs: "The back door lock needs a look", count: 1), kept: nil, tap: nil, now: now)
        XCTAssertEqual(one.lines, ["The back door lock needs a look"]); XCTAssertEqual(one.tone, .needs)
        let three = Face.make(house: elm, fresh: glance(needs: "The back door lock needs a look", count: 3), kept: nil, tap: nil, now: now)
        XCTAssertEqual(three.lines, ["3 things need a look"])
        let unnamed = Face.make(house: elm, fresh: glance(count: 1), kept: nil, tap: nil, now: now)
        XCTAssertEqual(unnamed.lines, ["Something needs a look"])
    }

    func testAHouseThatDoesNotAnswerShowsItsLastGlanceAndHowOldItIs() {
        let kept = Kept(glance: glance(), got: now)
        let f = Face.make(house: home, fresh: nil, kept: kept, tap: nil, now: now.addingTimeInterval(5 * 60))
        XCTAssertEqual(f.lines, ["On in 5 rooms", "2 people home"])
        XCTAssertEqual(f.age, "5 min ago")
    }

    func testAHouseNeverReachedSaysSoUnderItsName() {
        let f = Face.make(house: elm, fresh: nil, kept: nil, tap: nil, now: now)
        XCTAssertEqual(f.name, "Elm Street"); XCTAssertEqual(f.lines, ["Can’t reach it right now"])
        XCTAssertNil(f.temp); XCTAssertTrue(f.hasHouse)
    }

    func testWithNoHousesItSaysWhereToAddOne() {
        let f = Face.make(house: nil, fresh: nil, kept: nil, tap: nil, now: now)
        XCTAssertFalse(f.hasHouse); XCTAssertEqual(f.lines, ["Open Houses to add your house."])
    }

    func testATapIsAnsweredInThePanelsOwnWordsUntilTheNextRefresh() {
        let bed = Tap(id: home.id, scene: .asleep, ok: true, at: now)
        XCTAssertEqual(Face.make(house: home, fresh: glance(), kept: nil, tap: bed, now: now).said, .init(text: "Good night. The house is off.", failed: false))
        let off = Tap(id: home.id, scene: .away, ok: true, at: now)
        XCTAssertEqual(Face.make(house: home, fresh: glance(), kept: nil, tap: off, now: now.addingTimeInterval(60)).said?.text, "Everything is off.")
        let failed = Tap(id: home.id, scene: .away, ok: false, at: now)
        XCTAssertEqual(Face.make(house: home, fresh: nil, kept: nil, tap: failed, now: now).said, .init(text: "Couldn’t reach Home.", failed: true))
        XCTAssertNil(Face.make(house: home, fresh: glance(), kept: nil, tap: bed, now: now.addingTimeInterval(Face.refresh)).said)
        XCTAssertNil(Face.make(house: elm, fresh: glance(), kept: nil, tap: bed, now: now).said)
    }

    func testTheButtonsAreTheRoutinesRowsWords() {
        XCTAssertEqual(HouseScene.allCases.map(\.title), ["Bedtime", "Everything off"])
        XCTAssertEqual(Face.refresh, 15 * 60)
    }

    func testAgeIsSaidPlainly() {
        XCTAssertEqual(Words.age(20), "Just now")
        XCTAssertEqual(Words.age(5 * 60 + 10), "5 min ago")
        XCTAssertEqual(Words.age(65 * 60), "1 hour ago")
        XCTAssertEqual(Words.age(5 * 3600), "5 hours ago")
        XCTAssertEqual(Words.age(30 * 3600), "Yesterday")
        XCTAssertEqual(Words.age(3 * 86400), "3 days ago")
        XCTAssertEqual(Words.age(-30), "Just now")
    }

    func testTheWeatherIsOneOfAFewPictures() {
        XCTAssertEqual(Sky.of("partlycloudy"), .partly)
        XCTAssertEqual(Sky.of("clear-night"), .moon)
        XCTAssertEqual(Sky.of("pouring"), .rain)
        XCTAssertEqual(Sky.of("lightning-rainy"), .storm)
        XCTAssertNil(Sky.of(nil)); XCTAssertNil(Sky.of("volcano"))
    }

    // MARK: keeping the list

    func testTheListIsKeptInTheSharedKeychainGroupAndAHouseThatLeftTakesItsGlanceWithIt() throws {
        let group = try XCTUnwrap(Keychain.group)
        XCTAssertTrue(group.hasSuffix("app.elyir.houses.shared"), group)
        Keychain.clear()
        defer { Keychain.clear() }
        XCTAssertTrue(HouseStore.save([home, elm]))
        XCTAssertEqual(HouseStore.houses(), [home, elm])
        XCTAssertFalse(HouseStore.save([home, elm]))

        HouseStore.keep(glance(), for: elm.id, at: now)
        HouseStore.keep(Tap(id: elm.id, scene: .away, ok: true, at: now))
        HouseStore.opened = elm.id
        XCTAssertEqual(HouseStore.kept(elm.id)?.glance, glance())

        XCTAssertTrue(HouseStore.save([home]))
        XCTAssertEqual(HouseStore.houses(), [home])
        XCTAssertNil(HouseStore.kept(elm.id)); XCTAssertNil(HouseStore.tap(elm.id)); XCTAssertNil(HouseStore.opened)
    }
}
