import Foundation

enum AppPlan: String {
    case free
    case premium

    init(rawPlan: String?) {
        self = AppPlan(rawValue: rawPlan ?? "") ?? .free
    }

    var quotaMB: Double {
        switch self {
        case .free:
            return 3072.0
        case .premium:
            return 51200.0
        }
    }

    var maxGroups: Int {
        switch self {
        case .free:
            return 3
        case .premium:
            return 10
        }
    }

    var title: String {
        switch self {
        case .free:
            return "Free plan"
        case .premium:
            return "Premium plan"
        }
    }

    var priceLabel: String? {
        switch self {
        case .free:
            return nil
        case .premium:
            return "£24.99 / year"
        }
    }

    var featureLines: [String] {
        switch self {
        case .free:
            return [
                "3GB storage",
                "Preview photos up to 2 years",
                "Have up to 3 groups"
            ]
        case .premium:
            return [
                "50GB storage",
                "Preview all photos",
                "Have up to 10 groups"
            ]
        }
    }
}
