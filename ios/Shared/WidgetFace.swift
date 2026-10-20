// SPDX-License-Identifier: Apache-2.0
/*
 The widget as the boards draw it (design/widget/GlanceA and ScenesC): the app icon's night with the lamp's glow at
 its foot, the house in ink with its lamp lit, the weather, the house's name and its line, and on the medium size
 Bedtime and Everything off. In the app target too, so a test can render it to a picture.
 */
import AppIntents
import SwiftUI
import WidgetKit

enum Ink {
    static let ink = Color(red: 0xf1 / 255, green: 0xee / 255, blue: 0xe8 / 255)
    static let muted = Color(red: 0xb9 / 255, green: 0xb5 / 255, blue: 0xad / 255)
    static let caption = Color(red: 0x8d / 255, green: 0x8a / 255, blue: 0x84 / 255)
    static let lamp = Color(red: 0xe9 / 255, green: 0xb8 / 255, blue: 0x72 / 255)
    static let top = Color(red: 0x1a / 255, green: 0x1d / 255, blue: 0x24 / 255)
    static let bottom = Color(red: 0x0c / 255, green: 0x0d / 255, blue: 0x10 / 255)
}

struct WidgetFace: View {
    let face: Face
    let family: WidgetFamily

    var body: some View {
        Group {
            if family == .systemMedium { medium } else { small }
        }
        .foregroundStyle(Ink.ink)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var small: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center) {
                HouseMark().frame(width: 26, height: 26)
                Spacer(minLength: 4)
                weather
            }
            if face.hasHouse {
                Text(face.name).font(.system(size: 17, weight: .medium)).lineLimit(1).padding(.top, 22)
                Text(face.lines.joined(separator: "\n"))
                    .font(.system(size: 13)).lineSpacing(1.5).lineLimit(face.age == nil ? 3 : 2)
                    .foregroundStyle(face.tone == .needs ? Ink.lamp : Ink.muted)
                    .padding(.top, 4)
                age
            } else {
                Text(Words.noHouses).font(.system(size: 13)).lineSpacing(1.5).foregroundStyle(Ink.muted).padding(.top, 22)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
    }

