// SPDX-License-Identifier: Apache-2.0
/*
 The widget's two App Intents: which house it shows, picked when it is added, and Bedtime or Everything off, run from
 the medium size without opening anything.
 */
import AppIntents
import WidgetKit

enum HouseWidgetKind {
    static let kind = "house"
}

struct HouseEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "House"
    static var defaultQuery = HouseQuery()

    let id: String
    let name: String

    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(name)") }

    init(_ house: HouseRecord) { id = house.id; name = house.name }
}

struct HouseQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [HouseEntity] {
        HouseStore.houses().filter { identifiers.contains($0.id) }.map(HouseEntity.init)
    }

    func suggestedEntities() async throws -> [HouseEntity] {
        HouseStore.houses().map(HouseEntity.init)
    }

    func defaultResult() async -> HouseEntity? {
        Face.choose(HouseStore.houses(), picked: nil, opened: HouseStore.opened).map(HouseEntity.init)
    }
}

struct PickHouse: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "House"
    static var description = IntentDescription("Which house this shows.")

    @Parameter(title: "House")
    var house: HouseEntity?
}

extension HouseScene: AppEnum {
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Routine"
    static var caseDisplayRepresentations: [HouseScene: DisplayRepresentation] = [
        .asleep: "Bedtime",
        .away: "Everything off",
    ]
}

struct RunScene: AppIntent {
    static var title: LocalizedStringResource = "Bedtime or Everything off"
    static var isDiscoverable = false

    @Parameter(title: "House")
    var house: String

    @Parameter(title: "Routine")
    var scene: HouseScene

    init() {}

    init(house: String, scene: HouseScene) {
        self.house = house
        self.scene = scene
    }

    func perform() async throws -> some IntentResult {
        var ok = false
        if let record = HouseStore.houses().first(where: { $0.id == house }) {
            ok = await HouseClient.run(scene, in: record)
        }
        HouseStore.keep(Tap(id: house, scene: scene, ok: ok, at: .now))
        WidgetCenter.shared.reloadTimelines(ofKind: HouseWidgetKind.kind)
        return .result()
    }
}
