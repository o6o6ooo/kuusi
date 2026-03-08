import AVFoundation
import CoreImage
import CoreImage.CIFilterBuiltins
import FirebaseAuth
import Foundation
import PhotosUI
import SwiftUI
import UIKit

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
    private var memberBorderColor: Color { AppTheme.cardBorder(for: colorScheme) }

    private var usageRatio: Double {
        guard quotaMB > 0 else { return 0 }
        return min(max(usageMB / quotaMB, 0), 1)
    }

    private var usageText: String {
        "\(formatStorage(usageMB))/\(formatStorage(quotaMB))"
    }

    private var createStatusTextColor: Color {
        isCreateError ? AppTheme.errorText : AppTheme.primaryText(for: colorScheme).opacity(0.7)
    }

    private var saveStatusTextColor: Color {
        isSaveError ? AppTheme.errorText : AppTheme.primaryText(for: colorScheme).opacity(0.7)
    }

    private var canCreate: Bool {
        !isCreating && !createGroupName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var selectedGroup: GroupSummary? {
        guard let selectedGroupID else { return nil }
        return groups.first(where: { $0.id == selectedGroupID })
    }

    private var canSaveSelectedGroupName: Bool {
        guard let selectedGroup else { return false }
        let trimmed = editableGroupName.trimmingCharacters(in: .whitespacesAndNewlines)
        return !isSavingGroupName && !trimmed.isEmpty && trimmed != selectedGroup.name
    }

    private var canDeleteSelectedGroup: Bool {
        selectedGroupID != nil && !isDeletingGroup
    }

    private var canAddMemberByQRCode: Bool {
        !isJoiningGroup
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
                .font(.system(size: 20, weight: .bold))

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Spacer()
                    Text(usageText)
                        .font(.headline.weight(.semibold))
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
										.font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text("Upgrade to premium.")
                        .font(.subheadline.weight(.semibold))
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
                .font(.system(size: 20, weight: .bold))

            Text("Upgrade to premium, cancel anytime.")
						.font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .center, spacing: 8) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 24, weight: .regular))
                        .opacity(plan == "free" ? 1 : 0)
                        .frame(width: 84)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Free plan")
                            .font(.subheadline.weight(.semibold))

                        Text("•  5GB storage\n•  Preview photos up to 2 years\n•  Have up to 3 groups")
                            .font(.subheadline.weight(.medium))
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
                            .font(.subheadline.weight(.semibold))
                        
                        Text("•  50GB storage\n•  Preview all photos\n•  Have up to 10 groups")
                            .font(.subheadline.weight(.medium))
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
                                .font(.system(size: 20, weight: .bold))
                            TextField("Name", text: $name)
                                .textFieldStyle(.plain)
                                .font(.system(size: 20, weight: .bold))
                                .foregroundStyle(primaryText)
                        } else {
                            Text("Hi, \(name)")
                                .font(.system(size: 20, weight: .bold))
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
                    groupsSection

                    VStack(alignment: .leading, spacing: 12) {
                        storageCard
                        subscriptionCard

                        Button {
                            Task {
                                await appState.signOut()
                            }
                        } label: {
                            Text("Sign out")
                                .foregroundStyle(Color.accentColor)
                        }
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

    private var groupsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Create a group")
                .font(.system(size: 20, weight: .bold))

            VStack(spacing: 12) {
                HStack(spacing: 10) {
                    TextField(
                        "",
                        text: $createGroupName,
                        prompt: Text("group name")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    )
                    .textFieldStyle(.plain)
                    .font(.body)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(fieldBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 14))

                    Button {
                        Task {
                            await createGroup()
                        }
                    } label: {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 34, height: 34)
                            .background(Color.accentColor)
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .disabled(!canCreate)
                }
            }
            .padding(14)
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 20))

            if let createStatusMessage {
                Text(createStatusMessage)
                    .font(.footnote)
                    .foregroundStyle(createStatusTextColor)
            }

            Text("Your groups")
                .font(.system(size: 20, weight: .bold))
                .padding(.top, 8)

            VStack(spacing: 12) {
                if isLoadingGroups {
                    ProgressView()
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else if groups.isEmpty {
                    Text("No groups yet. Pull down to refresh.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: 10) {
                            ForEach(groups) { group in
                                let isSelected = selectedGroupID == group.id
                                Button(group.name) {
                                    selectedGroupID = group.id
                                    editableGroupName = group.name
                                }
                                .font(.body)
                                .foregroundStyle(isSelected ? Color.white : Color.accentColor)
                                .padding(.horizontal, 14)
                                .frame(height: 34)
                                .background(
                                    Capsule()
                                        .fill(isSelected ? Color.accentColor : Color.clear)
                                )
                                .overlay {
                                    Capsule()
                                        .strokeBorder(Color.accentColor, lineWidth: 1)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .fixedSize(horizontal: true, vertical: false)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    TextField(
                        "",
                        text: $editableGroupName,
                        prompt: Text("group name")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    )
                    .textFieldStyle(.plain)
                    .font(.body)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(fieldBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 14))

                    HStack(spacing: 10) {
                        Button {
                            isGroupQRCodeOverlayPresented = true
                        } label: {
                            Image(systemName: "qrcode")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 34, height: 34)
                                .background(Color.accentColor)
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .disabled(selectedGroupInvitePayload == nil)

                        if let selectedGroup {
                            HStack(spacing: -8) {
                                ForEach(selectedGroup.members) { member in
                                    Text(member.icon)
                                        .font(.system(size: 18))
                                        .frame(width: 36, height: 36)
                                        .background(Color(hex: member.bgColour))
                                        .clipShape(Circle())
                                        .overlay {
                                            Circle()
                                                .stroke(memberBorderColor, lineWidth: 2)
                                        }
                                }
                                let remainingCount = max(0, selectedGroup.totalMemberCount - selectedGroup.members.count)
                                if remainingCount > 0 {
                                    Text("+\(remainingCount)")
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(AppTheme.primaryText(for: colorScheme).opacity(0.85))
                                        .frame(width: 36, height: 36)
                                        .background(fieldBackground)
                                        .clipShape(Circle())
                                        .overlay {
                                            Circle()
                                                .stroke(memberBorderColor, lineWidth: 2)
                                        }
                                }
                            }
                        }

                        Spacer()

                        if let saveStatusMessage {
                            Text(saveStatusMessage)
                                .font(.footnote)
                                .foregroundStyle(saveStatusTextColor)
                        }

                        Button {
                            isDeleteConfirmPresented = true
                        } label: {
                            Image(systemName: "trash.fill")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 34, height: 34)
                                .background(AppTheme.errorText.opacity(0.7))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .disabled(!canDeleteSelectedGroup)

                        Button {
                            Task {
                                await saveGroupName()
                            }
                        } label: {
                            Image(systemName: "checkmark")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 34, height: 34)
                                .background(Color.accentColor)
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .disabled(!canSaveSelectedGroupName)
                    }
                }
            }
            .padding(14)
            .background(cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 20))

            Menu {
                Button {
                    isQRScannerPresented = true
                } label: {
                    Label("Scan QR code", systemImage: "camera")
                }

                Button {
                    isPhotoPickerPresented = true
                } label: {
                    Label("Choose from Photos", systemImage: "photo.badge.magnifyingglass")
                }
            } label: {
                Text("Join a group")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
            }
            .buttonStyle(.plain)
            .disabled(!canAddMemberByQRCode)

            ShareLink(item: appShareURL) {
                Text("Tell your friends about this app?")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
            }
            .buttonStyle(.plain)
        }
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

private struct GroupQRCodeOverlayView: View {
    @Environment(\.colorScheme) private var colorScheme
    let payload: String
    private let context = CIContext()
    private let filter = CIFilter.qrCodeGenerator()
    private var cardBackground: Color { AppTheme.cardBackground(for: colorScheme) }

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                if let image = makeQRCodeImage(from: payload) {
                    Image(uiImage: image)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 220, height: 220)
                        .padding(18)
                        .background(cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                } else {
                    Text("Failed to generate QR code")
                        .font(.footnote)
                        .foregroundStyle(AppTheme.errorText)
                }

                ShareLink(item: payload) {
                    Text("Share QR code")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                }
                .buttonStyle(.plain)
            }
            .padding(20)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .screenTheme()
        }
    }

    private func makeQRCodeImage(from string: String) -> UIImage? {
        filter.setValue(Data(string.utf8), forKey: "inputMessage")
        filter.setValue("M", forKey: "inputCorrectionLevel")
        guard let outputImage = filter.outputImage else { return nil }
        let transformed = outputImage.transformed(by: CGAffineTransform(scaleX: 10, y: 10))
        guard let cgImage = context.createCGImage(transformed, from: transformed.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}

private struct QRCodeScannerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onCode: (String) -> Void
    @State private var scanError: String?

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                QRCodeCameraView(
                    onCode: { code in
                        onCode(code)
                        dismiss()
                    },
                    onError: { message in
                        scanError = message
                    }
                )
                .ignoresSafeArea()

                if let scanError {
                    Text(scanError)
                        .font(.footnote)
                        .foregroundStyle(AppTheme.errorText)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                        .padding(.bottom, 20)
                }
            }
            .navigationTitle("Scan QR")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct QRCodeCameraView: UIViewRepresentable {
    let onCode: (String) -> Void
    let onError: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onCode: onCode, onError: onError)
    }

    func makeUIView(context: Context) -> CameraPreviewView {
        let view = CameraPreviewView()
        context.coordinator.configureSession(previewView: view)
        return view
    }

    func updateUIView(_ uiView: CameraPreviewView, context: Context) {}

    static func dismantleUIView(_ uiView: CameraPreviewView, coordinator: Coordinator) {
        coordinator.stopSession()
    }

    final class Coordinator: NSObject, AVCaptureMetadataOutputObjectsDelegate {
        private let onCode: (String) -> Void
        private let onError: (String) -> Void
        private var session: AVCaptureSession?
        private var didScan = false

        init(onCode: @escaping (String) -> Void, onError: @escaping (String) -> Void) {
            self.onCode = onCode
            self.onError = onError
        }

        func configureSession(previewView: CameraPreviewView) {
            switch AVCaptureDevice.authorizationStatus(for: .video) {
            case .authorized:
                setupCaptureSession(previewView: previewView)
            case .notDetermined:
                AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                    DispatchQueue.main.async {
                        guard let self else { return }
                        if granted {
                            self.setupCaptureSession(previewView: previewView)
                        } else {
                            self.onError("Camera permission was denied")
                        }
                    }
                }
            case .denied, .restricted:
                onError("Enable camera access in Settings")
            @unknown default:
                onError("Camera is unavailable")
            }
        }

        func stopSession() {
            session?.stopRunning()
            session = nil
        }

        private func setupCaptureSession(previewView: CameraPreviewView) {
            let session = AVCaptureSession()
            guard let device = AVCaptureDevice.default(for: .video) else {
                onError("Camera is unavailable")
                return
            }

            do {
                let input = try AVCaptureDeviceInput(device: device)
                guard session.canAddInput(input) else {
                    onError("Failed to configure camera input")
                    return
                }
                session.addInput(input)
            } catch {
                onError(error.localizedDescription)
                return
            }

            let output = AVCaptureMetadataOutput()
            guard session.canAddOutput(output) else {
                onError("Failed to configure camera output")
                return
            }
            session.addOutput(output)
            output.setMetadataObjectsDelegate(self, queue: .main)
            output.metadataObjectTypes = [.qr]

            previewView.previewLayer.session = session
            previewView.previewLayer.videoGravity = .resizeAspectFill
            self.session = session
            DispatchQueue.global(qos: .userInitiated).async {
                session.startRunning()
            }
        }

        func metadataOutput(
            _ output: AVCaptureMetadataOutput,
            didOutput metadataObjects: [AVMetadataObject],
            from connection: AVCaptureConnection
        ) {
            guard !didScan else { return }
            guard
                let qrObject = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
                let stringValue = qrObject.stringValue
            else {
                return
            }
            didScan = true
            stopSession()
            onCode(stringValue)
        }
    }
}

