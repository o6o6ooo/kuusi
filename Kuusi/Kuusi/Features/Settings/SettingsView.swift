import FirebaseAuth
import Foundation
import PhotosUI
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var subscriptionStore: SubscriptionStore
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase

    @State private var name = ""
    @State private var icon = "🌸"
    @State private var bgColour = "#A5C3DE"
    @State private var message: String?
    @State private var isError = false
    @State private var hasLoaded = false
    @State private var isEmojiPickerPresented = false
    @State private var clearMessageTask: Task<Void, Never>?
    @State private var clearBillingMessageTask: Task<Void, Never>?
    @State private var subscriptionRefreshTask: Task<Void, Never>?
    @State private var usageMB: Double = 0
    @State private var isEditingName = false
    @State private var selectedQRCodePhoto: PhotosPickerItem?
    @State private var billingMessage: String?
    @State private var isBillingError = false
    @StateObject private var groupsViewModel = SettingsGroupsViewModel()

    private let userService = UserService()
    private let avatarColours = [
        "#A5C3DE", "#E6C7D0", "#C7C0E4", "#EAA5B8", "#B7D7C9",
        "#F1C994", "#BECBE7", "#EBD892", "#B7D9E7", "#EFE79E"
    ]

    private var cardBackground: Color { AppTheme.cardBackground(for: colorScheme) }
    private var primaryText: Color { AppTheme.primaryText(for: colorScheme) }
    private var errorText: Color { AppTheme.errorText }
    private var cardBorder: Color { AppTheme.cardBorder(for: colorScheme) }
    private var currentPlan: AppPlan { subscriptionStore.isPremiumActive ? .premium : .free }
    private var effectiveQuotaMB: Double { currentPlan.quotaMB }
    private var premiumRenewalText: String? {
        guard let renewalDate = subscriptionStore.renewalDate else { return nil }
        let label = subscriptionStore.willAutoRenew ? "Renews on" : "Expires on"
        return "\(label) \(formatDate(renewalDate))"
    }

    private var usageRatio: Double {
        guard effectiveQuotaMB > 0 else { return 0 }
        return min(max(usageMB / effectiveQuotaMB, 0), 1)
    }

    private var usageText: String {
        "\(formatStorage(usageMB))/\(formatStorage(effectiveQuotaMB))"
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
                        .buttonStyle(.appPrimaryCapsule)
                    }

                    profileCard
                    GroupsSectionView(viewModel: groupsViewModel)

                    VStack(alignment: .leading, spacing: 12) {
                        SubscriptionView(
                            currentPlan: currentPlan,
                            billingMessage: billingMessage,
                            isBillingError: isBillingError,
                            usageRatio: usageRatio,
                            usageText: usageText,
                            renewalText: premiumRenewalText,
                            onPurchase: {
                                Task { await purchasePremium() }
                            },
                            onRestore: {
                                Task { await restorePurchases() }
                            },
                            onManage: {
                                Task { await openManageSubscriptions() }
                            }
                        )

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
                await groupsViewModel.loadGroups()
            }
            .task {
                if !hasLoaded {
                    await subscriptionStore.prepare()
                    await loadProfile()
                    await groupsViewModel.loadGroups()
                    syncPlanDependentState()
                    hasLoaded = true
                }
            }
            .onChange(of: subscriptionStore.isPremiumActive) { _, _ in
                syncPlanDependentState()
            }
            .onChange(of: scenePhase) { _, newPhase in
                guard newPhase == .active else { return }
                Task {
                    await subscriptionStore.prepare()
                    syncPlanDependentState()
                }
            }
            .photosPicker(
                isPresented: $groupsViewModel.isPhotoPickerPresented,
                selection: $selectedQRCodePhoto,
                matching: .images
            )
            .sheet(isPresented: $isEmojiPickerPresented) {
                EmojiPickerSheet(selectedEmoji: $icon)
            }
            .sheet(isPresented: $groupsViewModel.isQRScannerPresented) {
                QRCodeScannerSheet { payload in
                    Task {
                        await groupsViewModel.joinGroupFromQRCodePayload(payload)
                    }
                }
            }
            .sheet(isPresented: $groupsViewModel.isGroupQRCodeOverlayPresented) {
                if let payload = groupsViewModel.selectedGroupInvitePayload {
                    GroupQRCodeOverlayView(payload: payload)
                        .presentationDetents([.height(400)])
                        .presentationDragIndicator(.visible)
                }
            }
            .sheet(isPresented: $groupsViewModel.isMemberListPresented) {
                GroupMembersOverlayView(members: groupsViewModel.selectedGroupMembers)
                    .presentationDetents([.height(280)])
                    .presentationDragIndicator(.visible)
            }
            .alert(groupsViewModel.destructiveActionTitle, isPresented: $groupsViewModel.isDeleteConfirmPresented) {
                Button(groupsViewModel.destructiveActionButtonTitle, role: .destructive) {
                    Task {
                        if groupsViewModel.currentUserIsSelectedGroupOwner {
                            await groupsViewModel.deleteSelectedGroup()
                        } else {
                            await groupsViewModel.leaveSelectedGroup()
                        }
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(groupsViewModel.destructiveActionMessage)
            }
            .onChange(of: selectedQRCodePhoto) { _, newValue in
                guard let newValue else { return }
                Task {
                    let data = try? await newValue.loadTransferable(type: Data.self)
                    await groupsViewModel.handleSelectedQRCodePhotoData(data)
                    selectedQRCodePhoto = nil
                }
            }
            .onChange(of: message) { _, newValue in
                scheduleMessageAutoClear(for: newValue)
            }
            .onChange(of: billingMessage) { _, newValue in
                scheduleBillingMessageAutoClear(for: newValue)
            }
            .onDisappear {
                clearMessageTask?.cancel()
                clearMessageTask = nil
                clearBillingMessageTask?.cancel()
                clearBillingMessageTask = nil
                subscriptionRefreshTask?.cancel()
                subscriptionRefreshTask = nil
                groupsViewModel.onDisappear()
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
                                .shadow(
                                    color: .black.opacity(bgColour == colour ? 0.12 : 0.05),
                                    radius: bgColour == colour ? 5 : 2,
                                    x: 0,
                                    y: 1
                                )
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
                syncPlanDependentState()
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

    private func scheduleBillingMessageAutoClear(for value: String?) {
        clearBillingMessageTask?.cancel()
        guard value != nil else { return }

        let currentValue = value
        clearBillingMessageTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            if !Task.isCancelled, billingMessage == currentValue {
                billingMessage = nil
            }
        }
    }

    @MainActor
    private func purchasePremium() async {
        do {
            try await subscriptionStore.purchasePremium()
            syncPlanDependentState()
            billingMessage = "Premium unlocked"
            isBillingError = false
        } catch let error as SubscriptionStoreError {
            if case .purchaseCancelled = error {
                return
            }
            billingMessage = error.localizedDescription
            isBillingError = true
        } catch {
            billingMessage = error.localizedDescription
            isBillingError = true
        }
    }

    @MainActor
    private func restorePurchases() async {
        do {
            try await subscriptionStore.restorePurchases()
            syncPlanDependentState()
            billingMessage = currentPlan == .premium ? "Purchases restored" : "No active purchases found"
            isBillingError = false
        } catch {
            billingMessage = error.localizedDescription
            isBillingError = true
        }
    }

    @MainActor
    private func openManageSubscriptions() async {
        do {
            try await subscriptionStore.openManageSubscriptions()
            syncPlanDependentState()
            scheduleSubscriptionRefresh()
        } catch {
            billingMessage = error.localizedDescription
            isBillingError = true
        }
    }

    private func syncPlanDependentState() {
        groupsViewModel.updateCurrentPlan(currentPlan)
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

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    private func scheduleSubscriptionRefresh() {
        subscriptionRefreshTask?.cancel()
        subscriptionRefreshTask = Task { @MainActor in
            for delay in [300_000_000, 1_000_000_000, 2_500_000_000] {
                try? await Task.sleep(nanoseconds: UInt64(delay))
                if Task.isCancelled { return }
                await subscriptionStore.prepare()
                syncPlanDependentState()
            }
        }
    }
}
