import SwiftUI

enum BeFitTheme {
    static let backgroundTop = Color(hex: "000035")
    static let backgroundMiddle = Color(hex: "000042")
    static let backgroundBottom = Color(hex: "000068")
    static let surface = Color(hex: "000053")
    static let elevatedSurface = Color(hex: "1C1C84")
    static let divider = Color.white.opacity(0.08)
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.68)
    static let heart = Color(red: 1.0, green: 0.54, blue: 0.64)
    static let warning = Color.orange
    static let success = Color.green
    static let danger = Color.red.opacity(0.88)

    static let backgroundGradient = LinearGradient(
        colors: [backgroundTop, backgroundMiddle, backgroundBottom],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

enum Formatters {
    static let weightDisplay: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = 1
        formatter.maximumFractionDigits = 1
        return formatter
    }()

    static let compactDecimal: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 1
        return formatter
    }()

    static let integer: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.maximumFractionDigits = 0
        return formatter
    }()

    static let date: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter
    }()

    static func decimalInput(_ value: Double) -> String {
        compactDecimal.string(from: NSNumber(value: value)) ?? String(format: "%.1f", value)
    }
}

extension Color {
    init(hex: String) {
        let sanitized = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: sanitized).scanHexInt64(&value)

        let red = Double((value >> 16) & 0xFF) / 255
        let green = Double((value >> 8) & 0xFF) / 255
        let blue = Double(value & 0xFF) / 255

        self.init(red: red, green: green, blue: blue)
    }
}
