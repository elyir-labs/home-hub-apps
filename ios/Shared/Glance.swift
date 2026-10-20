// SPDX-License-Identifier: Apache-2.0
/*
 What the widget says (design/widget/ in the hub's repository, A as the small size and C as the medium, decided
 20 October 2026), kept free of WidgetKit and the network so every case can be tested on its own: the houses the
 Houses app hands over, how a house answers /glance, which house a widget shows, and the words for each moment.
 */
import Foundation

/// One house as the Houses app keeps it. `token` is this phone's pass for the house.
struct HouseRecord: Codable, Equatable, Identifiable {
    let id: String
    let name: String
    let origin: URL
    let lan: String?
    let token: String
}

/// How a house answers `GET /glance`.
struct Glance: Codable, Equatable {
    var name: String?
    var temp: String?
    var sky: String?
    var said: [String]
    var needs: String?
    var count: Int
    var at: Date?

    enum CodingKeys: String, CodingKey { case name, temp, sky, said, needs, count, at }

    init(name: String? = nil, temp: String? = nil, sky: String? = nil, said: [String] = [], needs: String? = nil, count: Int = 0, at: Date? = nil) {
        self.name = name; self.temp = temp; self.sky = sky; self.said = said; self.needs = needs; self.count = count; self.at = at
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = try c.decodeIfPresent(String.self, forKey: .name)
        temp = try c.decodeIfPresent(String.self, forKey: .temp)
        sky = try c.decodeIfPresent(String.self, forKey: .sky)
        said = try c.decodeIfPresent([String].self, forKey: .said) ?? []
        needs = try c.decodeIfPresent(String.self, forKey: .needs)
        count = try c.decodeIfPresent(Int.self, forKey: .count) ?? 0
        // The house says seconds; a value that can only be milliseconds is read as such.
        at = try c.decodeIfPresent(Double.self, forKey: .at).map { Date(timeIntervalSince1970: $0 > 1e11 ? $0 / 1000 : $0) }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encodeIfPresent(name, forKey: .name)
        try c.encodeIfPresent(temp, forKey: .temp)
        try c.encodeIfPresent(sky, forKey: .sky)
        try c.encode(said, forKey: .said)
        try c.encodeIfPresent(needs, forKey: .needs)
        try c.encode(count, forKey: .count)
        try c.encodeIfPresent(at?.timeIntervalSince1970, forKey: .at)
    }
}

/// The last glance a house gave, and when this phone got it.
struct Kept: Codable, Equatable {
    let glance: Glance
    let got: Date
}

/// The two things people say to a whole house, as the panel's routines row has them.
enum HouseScene: String, Codable, CaseIterable, Sendable {
    case asleep, away

    var title: String { self == .asleep ? "Bedtime" : "Everything off" }
    /// The panel's own words once it has run.
    var done: String { self == .asleep ? "Good night. The house is off." : "Everything is off." }
    var path: String { "home/intent/\(rawValue)" }
}

/// A tap on one of the medium widget's two buttons, kept until the refresh after it.
struct Tap: Codable, Equatable {
    let id: String
    let scene: HouseScene
    let ok: Bool
    let at: Date
}

/// What the Houses app tells the shell: its list, the house it opened, and its asks about notifications.
enum HousesMessage: Equatable {
    case list([HouseRecord])
    case opened(String)
    case pushIdentity
    case pushOff

    static func parse(_ body: Any) -> HousesMessage? {
        guard let body = body as? [String: Any], let type = body["type"] as? String else { return nil }
        switch type {
        case "houses:list":
            guard let rows = body["houses"] as? [[String: Any]] else { return nil }
            return .list(rows.compactMap(record))
        case "houses:opened":
            guard let id = body["id"] as? String, HouseLink.isID(id) else { return nil }
            return .opened(id)
        case "houses:push-identity":
            return .pushIdentity
        case "houses:push-off":
            return .pushOff
        default:
            return nil
        }
    }

    private static func record(_ row: [String: Any]) -> HouseRecord? {
        guard let id = row["id"] as? String, HouseLink.isID(id),
              let name = row["name"] as? String,
              let origin = (row["origin"] as? String).flatMap(URL.init(string:)),
              let scheme = origin.scheme?.lowercased(), scheme == "https" || scheme == "http", origin.host != nil,
              let token = row["token"] as? String, !token.isEmpty
        else { return nil }
        let lan = (row["lan"] as? String).flatMap { $0.isEmpty ? nil : $0 }
        return HouseRecord(id: id, name: name, origin: origin, lan: lan, token: token)
    }
}

/// `houses://open/<id>`: what a tap on the widget opens.
enum HouseLink {
    static func url(_ id: String?) -> URL {
        URL(string: "houses://open/" + (id.flatMap { isID($0) ? $0 : nil } ?? ""))!
    }

    static func id(_ url: URL) -> String? {
        guard url.scheme?.lowercased() == "houses", url.host?.lowercased() == "open" else { return nil }
        let id = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return isID(id) ? id : nil
    }

