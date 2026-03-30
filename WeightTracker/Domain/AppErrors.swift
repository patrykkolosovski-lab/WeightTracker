import Foundation

enum AppStateError: LocalizedError {
    case missingLocalAccountState

    var errorDescription: String? {
        switch self {
        case .missingLocalAccountState:
            return "Unable to restore your local BeFit data right now."
        }
    }
}

enum ValidationError: LocalizedError {
    case invalidAge
    case invalidHeight
    case invalidCurrentWeight
    case invalidTargetWeight
    case invalidTargetDate
    case targetWeightMatchesCurrentWeight
    case invalidWeightEntry
    case futureWeightEntryDate
    case duplicateWeightEntryDate

    var errorDescription: String? {
        switch self {
        case .invalidAge:
            return "Age must be between 13 and 120."
        case .invalidHeight:
            return "Height must be between 100 and 250 cm (39 and 98 in)."
        case .invalidCurrentWeight:
            return "Current weight must be between 25 and 400 kg (55 and 882 lb)."
        case .invalidTargetWeight:
            return "Target weight must be between 25 and 400 kg (55 and 882 lb)."
        case .invalidTargetDate:
            return "Target date must be at least tomorrow."
        case .targetWeightMatchesCurrentWeight:
            return "Target weight must be different from your current weight."
        case .invalidWeightEntry:
            return "Weight entries must be between 25 and 400 kg (55 and 882 lb)."
        case .futureWeightEntryDate:
            return "Future dates are not allowed. Please select today or an earlier date."
        case .duplicateWeightEntryDate:
            return "Only one weight entry is allowed per day. Edit the existing entry instead."
        }
    }
}
