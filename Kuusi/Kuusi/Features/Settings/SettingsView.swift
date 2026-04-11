import Foundation
import PhotosUI
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var subscriptionStore: SubscriptionStore
    @Environment(\.scenePhase) private var scenePhase

    @State private var hasLoaded = false
    @State private var isNameEditorPresented = false
    @State private var isEmojiPickerPresented = false
    @State private var isBackgroundPickerPresented = false
    @State private var pendingName = ""
    @State private var clearBillingMessageTask: Task<Void, Never>?
    @State private var subscriptionRefreshTask: Task<Void, Never>?
    @State private var selectedQRCodePhoto: PhotosPickerItem?
    @State private var billingMessage: AppMessage?
    @StateObject private var groupsViewModel = SettingsGroupsViewModel()
    @StateObject private var profileViewModel = SettingsProfileViewModel()

    private var currentPlan: AppPlan { subscriptionStore.isPremiumActive ? .premium : .free }
    private var effectiveQuotaMB: Double { currentPlan.quotaMB }
    private var premiumRenewalText: String? {
        guard let renewalDate = subscriptionStore.renewalDate else { return nil }
        let label = subscriptionStore.willAutoRenew ? "Renews on" : "Expires on"
        return "\(label) \(formatDate(renewalDate))"
    }

    private var usageRatio: Double {
        guard effectiveQuotaMB > 0 else { return 0 }
        return min(max(profileViewModel.usageMB / effectiveQuotaMB, 0), 1)
    }

    private var usageText: String {
        "\(formatStorage(profileViewModel.usageMB))/\(formatStorage(effectiveQuotaMB))"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    ProfileView(
                        viewModel: profileViewModel,
                        onEditName: {
                            pendingName = profileViewModel.name
                            isNameEditorPresented = true
                        },
                        onEditIcon: {
                            isEmojiPickerPresented = true
                        },
                        onEditBackground: {
                            isBackgroundPickerPresented = true
                        },
                        onSignOut: {
                            Task {
                                await appState.signOut()
                            }
                        }
                    )
                    googlePhotosSection
                    GroupsSectionView(viewModel: groupsViewModel)

                    VStack(alignment: .leading, spacing: 12) {
                        SubscriptionView(
                            currentPlan: currentPlan,
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

                }
                .padding(16)
            }
            .appOverlayTheme()
            .overlay(alignment: .topLeading) {
                Group {
                    Text("ui-screen-settings")
                        .accessibilityIdentifier("ui-screen-settings")
                    Text("ui-settings-profile-section")
                        .accessibilityIdentifier("ui-settings-profile-section")
                    Text("ui-settings-groups-section")
                        .accessibilityIdentifier("ui-settings-groups-section")
                    Text("ui-settings-subscription-section")
                        .accessibilityIdentifier("ui-settings-subscription-section")
                }
                .font(.caption2)
                .foregroundStyle(.clear)
                .frame(width: 0, height: 0)
                .clipped()
                .allowsHitTesting(false)
            }
            .toolbar(.hidden, for: .navigationBar)
            .task {
                if !hasLoaded {
                    await subscriptionStore.prepare()
                    await profileViewModel.loadProfile()
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
                EmojiPickerSheet(
                    selectedEmoji: Binding(
                        get: { profileViewModel.icon },
                        set: { newValue in
                            Task {
                                await profileViewModel.saveProfile(
                                    name: profileViewModel.name,
                                    icon: newValue,
                                    bgColour: profileViewModel.bgColour
                                )
                            }
                        }
                    )
                )
            }
            .sheet(isPresented: $isBackgroundPickerPresented) {
                BackgroundColorPickerSheet(selectedColour: profileViewModel.bgColour) { colour in
                    Task {
                        await profileViewModel.saveProfile(
                            name: profileViewModel.name,
                            icon: profileViewModel.icon,
                            bgColour: colour
                        )
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
            .alert("Edit Name", isPresented: $isNameEditorPresented) {
                TextField("Name", text: $pendingName)
                Button("Cancel", role: .cancel) {}
                Button("OK") {
                    let updatedName = pendingName
                    Task {
                        await profileViewModel.saveProfile(
                            name: updatedName,
                            icon: profileViewModel.icon,
                            bgColour: profileViewModel.bgColour
                        )
                    }
                }
            } message: {
                Text("Enter your display name.")
            }
            .onChange(of: selectedQRCodePhoto) { _, newValue in
                guard let newValue else { return }
                Task {
                    let data = try? await newValue.loadTransferable(type: Data.self)
                    await groupsViewModel.handleSelectedQRCodePhotoData(data)
                    selectedQRCodePhoto = nil
                }
            }
            .onChange(of: billingMessage) { _, newValue in
                scheduleBillingMessageAutoClear(for: newValue)
            }
            .onDisappear {
                clearBillingMessageTask?.cancel()
                clearBillingMessageTask = nil
                subscriptionRefreshTask?.cancel()
                subscriptionRefreshTask = nil
                groupsViewModel.onDisappear()
            }
            .appToastMessage(profileViewModel.toastMessage) {
                profileViewModel.clearToastMessage()
            }
            .appToastMessage(groupsViewModel.createStatusMessage)
            .appToastMessage(groupsViewModel.saveStatusMessage)
            .appToastMessage(billingMessage) {
                billingMessage = nil
            }
            .appToastHost()
        }
    }

    private var googlePhotosSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Google Photos")
                .font(.title3.weight(.bold))

            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(profileViewModel.isGoogleLinked ? "Connected as \(profileViewModel.googleLinkedEmail)" : "Not connected")
                        .font(.subheadline.weight(.semibold))

                    if !profileViewModel.isGoogleLinked {
                        Text("Connect to your Google account to import photos from Google Photos.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                if profileViewModel.isGoogleAccountActionInFlight {
                    ProgressView()
                        .controlSize(.small)
                } else if profileViewModel.isGoogleLinked {
                    Button("Disconnect") {
                        Task {
                            await profileViewModel.disconnectGoogleAccount()
                        }
                    }
                    .buttonStyle(.appPrimaryCapsule)
                    .controlSize(.small)
                } else {
                    Button("Connect") {
                        Task {
                            await profileViewModel.connectGoogleAccount()
                        }
                    }
                    .buttonStyle(.appPrimaryCapsule)
                    .controlSize(.small)
                }
            }
        }
    }

    private func scheduleBillingMessageAutoClear(for value: AppMessage?) {
        clearBillingMessageTask?.cancel()
        clearBillingMessageTask = AppMessageAutoClear.schedule(
            for: value,
            currentMessage: { billingMessage },
            clear: { billingMessage = nil }
        )
    }

    @MainActor
    private func purchasePremium() async {
        do {
            try await subscriptionStore.purchasePremium()
            syncPlanDependentState()
            billingMessage = AppMessage(.premiumUnlocked, .success)
        } catch let error as SubscriptionStoreError {
            if case .purchaseCancelled = error {
                return
            }
            billingMessage = AppMessage(.details(error.localizedDescription), .error)
        } catch {
            billingMessage = AppMessage(.details(error.localizedDescription), .error)
        }
    }

    @MainActor
    private func restorePurchases() async {
        do {
            try await subscriptionStore.restorePurchases()
            syncPlanDependentState()
            billingMessage = currentPlan == .premium ? AppMessage(.purchasesRestored, .success) : AppMessage(.noActivePurchasesFound, .success)
        } catch {
            billingMessage = AppMessage(.details(error.localizedDescription), .error)
        }
    }

    @MainActor
    private func openManageSubscriptions() async {
        do {
            try await subscriptionStore.openManageSubscriptions()
            syncPlanDependentState()
            scheduleSubscriptionRefresh()
        } catch {
            billingMessage = AppMessage(.details(error.localizedDescription), .error)
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
