import FirebaseAuth
import Foundation
import PhotosUI
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.colorScheme) private var colorScheme
    @State private var name = ""
    @State private var icon = "🌸"
    @State private var bgColour = "#A5C3DE"
    @State private var message: String?
    @State private var isError = false
    @State private var hasLoaded = false
    @State private var isEmojiPickerPresented = false
    @State private var clearMessageTask: Task<Void, Never>?
    @State private var usageMB: Double = 0
    @State private var quotaMB: Double = 5120
    @State private var plan = "free"
    @State private var isEditingName = false

    @State private var createGroupName = ""
    @State private var selectedGroupID: String?
    @State private var editableGroupName = ""
    @State private var groups: [GroupSummary] = []
    @State private var createStatusMessage: String?
    @State private var isCreateError = false
    @State private var saveStatusMessage: String?
    @State private var isSaveError = false
    @State private var isCreating = false
    @State private var isLoadingGroups = false
    @State private var isSavingGroupName = false
    @State private var isDeletingGroup = false
    @State private var isDeleteConfirmPresented = false
    @State private var isQRScannerPresented = false
    @State private var isPhotoPickerPresented = false
    @State private var isGroupQRCodeOverlayPresented = false
    @State private var selectedQRCodePhoto: PhotosPickerItem?
    @State private var isJoiningGroup = false
    @State private var clearCreateMessageTask: Task<Void, Never>?
    @State private var clearSaveMessageTask: Task<Void, Never>?

    private let userService = UserService()
    private let groupService = GroupService()
    private let avatarColours = [
        "#A5C3DE", "#E6C7D0", "#C7C0E4", "#EAA5B8", "#B7D7C9",
        "#F1C994", "#BECBE7", "#EBD892", "#B7D9E7", "#EFE79E"
    ]

    private var cardBackground: Color { AppTheme.cardBackground(for: colorScheme) }
    private var fieldBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.08) : Color.white.opacity(0.85)
    }
    private var primaryText: Color { AppTheme.primaryText(for: colorScheme) }
    private var errorText: Color { AppTheme.errorText }
    private var cardBorder: Color { AppTheme.cardBorder(for: colorScheme) }

    private var usageRatio: Double {
        guard quotaMB > 0 else { return 0 }
        return min(max(usageMB / quotaMB, 0), 1)
    }

    private var usageText: String {
        "\(formatStorage(usageMB))/\(formatStorage(quotaMB))"
    }

    private var selectedGroup: GroupSummary? {
        guard let selectedGroupID else { return nil }
        return groups.first(where: { $0.id == selectedGroupID })
    }

    private var appShareURL: URL {
        URL(string: "https://apps.apple.com/app/id1234567890")!
    }

    private var selectedGroupInvitePayload: String? {
        guard let selectedGroupID else { return nil }
        return "kuusi://invite/\(selectedGroupID)"
    }

    private var storageCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Your storage")
						.font(.title3.weight(.bold))

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Spacer()
                    Text(usageText)
                        .font(.body.weight(.semibold))
                }

                GeometryReader { proxy in
                    let barWidth = max(0, proxy.size.width * usageRatio)
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(fieldBackground)
                            .frame(height: 22)
                        Capsule()
                            .fill(Color.accentColor)
                            .frame(width: barWidth, height: 22)
                    }
                }
                .frame(height: 22)

                HStack(spacing: 6) {
                    Text("Need more storage?")
										.font(.footnote.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text("Upgrade to premium.")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(primaryText)
                }
            }
            .padding(14)
            .background(cardBackground)
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .stroke(cardBorder, lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    private var subscriptionCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Subscription")
						.font(.title3.weight(.bold))

            Text("Upgrade to premium, cancel anytime.")
						.font(.footnote.weight(.medium))
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .center, spacing: 8) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 24, weight: .regular))
                        .opacity(plan == "free" ? 1 : 0)
                        .frame(width: 84)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Free plan")
                            .font(.body.weight(.semibold))

                        Text("•  5GB storage\n•  Preview photos up to 2 years\n•  Have up to 3 groups")
                            .font(.callout.weight(.medium))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(14)
            .background(cardBackground)
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .stroke(cardBorder, lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .center, spacing: 8) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 24, weight: .regular))
                        .opacity(plan == "premium" ? 1 : 0)
                        .frame(width: 84)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Premium plan - £20.00 / year")
                            .font(.body.weight(.semibold))
                        
                        Text("•  50GB storage\n•  Preview all photos\n•  Have up to 10 groups")
                            .font(.callout.weight(.medium))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(14)
            .background(cardBackground)
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .stroke(cardBorder, lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 6) {
                Text("Already got premium?")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text("Restore purchases.")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(primaryText)
            }
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    HStack(spacing: 10) {
                        if isEditingName {
                            Text("Hi,")
														.font(.title3.weight(.bold))
                            TextField("Name", text: $name)
                                .textFieldStyle(.plain)
																.font(.title3.weight(.bold))
                                .foregroundStyle(primaryText)
                        } else {
                            Text("Hi, \(name)")
														.font(.title3.weight(.bold))
                        }

                        Button {
                            isEditingName.toggle()
                        } label: {
                            Image(systemName: "pencil.and.outline")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Color.accentColor)
                        }
                        .buttonStyle(.plain)

                        Spacer()

                        if let message, !isError {
                            Text(message)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }

                        Button("Save") {
                            Task {
                                await saveProfile()
                            }
                        }
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(.ultraThinMaterial, in: Capsule())
                        .overlay {
                            Capsule()
                                .stroke(cardBorder.opacity(0.7), lineWidth: 1)
                        }
                        .buttonStyle(.plain)
                    }

                    profileCard
                    GroupsSectionView(
                        createGroupName: $createGroupName,
                        selectedGroupID: $selectedGroupID,
                        editableGroupName: $editableGroupName,
                        groups: $groups,
                        createStatusMessage: $createStatusMessage,
                        saveStatusMessage: $saveStatusMessage,
                        isLoadingGroups: $isLoadingGroups,
                        isGroupQRCodeOverlayPresented: $isGroupQRCodeOverlayPresented,
                        isDeleteConfirmPresented: $isDeleteConfirmPresented,
                        isQRScannerPresented: $isQRScannerPresented,
                        isPhotoPickerPresented: $isPhotoPickerPresented,
                        isCreateError: isCreateError,
                        isSaveError: isSaveError,
                        isCreating: isCreating,
                        isSavingGroupName: isSavingGroupName,
                        isDeletingGroup: isDeletingGroup,
                        isJoiningGroup: isJoiningGroup,
                        selectedGroupInvitePayload: selectedGroupInvitePayload,
                        appShareURL: appShareURL,
                        onCreateGroup: createGroup,
                        onSaveGroupName: saveGroupName
                    )

                    VStack(alignment: .leading, spacing: 12) {
                        storageCard
                        subscriptionCard

                        Button {
                            Task {
                                await appState.signOut()
                            }
                        } label: {
                            Text("Sign out")
                                .appTextLinkStyle()
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            Text("Privacy policy")
                                .appSecondaryTextLinkStyle()

                            Text("Terms of service")
                                .appSecondaryTextLinkStyle()

                            HStack(spacing: 4) {
                                Text("Made with love by")
                                    .appSecondaryTextLinkStyle()
                                Link("Sakura Wallace", destination: URL(string: "https://github.com/o6o6ooo")!)
                                    .appSecondaryTextLinkStyle()
                                    .foregroundStyle(Color.accentColor)
                            }
                        }
                        .padding(.top, 4)
                    }

                    if let message, isError {
                        Text(message)
                            .font(.footnote)
                            .foregroundStyle(errorText)
                    }
                }
                .padding(16)
                .foregroundStyle(primaryText)
            }
            .screenTheme()
            .toolbar(.hidden, for: .navigationBar)
            .refreshable {
                await loadProfile()
                await loadGroups()
            }
            .task {
                if !hasLoaded {
                    await loadProfile()
                    await loadGroups()
                    hasLoaded = true
                }
            }
            .photosPicker(
                isPresented: $isPhotoPickerPresented,
                selection: $selectedQRCodePhoto,
                matching: .images
            )
            .sheet(isPresented: $isEmojiPickerPresented) {
                EmojiPickerSheet(selectedEmoji: $icon)
            }
            .sheet(isPresented: $isQRScannerPresented) {
                QRCodeScannerSheet { payload in
                    Task {
                        await joinGroupFromQRCodePayload(payload)
                    }
                }
            }
            .sheet(isPresented: $isGroupQRCodeOverlayPresented) {
                if let selectedGroupInvitePayload {
                    GroupQRCodeOverlayView(payload: selectedGroupInvitePayload)
                        .presentationDetents([.height(400)])
                        .presentationDragIndicator(.visible)
                }
            }
            .alert("Delete group?", isPresented: $isDeleteConfirmPresented) {
                Button("Delete", role: .destructive) {
                    Task {
                        await deleteSelectedGroup()
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will remove the group for all members.")
            }
            .onChange(of: selectedQRCodePhoto) { _, newValue in
                guard let newValue else { return }
                Task {
                    await handleSelectedQRCodePhoto(newValue)
                }
            }
            .onChange(of: message) { _, newValue in
                scheduleMessageAutoClear(for: newValue)
            }
            .onChange(of: createStatusMessage) { _, newValue in
                scheduleCreateMessageAutoClear(for: newValue)
            }
            .onChange(of: saveStatusMessage) { _, newValue in
                scheduleSaveMessageAutoClear(for: newValue)
            }
            .onDisappear {
                clearMessageTask?.cancel()
                clearMessageTask = nil
                clearCreateMessageTask?.cancel()
                clearCreateMessageTask = nil
                clearSaveMessageTask?.cancel()
                clearSaveMessageTask = nil
            }
        }
    }

    private var profileCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 14) {
                Button {
                    isEmojiPickerPresented = true
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color(hex: bgColour))
                            .frame(width: 84, height: 84)
                        Text(icon.isEmpty ? "🌸" : icon)
                            .font(.system(size: 42))
                    }
                }
                .buttonStyle(.plain)

                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(minimum: 26, maximum: 36)), count: 5),
                    spacing: 10
                ) {
                    ForEach(avatarColours, id: \.self) { colour in
                        Button {
                            withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                                bgColour = colour
                            }
                        } label: {
                            Circle()
                                .fill(Color(hex: colour))
                                .frame(width: 36, height: 36)
                                .scaleEffect(bgColour == colour ? 1.07 : 1.0)
                                .overlay {
                                    if bgColour == colour {
                                        Circle()
                                            .stroke(.black.opacity(0.16), lineWidth: 1.2)
                                    }
                                }
                                .shadow(color: .black.opacity(bgColour == colour ? 0.12 : 0.05), radius: bgColour == colour ? 5 : 2, x: 0, y: 1)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

        }
        .padding(16)
        .background(cardBackground)
        .overlay {
            RoundedRectangle(cornerRadius: 20)
                .stroke(cardBorder, lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    @MainActor
    private func loadProfile() async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        do {
            if let user = try await userService.fetchUser(uid: uid) {
                name = user.name
                icon = user.icon
                bgColour = user.bgColour
                usageMB = user.usageMB
                quotaMB = user.quotaMB
                plan = user.plan
            }
        } catch {
            message = error.localizedDescription
            isError = true
        }
    }

    @MainActor
    private func saveProfile() async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanIcon = icon.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else {
            message = "Name cannot be empty."
            isError = true
            return
        }

        do {
            try await userService.updateProfile(
                uid: uid,
                name: cleanName,
                icon: cleanIcon.isEmpty ? "🌸" : cleanIcon,
                bgColour: bgColour
            )
            message = "Profile updated"
            isError = false
        } catch {
            message = error.localizedDescription
            isError = true
        }
    }

    @MainActor
    private func createGroup() async {
        guard let uid = Auth.auth().currentUser?.uid else {
            isCreateError = true
            createStatusMessage = "Please sign in first"
            return
        }

        let cleanName = createGroupName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanName.isEmpty else {
            isCreateError = true
            createStatusMessage = "Fill in group name"
            return
        }

        isCreating = true
        defer { isCreating = false }

        do {
            _ = try await groupService.createGroup(groupName: cleanName, ownerUID: uid)
            createGroupName = ""
            isCreateError = false
            createStatusMessage = "Group created. Pull down to refresh."
        } catch {
            isCreateError = true
            createStatusMessage = error.localizedDescription
        }
    }

    @MainActor
    private func loadGroups() async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        isLoadingGroups = true
        defer { isLoadingGroups = false }

        do {
            let fetched = try await groupService.fetchGroups(for: uid)
            groups = fetched

            if selectedGroupID == nil || !fetched.contains(where: { $0.id == selectedGroupID }) {
                selectedGroupID = fetched.first?.id
            }

            if let selectedGroup {
                editableGroupName = selectedGroup.name
            } else {
                editableGroupName = ""
            }
        } catch {
            isCreateError = true
            createStatusMessage = error.localizedDescription
        }
    }

    @MainActor
    private func saveGroupName() async {
        guard let selectedGroupID else { return }
        let trimmed = editableGroupName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        isSavingGroupName = true
        defer { isSavingGroupName = false }

        do {
            try await groupService.updateGroupName(groupID: selectedGroupID, name: trimmed)
            if let index = groups.firstIndex(where: { $0.id == selectedGroupID }) {
                groups[index] = GroupSummary(
                    id: groups[index].id,
                    name: trimmed,
                    members: groups[index].members,
                    totalMemberCount: groups[index].totalMemberCount
                )
            }
            isSaveError = false
            saveStatusMessage = "Group updated"
        } catch {
            isSaveError = true
            saveStatusMessage = error.localizedDescription
        }
    }

    @MainActor
    private func deleteSelectedGroup() async {
        guard let selectedGroupID else { return }

        isDeletingGroup = true
        defer { isDeletingGroup = false }

        do {
            try await groupService.deleteGroup(groupID: selectedGroupID)
            isSaveError = false
            saveStatusMessage = "Group deleted. Pull down to refresh."
        } catch {
            isSaveError = true
            saveStatusMessage = error.localizedDescription
        }
    }

    @MainActor
    private func handleSelectedQRCodePhoto(_ item: PhotosPickerItem) async {
        defer { selectedQRCodePhoto = nil }

        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                isSaveError = true
                saveStatusMessage = "Failed to load image"
                return
            }
            guard let payload = decodeQRCodePayload(from: data) else {
                isSaveError = true
                saveStatusMessage = "QR code was not found in the image"
                return
            }
            await joinGroupFromQRCodePayload(payload)
        } catch {
            isSaveError = true
            saveStatusMessage = error.localizedDescription
        }
    }

    @MainActor
    private func joinGroupFromQRCodePayload(_ payload: String) async {
        guard let uid = Auth.auth().currentUser?.uid else {
            isSaveError = true
            saveStatusMessage = "Please sign in first"
            return
        }
        guard let groupID = extractGroupID(from: payload) else {
            isSaveError = true
            saveStatusMessage = "Invalid invite QR"
            return
        }

        isJoiningGroup = true
        defer { isJoiningGroup = false }

        do {
            try await groupService.joinGroup(groupID: groupID, uid: uid)
            isSaveError = false
            saveStatusMessage = "Joined group"
        } catch {
            isSaveError = true
            saveStatusMessage = error.localizedDescription
        }
    }

    private func extractGroupID(from payload: String) -> String? {
        let trimmed = payload.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let url = URL(string: trimmed) {
            if url.scheme?.lowercased() == "kuusi", url.host?.lowercased() == "invite" {
                let groupID = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                return groupID.isEmpty ? nil : groupID.lowercased()
            }

            let parts = url.pathComponents.filter { $0 != "/" }
            if let idx = parts.firstIndex(of: "invite"), idx + 1 < parts.count {
                let groupID = parts[idx + 1].trimmingCharacters(in: .whitespacesAndNewlines)
                return groupID.isEmpty ? nil : groupID.lowercased()
            }
        }

        return trimmed.lowercased()
    }

    private func decodeQRCodePayload(from data: Data) -> String? {
        guard let ciImage = CIImage(data: data) else { return nil }
        let detector = CIDetector(
            ofType: CIDetectorTypeQRCode,
            context: nil,
            options: [CIDetectorAccuracy: CIDetectorAccuracyHigh]
        )
        let features = detector?.features(in: ciImage) as? [CIQRCodeFeature]
        return features?.first?.messageString
    }

    private func scheduleMessageAutoClear(for value: String?) {
        clearMessageTask?.cancel()
        guard value != nil, !isError else { return }

        let currentValue = value
        clearMessageTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            if !Task.isCancelled, message == currentValue, !isError {
                message = nil
            }
        }
    }

    private func scheduleCreateMessageAutoClear(for value: String?) {
        clearCreateMessageTask?.cancel()
        guard value != nil, !isCreateError else { return }

        let currentValue = value
        clearCreateMessageTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            if !Task.isCancelled, createStatusMessage == currentValue, !isCreateError {
                createStatusMessage = nil
            }
        }
    }

    private func scheduleSaveMessageAutoClear(for value: String?) {
        clearSaveMessageTask?.cancel()
        guard value != nil, !isSaveError else { return }

        let currentValue = value
        clearSaveMessageTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            if !Task.isCancelled, saveStatusMessage == currentValue, !isSaveError {
                saveStatusMessage = nil
            }
        }
    }

    private func formatStorage(_ mb: Double) -> String {
        if mb >= 1024 {
            let gb = mb / 1024
            if abs(gb.rounded() - gb) < 0.01 {
                return "\(Int(gb.rounded()))GB"
            }
            return String(format: "%.1fGB", gb)
        }

        if mb.rounded() >= mb - 0.01 {
            return "\(Int(mb.rounded()))MB"
        }
        return String(format: "%.0fMB", mb)
    }
}
