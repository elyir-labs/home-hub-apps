// SPDX-License-Identifier: Apache-2.0
import SwiftUI

/// The few SVG path commands the startup's marks use (M L H V C Z, absolute and relative), read into a Path.
enum SVGPath {
    static func path(_ d: String) -> Path {
        var path = Path()
        var tokens = tokenize(d)[...]
        var command: Character = "M"
        var at = CGPoint.zero, start = CGPoint.zero
        func number() -> CGFloat {
            if case .number(let n)? = tokens.first { tokens.removeFirst(); return n }
            return 0
        }
        while let token = tokens.first {
            if case .command(let c) = token { command = c; tokens.removeFirst() }
            let relative = command.isLowercase
            let base = relative ? at : .zero
            switch command.uppercased() {
            case "M":
                at = CGPoint(x: base.x + number(), y: base.y + number())
                path.move(to: at); start = at
                command = relative ? "l" : "L"   // further pairs after a move are lines
            case "L":
                at = CGPoint(x: base.x + number(), y: base.y + number()); path.addLine(to: at)
            case "H":
                at = CGPoint(x: (relative ? at.x : 0) + number(), y: at.y); path.addLine(to: at)
            case "V":
                at = CGPoint(x: at.x, y: (relative ? at.y : 0) + number()); path.addLine(to: at)
            case "C":
                let c1 = CGPoint(x: base.x + number(), y: base.y + number())
                let c2 = CGPoint(x: base.x + number(), y: base.y + number())
                at = CGPoint(x: base.x + number(), y: base.y + number())
                path.addCurve(to: at, control1: c1, control2: c2)
            case "Z":
                path.closeSubpath(); at = start
                if case .number? = tokens.first { tokens.removeFirst() }
            default:
                tokens.removeFirst()
            }
        }
        return path
    }

    private enum Token { case command(Character), number(CGFloat) }

    private static func tokenize(_ d: String) -> [Token] {
        var out: [Token] = [], current = ""
        func flush() { if let n = Double(current) { out.append(.number(n)) }; current = "" }
        for ch in d {
            if ch.isLetter, ch != "e" { flush(); out.append(.command(ch)) }
            else if ch == "-" && !current.isEmpty && current.last != "e" { flush(); current = "-" }
            else if ch == "," || ch.isWhitespace { flush() }
            else if ch == "." && current.contains(".") { flush(); current = "." }
            else { current.append(ch) }
        }
        flush()
        return out
    }
}
