// SPDX-License-Identifier: Apache-2.0
/*
 A house on the home screen (design/widget/ in the hub's repository, decided 20 October 2026): one widget, how the
 house is in the small size and the same with Bedtime and Everything off in the medium. It asks the house about every
 quarter of an hour, and a tap anywhere but a button opens that house in the app.
 */
import SwiftUI
import WidgetKit

@main
struct HousesWidgets: WidgetBundle {
    var body: some Widget { HouseWidget() }
}

struct HouseWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: HouseWidgetKind.kind, intent: PickHouse.self, provider: Provider()) { entry in
            HouseWidgetView(entry: entry)
        }
        .configurationDisplayName("Your house")
        .description("How the house is, and on the larger size Bedtime and Everything off.")
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()
    }
}

struct HouseWidgetView: View {
    let entry: Entry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        WidgetFace(face: entry.face, family: family)
            .widgetURL(HouseLink.url(entry.face.id))
            .containerBackground(for: .widget) { Night() }
    }
}

struct Entry: TimelineEntry {
    let date: Date
    let face: Face
}

struct Provider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> Entry {
        Entry(date: .now, face: .sample)
    }

    func snapshot(for configuration: PickHouse, in context: Context) async -> Entry {
        if context.isPreview {
            guard let house = Face.choose(HouseStore.houses(), picked: configuration.house?.id, opened: HouseStore.opened) else {
                return Entry(date: .now, face: .sample)
            }
            return Entry(date: .now, face: Face.make(house: house, fresh: HouseStore.kept(house.id)?.glance, kept: nil, tap: nil, now: .now))
        }
        return await entries(for: configuration).first!
    }

    func timeline(for configuration: PickHouse, in context: Context) async -> Timeline<Entry> {
        let now = Date.now
        return Timeline(entries: await entries(for: configuration, now: now), policy: .after(now.addingTimeInterval(Face.refresh)))
    }

    /// Now, and when a tap's words have had their time, the same glance without them.
    private func entries(for configuration: PickHouse, now: Date = .now) async -> [Entry] {
        let house = Face.choose(HouseStore.houses(), picked: configuration.house?.id, opened: HouseStore.opened)
        var fresh: Glance?
        if let house, let glance = try? await HouseClient.glance(house) {
            HouseStore.keep(glance, for: house.id, at: now)
            fresh = glance
        }
        let kept = house.flatMap { HouseStore.kept($0.id) }
        let tap = house.flatMap { HouseStore.tap($0.id) }
        let face = Face.make(house: house, fresh: fresh, kept: kept, tap: tap, now: now)
        guard face.said != nil, let tap else { return [Entry(date: now, face: face)] }
        var after = face
        after.said = nil
        return [Entry(date: now, face: face), Entry(date: tap.at.addingTimeInterval(Face.refresh), face: after)]
    }
}