    private var medium: some View {
        ZStack(alignment: .bottom) {
            HStack(alignment: .top, spacing: 12) {
                HouseMark().frame(width: 28, height: 28).padding(.top, 5)
                VStack(alignment: .leading, spacing: 0) {
                    if face.hasHouse {
                        Text(face.name).font(.system(size: 17, weight: .medium)).lineLimit(1)
                        if let said = face.said {
                            Text(said.text).font(.system(size: 13)).lineLimit(2)
                                .foregroundStyle(said.failed ? Ink.lamp : Ink.ink)
                        } else {
                            Text(face.line).font(.system(size: 13)).lineLimit(2)
                                .foregroundStyle(face.tone == .needs ? Ink.lamp : Ink.muted)
                            age
                        }
                    } else {
                        Text(Words.noHouses).font(.system(size: 13)).foregroundStyle(Ink.muted).padding(.top, 9)
                    }
                }
                Spacer(minLength: 4)
                weather
            }
            .frame(maxHeight: .infinity, alignment: .top)
            if let id = face.id {
                HStack(spacing: 10) {
                    ForEach(HouseScene.allCases, id: \.self) { scene in
                        Button(intent: RunScene(house: id, scene: scene)) {
                            Text(scene.title).font(.system(size: 13, weight: .medium))
                                .frame(maxWidth: .infinity).frame(height: 44)
                                .background(Capsule().fill(.white.opacity(0.1)))
                                .overlay(Capsule().strokeBorder(.white.opacity(0.14), lineWidth: 1))
                                .contentShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(EdgeInsets(top: 16, leading: 16, bottom: 14, trailing: 16))
    }

    @ViewBuilder private var weather: some View {
        if let temp = face.temp {
            HStack(spacing: 4) {
                if let sky = Sky.of(face.sky) { SkyMark(sky: sky).frame(width: 22, height: 16) }
                Text(temp).font(.system(size: 13))
            }
        }
    }

    @ViewBuilder private var age: some View {
        if let age = face.age {
            Text(age).font(.system(size: 11)).foregroundStyle(Ink.caption).padding(.top, 4)
        }
    }
}

/// The app icon's night: its gradient, and the lamp's glow rising from the foot.
struct Night: View {
    var body: some View {
        Canvas { ctx, size in
            ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .linearGradient(
                Gradient(colors: [Ink.top, Ink.bottom]), startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)))
            var glow = ctx
            glow.translateBy(x: size.width / 2, y: size.height)
            glow.scaleBy(x: 0.7 * size.width, y: 0.6 * size.height)
            glow.fill(Path(ellipseIn: CGRect(x: -1, y: -1, width: 2, height: 2)), with: .radialGradient(
                Gradient(stops: [.init(color: Ink.lamp.opacity(0.18), location: 0), .init(color: Ink.lamp.opacity(0), location: 0.7)]),
                center: .zero, startRadius: 0, endRadius: 1))
        }
    }
}

/// The hub's house in ink, its lamp lit (app/public/icon.svg).
struct HouseMark: View {
    var body: some View {
        Canvas { ctx, size in
            let k = min(size.width, size.height) / 512
            var house = Path()
            house.move(to: CGPoint(x: 112, y: 248)); house.addLine(to: CGPoint(x: 256, y: 120)); house.addLine(to: CGPoint(x: 400, y: 248))
            house.move(to: CGPoint(x: 148, y: 226)); house.addLine(to: CGPoint(x: 148, y: 396))
            house.addLine(to: CGPoint(x: 364, y: 396)); house.addLine(to: CGPoint(x: 364, y: 226))
            let place = CGAffineTransform(scaleX: k, y: k)
            ctx.stroke(house.applying(place), with: .color(Ink.ink), style: StrokeStyle(lineWidth: 34 * k, lineCap: .round, lineJoin: .round))
            ctx.fill(Path(ellipseIn: CGRect(x: 226, y: 276, width: 60, height: 60)).applying(place), with: .color(Ink.lamp))
        }
    }
}

/// The weather, small, in the board's 210x150 box.
struct SkyMark: View {
    let sky: Sky

    var body: some View {
        Canvas { ctx, size in
            ctx.scaleBy(x: size.width / 210, y: size.height / 150)
            let cloud = { (c: inout GraphicsContext, dy: CGFloat) in
                c.fill(ellipse(72, 96 + dy, 56, 36), with: .color(.init(red: 238 / 255, green: 240 / 255, blue: 246 / 255, opacity: 0.9)))
                c.fill(ellipse(118, 84 + dy, 44, 34), with: .color(.init(red: 0.886, green: 0.902, blue: 0.941, opacity: 0.92)))
                c.fill(ellipse(96, 108 + dy, 72, 24), with: .color(.init(red: 0.808, green: 0.831, blue: 0.886, opacity: 0.85)))
            }
            let sun = Color(red: 0xf0 / 255, green: 0xd6 / 255, blue: 0xa0 / 255)
            switch sky {
            case .sun:
                ctx.fill(ellipse(105, 75, 46, 46), with: .color(sun))
            case .moon:
                let moon = ellipse(105, 75, 46, 46).subtracting(ellipse(128, 58, 40, 40))
                ctx.fill(moon, with: .color(.init(red: 0.886, green: 0.902, blue: 0.941, opacity: 0.92)))
            case .partly:
                ctx.fill(ellipse(150, 44, 30, 30), with: .color(.init(red: 214 / 255, green: 206 / 255, blue: 186 / 255, opacity: 0.62)))
                cloud(&ctx, 0)
            case .cloud:
                cloud(&ctx, -10)
            case .rain, .snow, .storm:
                cloud(&ctx, -22)
                if sky == .storm {
                    var bolt = Path()
                    bolt.addLines([CGPoint(x: 112, y: 104), CGPoint(x: 90, y: 134), CGPoint(x: 108, y: 134), CGPoint(x: 96, y: 150)])
                    ctx.stroke(bolt, with: .color(Ink.lamp), style: StrokeStyle(lineWidth: 10, lineCap: .round, lineJoin: .round))
                } else {
                    for x in [70.0, 105, 140] {
                        if sky == .rain {
                            var drop = Path(); drop.move(to: CGPoint(x: x + 6, y: 116)); drop.addLine(to: CGPoint(x: x - 4, y: 142))
                            ctx.stroke(drop, with: .color(.init(red: 0.62, green: 0.75, blue: 0.92, opacity: 0.9)), style: StrokeStyle(lineWidth: 9, lineCap: .round))
                        } else {
                            ctx.fill(ellipse(x, 130, 9, 9), with: .color(.white.opacity(0.9)))
                        }
                    }
                }
            case .fog:
                for (i, y) in [50.0, 80, 110].enumerated() {
                    var line = Path(); line.move(to: CGPoint(x: 30 + Double(i % 2) * 20, y: y)); line.addLine(to: CGPoint(x: 170 + Double(i % 2) * 10, y: y))
                    ctx.stroke(line, with: .color(.white.opacity(0.75)), style: StrokeStyle(lineWidth: 14, lineCap: .round))
                }
            }
        }
    }

    private func ellipse(_ cx: CGFloat, _ cy: CGFloat, _ rx: CGFloat, _ ry: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: cx - rx, y: cy - ry, width: 2 * rx, height: 2 * ry))
    }
}
