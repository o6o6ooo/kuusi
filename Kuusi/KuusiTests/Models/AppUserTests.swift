import Testing
@testable import Kuusi

struct AppUserTests {
    @Test
    func initRequiresNameAndEmail() {
        let missingName = AppUser(id: "user-1", data: ["email": "sakura@example.com"])
        let missingEmail = AppUser(id: "user-1", data: ["name": "Sakura"])

        #expect(missingName == nil)
        #expect(missingEmail == nil)
    }

    @Test
    func initUsesDocumentValuesWhenPresent() {
        let user = AppUser(
            id: "user-1",
            data: [
                "name": "Sakura",
                "email": "sakura@example.com",
                "icon": "🌲",
                "bgColour": "#123456",
                "usage_mb": 42.5,
                "groups": ["group-a", "group-b"]
            ]
        )

        #expect(user?.id == "user-1")
        #expect(user?.name == "Sakura")
        #expect(user?.email == "sakura@example.com")
        #expect(user?.icon == "🌲")
        #expect(user?.bgColour == "#123456")
        #expect(user?.usageMB == 42.5)
        #expect(user?.groups == ["group-a", "group-b"])
    }

    @Test
    func initUsesDefaultsWhenOptionalFieldsAreMissing() {
        let user = AppUser(
            id: "user-1",
            data: [
                "name": "Sakura",
                "email": "sakura@example.com"
            ]
        )

        #expect(user?.icon == "🌸")
        #expect(user?.bgColour == "#A5C3DE")
        #expect(user?.usageMB == 0)
        #expect(user?.groups == [])
    }
}
