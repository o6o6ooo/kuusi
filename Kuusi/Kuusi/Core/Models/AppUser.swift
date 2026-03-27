import Foundation
import FirebaseFirestore

struct AppUser: Identifiable {
    let id: String
    let name: String
    let email: String
    let icon: String
    let bgColour: String
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
        self.usageMB = (data["usage_mb"] as? Double) ?? ((data["upload_total_mb"] as? Double) ?? 0)
        self.groups = (data["groups"] as? [String]) ?? []
    }
}
