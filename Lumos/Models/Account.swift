import Foundation
import AppKit

struct Account: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var colorHex: String

    init(id: UUID = UUID(), name: String, colorHex: String = Account.randomColorHex()) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
    }

    var color: NSColor {
        NSColor(hex: colorHex) ?? .systemBlue
    }

    static func randomColorHex() -> String {
        let colors = ["#0066FF", "#FF3B30", "#34C759", "#FF9500", "#AF52DE", "#FF2D55", "#5AC8FA", "#FFCC00"]
        return colors.randomElement() ?? "#0066FF"
    }
}

extension NSColor {
    convenience init?(hex: String) {
        var hex = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if hex.hasPrefix("#") { hex.removeFirst() }
        guard hex.count == 6, let value = UInt32(hex, radix: 16) else { return nil }
        let r = CGFloat((value >> 16) & 0xFF) / 255
        let g = CGFloat((value >> 8) & 0xFF) / 255
        let b = CGFloat(value & 0xFF) / 255
        self.init(red: r, green: g, blue: b, alpha: 1)
    }
}
