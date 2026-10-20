// SPDX-License-Identifier: Apache-2.0
/*
 How the app starts (design/boot/ in the hub's repository, J, and the app's half decided 19 October 2026): elyir
 written by hand, the dot of the i lighting like a lamp and gliding into the house, then breathing there until the
 Houses app is ready. All of it the first time the app opens; the house breathing on every start after.

 The numbers are the wall's own (startup.json, copied by tools/startup.sh from the hub's startup/sequence.json), and
 `Startup.frame` is the boot splash's refresh() in startup/plymouth.mjs, line for line, so the two stay one picture.
 */
import SwiftUI

struct Sequence: Decodable {
    struct Space: Decodable { let width, height: Double }
    struct Colors: Decodable { let ink: String; let lamp, unlit, panel: [Double] }
    struct Name: Decodable { let d: String; let viewBox: [Double]; let scale, stroke, left, top, tittleSize: Double; let tittle: [Double] }
    struct House: Decodable { let roof, walls: String; let stroke, size, left, top, lampSize: Double; let lamp: [Double] }
    struct Time: Decodable { let write, dotted, lit, hold, nameOut, leave, houseIn, land, ending, readyAfter: Double }
    struct Breath: Decodable { let period, low: Double }
    let SPACE: Space, COLOR: Colors, NAME: Name, HOUSE: House, TIME: Time, BREATH: Breath

    static let shipped: Sequence = {
        let url = Bundle.main.url(forResource: "startup", withExtension: "json")!
        return try! JSONDecoder().decode(Sequence.self, from: Data(contentsOf: url))
    }()
}

enum Startup {
    /// One moment, in the boards' space (1440x900). Opacities are 0...1.
    struct Frame: Equatable {
        var written = 0.0, name = 0.0
        var house = 0.0, houseScale = 1.0
        var dot = CGPoint.zero, dotSize = 0.0
        var unlit = 0.0, lit = 0.0, dotGlow = 0.0
        var houseGlow = 0.0, houseGlowSize = 0.0
        var out = 0.0
    }

    static func clamp01(_ v: Double) -> Double { min(max(v, 0), 1) }
    static func ramp(_ t: Double, _ a: Double, _ b: Double) -> Double { clamp01((t - a) / (b - a)) }
    static func ease(_ x: Double) -> Double { x * x * (3 - 2 * x) }
    static func breath(_ t: Double, _ period: Double) -> Double { 0.5 + 0.5 * sin(t / period * 2 * .pi - .pi / 2) }

    /// `t` seconds into J; `endingAt` once the app is ready and the ending has begun.
    static func frame(_ t: Double, endingAt: Double?, _ s: Sequence = .shipped) -> Frame {
        let T = s.TIME, N = s.NAME, H = s.HOUSE
        var f = Frame()
        f.out = endingAt.map { ease(ramp(t, $0, $0 + T.ending)) } ?? 0
        f.written = ease(clamp01(t / T.write))
        f.name = 1 - ease(ramp(t, T.hold, T.hold + T.nameOut))

        let inn = ease(ramp(t, T.houseIn - 0.2, T.houseIn + 0.8))
        f.houseScale = (0.96 + 0.04 * inn) * (1 + 0.18 * f.out)
        f.house = inn * (1 - f.out)

        let appear = ease(ramp(t, T.dotted, T.dotted + 0.3)) * (1 - f.out)
        var k = ease(ramp(t, T.lit, T.lit + 0.8)) * (s.BREATH.low + (1 - s.BREATH.low) * breath(t, s.BREATH.period))
        if endingAt != nil { k = 1 }
        let move = ease(ramp(t, T.leave, T.land))
        let cx = H.left + H.size / 2, cy = H.top + H.size / 2
        let x = N.tittle[0] + (H.lamp[0] - N.tittle[0]) * move
        let y = N.tittle[1] + (H.lamp[1] - N.tittle[1]) * move
        f.dot = CGPoint(x: cx + (x - cx) * (1 + 0.18 * f.out), y: cy + (y - cy) * (1 + 0.18 * f.out))
        f.dotSize = (N.tittleSize + (H.lampSize - N.tittleSize) * move) * (1 + 0.18 * f.out)
        f.unlit = appear
        f.lit = appear * k

        let landed = ramp(t, T.land, T.land + 0.6)
        f.dotGlow = appear * k * (1 - landed)
        f.houseGlow = k * landed * inn * (1 - f.out)
        f.houseGlowSize = H.size * 1.1 * (1 + 3 * f.out)
        return f
    }

    /// Where a start that has seen J before begins: the house in, the dot landed, the lamp lit.
    static func settled(_ s: Sequence = .shipped) -> Double { s.TIME.land + 0.6 }
}

/// J over whatever is behind it, until it has opened onto it. `ready` is the Houses app's first page; `unreachable`
/// brings up the one sentence.
struct StartupView: View {
    let full: Bool
    let ready: Bool
    let unreachable: Bool
    let done: () -> Void

    @State private var began = Date()
    @State private var endingAt: Double?
    private let s = Sequence.shipped