    /// A house's id is its label in the zone (`jordan` of jordan.elyir.app).
    static func isID(_ s: String) -> Bool {
        !s.isEmpty && s.count <= 63 && s.allSatisfy { $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" || $0 == ".") }
    }
}

/// Where to ask a house: its Wi-Fi name if that answers within a second and a half, else its own address. The same
/// rule as the Houses app's `reach()`.
enum Base {
    static let lanWait: TimeInterval = 1.5

    static func lan(_ house: HouseRecord) -> URL? {
        house.lan.flatMap { URL(string: "https://\($0)") }
    }

    static func choose(_ house: HouseRecord, lanAnswered: Bool) -> URL {
        lanAnswered ? (lan(house) ?? house.origin) : house.origin
    }

    static func url(_ base: URL, _ path: String) -> URL {
        base.appending(path: path)
    }
}

/// Everything a widget draws, worked out before any view sees it.
struct Face: Equatable {
    enum Tone: Equatable { case plain, needs }
    /// What a tap on Bedtime or Everything off came to, until the next refresh.
    struct Said: Equatable { let text: String; let failed: Bool }

    var id: String?
    var name: String
    var temp: String?
    var sky: String?
    var lines: [String]
    var tone: Tone = .plain
    var age: String?
    var said: Said?

    var hasHouse: Bool { id != nil }
    /// The medium size has one line beside the house; the small one gives each its own.
    var line: String { lines.joined(separator: " · ") }

    static let refresh: TimeInterval = 15 * 60

    static let noHouses = Face(id: nil, name: "", lines: [Words.noHouses])

    static let sample = Face(id: "home", name: "Home", temp: "78°", sky: "partlycloudy", lines: ["On in 5 rooms", "2 people home"])

    /// The house a widget shows: the one picked for it, else the one last opened, else the first.
    static func choose(_ houses: [HouseRecord], picked: String?, opened: String?) -> HouseRecord? {
        houses.first { $0.id == picked } ?? houses.first { $0.id == opened } ?? houses.first
    }

    static func make(house: HouseRecord?, fresh: Glance?, kept: Kept?, tap: Tap?, now: Date) -> Face {
        guard let house else { return .noHouses }
        var face: Face
        if let glance = fresh ?? kept?.glance {
            face = Face(id: house.id, name: name(house, glance), temp: glance.temp, sky: glance.sky, lines: Words.lines(glance))
            face.tone = Words.needs(glance) == nil ? .plain : .needs
            if fresh == nil, let kept { face.age = Words.age(now.timeIntervalSince(kept.glance.at ?? kept.got)) }
        } else {
            face = Face(id: house.id, name: house.name, lines: [Words.unreachable])
        }
        if let tap, tap.id == house.id, showsTap(tap, now: now) {
            face.said = Said(text: tap.ok ? tap.scene.done : Words.couldNotReach(face.name), failed: !tap.ok)
        }
        return face
    }

    static func showsTap(_ tap: Tap, now: Date) -> Bool {
        let since = now.timeIntervalSince(tap.at)
        return since >= -60 && since < refresh
    }

    private static func name(_ house: HouseRecord, _ glance: Glance) -> String {
        house.name.isEmpty ? (glance.name ?? house.id) : house.name
    }
}

enum Words {
    static let noHouses = "Open Houses to add your house."
    static let unreachable = "Can’t reach it right now"

    static func couldNotReach(_ name: String) -> String { "Couldn’t reach \(name)." }

    /// The same line Houses says for a house: what needs somebody, else what the house says of itself.
    static func needs(_ g: Glance) -> String? {
        if g.count > 1 { return "\(g.count) things need a look" }
        if g.count == 1 || g.needs != nil { return g.needs.flatMap { $0.isEmpty ? nil : $0 } ?? "Something needs a look" }
        return nil
    }

    static func lines(_ g: Glance) -> [String] {
        needs(g).map { [$0] } ?? Array(g.said.filter { !$0.isEmpty }.prefix(2))
    }

    static func age(_ seconds: TimeInterval) -> String {
        let s = max(0, Int(seconds))
        switch s {
        case ..<60: return "Just now"
        case ..<3600: return "\(s / 60) min ago"
        case ..<7200: return "1 hour ago"
        case ..<86400: return "\(s / 3600) hours ago"
        case ..<172_800: return "Yesterday"
        default: return "\(s / 86400) days ago"
        }
    }
}

/// The house's weather as one of the few small pictures the widget draws, from the panel's sky keys (app/src/sky.ts).
enum Sky: Equatable {
    case sun, moon, partly, cloud, rain, snow, storm, fog

    static func of(_ key: String?) -> Sky? {
        switch key {
        case "sunny": return .sun
        case "clear-night": return .moon
        case "partlycloudy": return .partly
        case "cloudy", "windy", "windy-variant", "exceptional": return .cloud
        case "rainy", "pouring", "hail": return .rain
        case "snowy", "snowy-rainy": return .snow
        case "lightning", "lightning-rainy": return .storm
        case "fog": return .fog
        default: return nil
        }
    }
}
