import CoreGraphics

/// Parses the subset of SVG path data used by the built-in art: M L H V Q C Z, absolute and relative.
enum SVGPath {
    static func parse(_ d: String) -> CGPath {
        let path = CGMutablePath()
        var tokens = Tokens(Array(d.utf8))
        var command: UInt8 = 0
        var current = CGPoint.zero, start = CGPoint.zero

        while true {
            if let next = tokens.peekCommand() {
                tokens.skipCommand()
                command = next
            } else if command == 0 || !tokens.hasNumber {
                break
            }
            let relative = command >= 97
            func point() -> CGPoint {
                let x = tokens.number(), y = tokens.number()
                return relative ? CGPoint(x: current.x + x, y: current.y + y) : CGPoint(x: x, y: y)
            }
            switch command | 0x20 {
            case UInt8(ascii: "m"):
                current = point(); start = current
                path.move(to: current)
                command = relative ? UInt8(ascii: "l") : UInt8(ascii: "L")
            case UInt8(ascii: "l"):
                current = point(); path.addLine(to: current)
            case UInt8(ascii: "h"):
                let x = tokens.number(); current.x = relative ? current.x + x : x; path.addLine(to: current)
            case UInt8(ascii: "v"):
                let y = tokens.number(); current.y = relative ? current.y + y : y; path.addLine(to: current)
            case UInt8(ascii: "q"):
                let c = point(), p = point(); path.addQuadCurve(to: p, control: c); current = p
            case UInt8(ascii: "c"):
                let c1 = point(), c2 = point(), p = point()
                path.addCurve(to: p, control1: c1, control2: c2); current = p
            case UInt8(ascii: "z"):
                path.closeSubpath(); current = start; command = 0
            default:
                return path
            }
        }
        return path
    }

    private struct Tokens {
        let bytes: [UInt8]
        var i = 0
        init(_ bytes: [UInt8]) { self.bytes = bytes }

        mutating func skipSeparators() {
            while i < bytes.count, bytes[i] == 32 || bytes[i] == 44 || bytes[i] == 10 || bytes[i] == 9 { i += 1 }
        }

        mutating func peekCommand() -> UInt8? {
            skipSeparators()
            guard i < bytes.count else { return nil }
            let b = bytes[i] | 0x20
            return (b >= 97 && b <= 122 && b != 101) ? bytes[i] : nil
        }

        mutating func skipCommand() { i += 1 }

        var hasNumber: Bool {
            mutating get {
                skipSeparators()
                guard i < bytes.count else { return false }
                let b = bytes[i]
                return (b >= 48 && b <= 57) || b == 45 || b == 46 || b == 43
            }
        }

        mutating func number() -> CGFloat {
            skipSeparators()
            let begin = i
            if i < bytes.count, bytes[i] == 45 || bytes[i] == 43 { i += 1 }
            var seenDot = false
            while i < bytes.count {
                let b = bytes[i]
                if b >= 48 && b <= 57 { i += 1 } else if b == 46 && !seenDot { seenDot = true; i += 1 } else { break }
            }
            return CGFloat(Double(String(decoding: bytes[begin..<i], as: UTF8.self)) ?? 0)
        }
    }
}
