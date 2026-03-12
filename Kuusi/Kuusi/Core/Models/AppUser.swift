import Foundation
import FirebaseFirestore

struct AppUser: Identifiable {
    let id: String
    let name: String
    let email: String
    let icon: String
    let bgColour: String
    let plan: String
    let quotaMB: Double
    let usageMB: Double
    let groups: [String]
}

extension AppUser {
    init?(id: String, data: [String: Any]) {
        guard
            let name = data["name"] as? String,
            let email = data["email"] as? String
        else {
            return nil
        }

        self.id = id
        self.name = name
        self.email = email
        self.icon = (data["icon"] as? String) ?? "🌸"
        self.bgColour = (data["bgColour"] as? String) ?? "#A5C3DE"
        let premium = (data["premium"] as? Bool) ?? false
        let resolvedPlan = (data["plan"] as? String) ?? (premium ? "premium" : "free")
        let appPlan = AppPlan(rawPlan: resolvedPlan)
        let storedQuota = data["quota_mb"] as? Double

        self.plan = appPlan.rawValue
        if let storedQuota {
            if appPlan == .free, storedQuota == 5120.0 {
                self.quotaMB = appPlan.quotaMB
            } else {
                self.quotaMB = storedQuota
            }
        } else {
            self.quotaMB = appPlan.quotaMB
        }
        self.usageMB = (data["usage_mb"] as? Double) ?? ((data["upload_total_mb"] as? Double) ?? 0)
        self.groups = (data["groups"] as? [String]) ?? []
    }
}
