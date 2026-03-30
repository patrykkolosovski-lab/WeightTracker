import Foundation

enum RootDestination {
    case loading
    case metricsOnboarding
    case main
}

enum AppTab: String, CaseIterable, Identifiable {
    case home = "Home"
    case graph = "Graph"
    case metrics = "Metrics"
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

enum GoalMode: String, CaseIterable, Identifiable {
    case target
    case generic

    var id: String { rawValue }

    var title: String {
        switch self {
        case .target:
            return "Target"
        case .generic:
            return "Generic"
        }
    }
}

enum WeeklyPaceOption: String, CaseIterable, Identifiable {
    case quarter = "0.25 kg/w"
    case half = "0.5 kg/w"
    case threeQuarter = "0.75 kg/w"
    case one = "1.0 kg/w"

    var id: String { rawValue }

    var kilogramsPerWeek: Double {
        switch self {
        case .quarter:
            return 0.25
        case .half:
            return 0.5
        case .threeQuarter:
            return 0.75
        case .one:
            return 1.0
        }
    }

    static func from(kilogramsPerWeek: Double?) -> WeeklyPaceOption {
        guard let kilogramsPerWeek else { return .half }
        return allCases.min(by: {
            abs($0.kilogramsPerWeek - kilogramsPerWeek) < abs($1.kilogramsPerWeek - kilogramsPerWeek)
        }) ?? .half
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

enum WeightEntrySource: String, Codable {
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
    let goalMode: GoalMode
    let genericGoalType: GoalType
    let weeklyPaceKilograms: Double?
    let targetDate: Date?
    let formulaSex: FormulaSex
    let unitSystem: UnitSystem
}

struct GoalConfiguration {
    let mode: GoalMode
    let genericGoalType: GoalType
    let weeklyPaceKilograms: Double?
    let targetWeightKilograms: Double
    let targetDate: Date?
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
