import Foundation

enum AppPlan: String {
    case free
    case premium

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
            return "Free"
        case .premium:
            return "Premium"
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

    var productID: String? {
        switch self {
        case .free:
            return nil
        case .premium:
            return "com.swallace.kuusi.premium.annual"
        }
    }

    var featureLines: [String] {
        switch self {
        case .free:
            return [
                "3GB storage",
                "2 years photo preview",
                "Up to 3 groups"
            ]
        case .premium:
            return [
                "50GB storage",
                "All photo preview",
                "Up to 10 groups"
            ]
        }
    }
}