private final class CameraPreviewView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
}

private struct EmojiPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedEmoji: String

    private let emojis = [
        "☺️","😉","🥰","🥳","😎","🥺","😳","🫠","😲","🤑",
        "🐶","🐱","🐼","🐻‍❄️","🐰","🐨","🐸","🦁","🐷","🐻",
        "🦄","🦋","🦆","🐊","🐏","🐖","🦓","🦢","🐇","🦔",
        "🐈‍⬛","🐄","🌲","🎄","🎍","🌷","🌹","🥀","🌸","🪷",
        "💐","💭","🌝","🌜","🌚","🌞","🌍","🪐","☔️","⛄️",
        "🌦️","🌧️","❄️","🌨️","☁️","⭐️",
        "🍎","🍐","🍋","🍇","🍒","🍓","🍍","🍉","🥝","🥑",
        "🍅","🍆","🥒","🫛","🥦","🌽","🫜","🥕","🫒","🥫",
        "🍳","🥓","🥖","🧈","🥞","🍕","🌭","🥟","🍣","🍤",
        "🍙","🍥","🍡","🎂","🧁","🍩","🫖","🧃","🍺","🥄",
        "🎱","⛳️","🥌","⛷️","🛹","🎣","⚽️","🎾","🎧","🥁",
        "🎺","🎯","🎳","🎮","🚦","🗿","⛱️","🗼","⛩️","🗻",
        "✈️","🛩️","🚁","🚢","🚘","🚖","🛞","🏠","🏡",
        "💻","⌨️","📱","⌚️","⏰","💸","⚙️","🪏","🔨","🧻",
        "🪣","🧺","🪥","🪑","🚪","🎈","📫","📚","🗑️","👀",
        "🧣","🩴","⛑️","❤️","💛","💚","🩵","💙","🤍",
        "🩷","💞","💤","🌀","❔","🎶"
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(minimum: 36, maximum: 52)), count: 8), spacing: 12) {
                    ForEach(emojis, id: \.self) { emoji in
                        Button {
                            selectedEmoji = emoji
                            dismiss()
                        } label: {
                            Text(emoji)
                                .font(.system(size: 30))
                                .frame(width: 44, height: 44)
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(selectedEmoji == emoji ? Color.blue.opacity(0.15) : Color.clear)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(16)
            }
            .navigationTitle("Choose Icon")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
}
