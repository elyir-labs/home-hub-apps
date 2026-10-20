// SPDX-License-Identifier: Apache-2.0
import SwiftUI
import WidgetKit
import XCTest
@testable import Houses

/// Pictures of the widget in each moment, to hold against the boards (design/widget/GlanceA and ScenesC). Runs only
/// when asked: `TEST_RUNNER_WIDGET_SHOTS=<folder>` on xcodebuild, and `TEST_RUNNER_WIDGET_HOME=<board's shots/home.png>`
/// to also place them on the boards' home screen at the boards' own positions.
@MainActor
final class WidgetPictures: XCTestCase {
    let at = Date(timeIntervalSince1970: 1_800_000_000)

    func testDrawEachMoment() throws {
        guard let out = ProcessInfo.processInfo.environment["WIDGET_SHOTS"].map(URL.init(fileURLWithPath:)) else {
            throw XCTSkip("WIDGET_SHOTS is not set")
        }
        try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)

        let home = HouseRecord(id: "home", name: "Home", origin: URL(string: "https://home.elyir.app")!, lan: nil, token: "t")
        let elm = HouseRecord(id: "elm", name: "Elm Street", origin: URL(string: "https://elm.elyir.app")!, lan: nil, token: "t")
        let normal = Glance(temp: "78°", sky: "partlycloudy", said: ["On in 5 rooms", "2 people home"], at: at)
        let needs = Glance(temp: "58°", said: ["On in 2 rooms"], needs: "The back door lock needs a look", count: 1, at: at)
        let faces: [String: Face] = [
            "normal": Face.make(house: home, fresh: normal, kept: nil, tap: nil, now: at),
            "needs": Face.make(house: elm, fresh: needs, kept: nil, tap: nil, now: at),
            "kept": Face.make(house: home, fresh: nil, kept: Kept(glance: normal, got: at), tap: nil, now: at + 5 * 60),
            "unreachable": Face.make(house: elm, fresh: nil, kept: nil, tap: nil, now: at),
            "none": Face.make(house: nil, fresh: nil, kept: nil, tap: nil, now: at),
            "bedtime": Face.make(house: home, fresh: normal, kept: nil, tap: Tap(id: "home", scene: .asleep, ok: true, at: at), now: at),
            "off": Face.make(house: home, fresh: normal, kept: nil, tap: Tap(id: "home", scene: .away, ok: true, at: at), now: at),
            "tap-failed": Face.make(house: home, fresh: nil, kept: Kept(glance: normal, got: at), tap: Tap(id: "home", scene: .away, ok: false, at: at), now: at),
        ]
        for (name, face) in faces {
            try save(widget(face, .systemSmall), out.appending(path: "small-\(name).png"))
            try save(widget(face, .systemMedium), out.appending(path: "medium-\(name).png"))
        }

        if let shot = ProcessInfo.processInfo.environment["WIDGET_HOME"], let wallpaper = UIImage(contentsOfFile: shot) {
            try save(screen(wallpaper, [(faces["normal"]!, .systemSmall, 24), (faces["needs"]!, .systemSmall, 202)]), out.appending(path: "board-A.png"))
            try save(screen(wallpaper, [(faces["normal"]!, .systemMedium, 24)]), out.appending(path: "board-C.png"))
            try save(screen(wallpaper, [(faces["bedtime"]!, .systemMedium, 24)]), out.appending(path: "board-C-after-bedtime.png"))
        }
    }

    /// The boards draw a small one 164 points square and a medium one 342 by 164, with the system's 22-point corners.
    private func widget(_ face: Face, _ family: WidgetFamily) -> some View {
        WidgetFace(face: face, family: family)
            .frame(width: family == .systemMedium ? 342 : 164, height: 164)
            .background(Night())
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func screen(_ wallpaper: UIImage, _ widgets: [(Face, WidgetFamily, CGFloat)]) -> some View {
        ZStack(alignment: .topLeading) {
            Image(uiImage: wallpaper).resizable().frame(width: 390, height: 844)
            ForEach(Array(widgets.enumerated()), id: \.offset) { _, w in
                self.widget(w.0, w.1)
                    .shadow(color: .black.opacity(0.35), radius: 15, y: 10)
                    .offset(x: w.2, y: 288)
                Text("Houses").font(.system(size: 12)).foregroundStyle(.white).shadow(color: .black.opacity(0.4), radius: 1, y: 1)
                    .frame(width: w.1 == .systemMedium ? 342 : 164)
                    .offset(x: w.2, y: 458)
            }
        }
        .frame(width: 390, height: 844, alignment: .topLeading)
    }

    private func save(_ view: some View, _ url: URL) throws {
        let renderer = ImageRenderer(content: view.environment(\.colorScheme, .dark))
        renderer.scale = 3
        let png = try XCTUnwrap(renderer.uiImage?.pngData())
        try png.write(to: url)
    }
}
