import Foundation

enum AuthScreenMode {
    case register
    case login
}

enum RootDestination {
    case loading
    case auth(AuthScreenMode)
    case metricsOnboarding
    case main
}

enum AppTab: String, CaseIterable, Identifiable {
    case home = "Home"
    case graph = "Graph"
    case metrics = "Body Metrics"
    case settings = "Settings"

    var id: String { rawValue }

    var iconName: String {
        switch self {
        case .home:
            return "house.fill"
        case .graph:
            return "chart.line.uptrend.xyaxis"
        case .metrics:
            return "figure.stand"
        case .settings:
            return "gearshape.fill"
        }
    }
}

enum UnitSystem: String, CaseIterable, Identifiable {
    case metric
    case imperial

    var id: String { rawValue }

    var weightUnit: String {
        switch self {
        case .metric:
            return "kg"
        case .imperial:
            return "lb"
        }
    }

    var heightUnit: String {
        switch self {
        case .metric:
            return "cm"
        case .imperial:
            return "in"
        }
    }
}

enum GoalType: String, CaseIterable, Identifiable {
    case loss
    case gain
    case maintenance

    var id: String { rawValue }

    var title: String {
        switch self {
        case .loss:
            return "Loss"
        case .gain:
            return "Gain"
        case .maintenance:
            return "Maintenance"
        }
    }
}

enum ActivityLevel: String, CaseIterable, Identifiable {
    case sedentary
    case light
    case moderate
    case veryActive
    case extraActive

    var id: String { rawValue }

    var title: String {
        switch self {
        case .sedentary:
            return "Sedentary"
        case .light:
            return "Light"
        case .moderate:
            return "Moderate"
        case .veryActive:
            return "Very Active"
        case .extraActive:
            return "Extra Active"
        }
    }

    var multiplier: Double {
        switch self {
        case .sedentary:
            return 1.2
        case .light:
            return 1.375
        case .moderate:
            return 1.55
        case .veryActive:
            return 1.725
        case .extraActive:
            return 1.9
        }
    }
}

enum FormulaSex: String, CaseIterable, Identifiable {
    case female
    case male

    var id: String { rawValue }

    var title: String {
        rawValue.capitalized
    }
}

enum WeightEntrySource: String {
    case onboarding
    case manual
    case metricsAdjustment
}

enum GraphTimeframe: String, CaseIterable, Identifiable {
    case week = "1W"
    case month = "1M"
    case threeMonths = "3M"
    case sixMonths = "6M"
    case year = "1Y"
    case all = "All"

    var id: String { rawValue }

    func startDate(relativeTo currentDate: Date = .now) -> Date? {
        let calendar = Calendar.current
        switch self {
        case .week:
            return calendar.date(byAdding: .day, value: -7, to: currentDate)
        case .month:
            return calendar.date(byAdding: .month, value: -1, to: currentDate)
        case .threeMonths:
            return calendar.date(byAdding: .month, value: -3, to: currentDate)
        case .sixMonths:
            return calendar.date(byAdding: .month, value: -6, to: currentDate)
        case .year:
            return calendar.date(byAdding: .year, value: -1, to: currentDate)
        case .all:
            return nil
        }
    }
}

struct MetricsInput {
    let age: Int
    let heightCentimeters: Double
    let currentWeightKilograms: Double
    let targetWeightKilograms: Double
    let activityLevel: ActivityLevel
    let goalType: GoalType
    let formulaSex: FormulaSex
    let unitSystem: UnitSystem
}

struct WeightEntryDraft {
    let date: Date
    let weightKilograms: Double
    let notes: String
    let source: WeightEntrySource
}

enum UnitConverter {
    static func weightToDisplay(_ kilograms: Double, unitSystem: UnitSystem) -> Double {
        switch unitSystem {
        case .metric:
            return kilograms
        case .imperial:
            return kilograms * 2.2046226218
        }
    }

    static func weightToKilograms(_ displayValue: Double, unitSystem: UnitSystem) -> Double {
        switch unitSystem {
        case .metric:
            return displayValue
        case .imperial:
            return displayValue / 2.2046226218
        }
    }

    static func heightToDisplay(_ centimeters: Double, unitSystem: UnitSystem) -> Double {
        switch unitSystem {
        case .metric:
            return centimeters
        case .imperial:
            return centimeters / 2.54
        }
    }

    static func heightToCentimeters(_ displayValue: Double, unitSystem: UnitSystem) -> Double {
        switch unitSystem {
        case .metric:
            return displayValue
        case .imperial:
            return displayValue * 2.54
        }
    }
}