    var body: some View {
        TimelineView(.animation) { timeline in
            let elapsed = timeline.date.timeIntervalSince(began)
            let t = full ? elapsed : Startup.settled(s) + elapsed
            let f = Startup.frame(t, endingAt: endingAt, s)
            let fadeIn = full ? 1 : Startup.ease(Startup.clamp01(elapsed / 0.3))
            GeometryReader { geo in
                let k = min(geo.size.width / s.SPACE.width, geo.size.height / s.SPACE.height)
                let ox = (geo.size.width - s.SPACE.width * k) / 2, oy = (geo.size.height - s.SPACE.height * k) / 2
                ZStack {
                    Color(rgb: s.COLOR.panel).opacity(f.out)
                    Canvas { ctx, _ in draw(f, in: &ctx, k: k, ox: ox, oy: oy) }
                        .opacity(fadeIn)
                    if unreachable && !ready {
                        Text("Can’t reach your houses right now. Check that this phone is online.")
                            .font(.system(size: 15))
                            .foregroundStyle(Color(red: 0xb9 / 255, green: 0xb5 / 255, blue: 0xad / 255))
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 300)
                            .position(x: geo.size.width / 2, y: oy + (s.HOUSE.top + s.HOUSE.size) * k + 40)
                            .transition(.opacity)
                    }
                }
            }
            .onChange(of: t >= s.TIME.readyAfter && ready) { _, go in
                if go && endingAt == nil { endingAt = t }
            }
            .onChange(of: endingAt.map { t >= $0 + s.TIME.ending } ?? false) { _, over in
                if over { done() }
            }
        }
        .background(Color.black)
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 0.4), value: unreachable)
    }

    private func draw(_ f: Startup.Frame, in ctx: inout GraphicsContext, k: Double, ox: Double, oy: Double) {
        let N = s.NAME, H = s.HOUSE, C = s.COLOR
        let at = { (x: Double, y: Double) in CGPoint(x: ox + x * k, y: oy + y * k) }
        let round = { (w: Double) in StrokeStyle(lineWidth: w, lineCap: .round, lineJoin: .round) }

        if f.name > 0 && f.written > 0 {
            let place = CGAffineTransform(translationX: -N.viewBox[0], y: -N.viewBox[1])
                .concatenating(CGAffineTransform(scaleX: N.scale * k, y: N.scale * k))
                .concatenating(CGAffineTransform(translationX: ox + N.left * k, y: oy + N.top * k))
            let name = SVGPath.path(N.d).trimmedPath(from: 0, to: f.written).applying(place)
            ctx.stroke(name, with: .color(Color(hex: C.ink).opacity(f.name)), style: round(N.stroke * N.scale * k))
        }

        let center = at(H.left + H.size / 2, H.top + H.size / 2)
        if f.houseGlow > 0 {
            let r = f.houseGlowSize * k / 2, d = at(f.dot.x, f.dot.y)
            ctx.fill(Path(ellipseIn: CGRect(x: d.x - r, y: d.y - r, width: 2 * r, height: 2 * r)), with: .radialGradient(
                Gradient(stops: [.init(color: Color(rgb: C.lamp, f.houseGlow * 0.55), location: 0), .init(color: Color(rgb: C.lamp, 0), location: 0.68)]),
                center: d, startRadius: 0, endRadius: r))
        }
        if f.house > 0 {
            let size = H.size * f.houseScale * k
            let place = CGAffineTransform(scaleX: size / 512, y: size / 512)
                .concatenating(CGAffineTransform(translationX: center.x - size / 2, y: center.y - size / 2))
            let ink = GraphicsContext.Shading.color(Color(hex: C.ink).opacity(f.house))
            ctx.stroke(SVGPath.path(H.roof).applying(place), with: ink, style: round(H.stroke * size / 512))
            ctx.stroke(SVGPath.path(H.walls).applying(place), with: ink, style: round(H.stroke * size / 512))
        }
        if f.unlit > 0 {
            let d = at(f.dot.x, f.dot.y), r = f.dotSize * k / 2
            if f.dotGlow > 0 {
                let g = r * (32 + 180) / 32
                ctx.fill(Path(ellipseIn: CGRect(x: d.x - g, y: d.y - g, width: 2 * g, height: 2 * g)), with: .radialGradient(
                    Gradient(stops: [.init(color: Color(rgb: C.lamp, f.dotGlow * 0.45), location: 0), .init(color: Color(rgb: C.lamp, 0), location: 1)]),
                    center: d, startRadius: r, endRadius: g))
            }
            let disc = Path(ellipseIn: CGRect(x: d.x - r, y: d.y - r, width: 2 * r, height: 2 * r))
            ctx.fill(disc, with: .color(Color(rgb: C.unlit, f.unlit)))
            ctx.fill(disc, with: .color(Color(rgb: C.lamp, f.lit)))
        }
    }
}

extension Color {
    init(rgb c: [Double], _ alpha: Double = 1) { self.init(.sRGB, red: c[0] / 255, green: c[1] / 255, blue: c[2] / 255, opacity: alpha) }
    init(hex: String) {
        let v = Int(hex.dropFirst(), radix: 16) ?? 0
        self.init(rgb: [Double((v >> 16) & 255), Double((v >> 8) & 255), Double(v & 255)])
    }
}
