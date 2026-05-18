import AuthenticationServices
import Foundation
import PhotosUI
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var consentStore: ConsentStore
    @EnvironmentObject private var groupStore: GroupStore
    @EnvironmentObject private var subscriptionStore: SubscriptionStore
    @Environment(\.scenePhase) private var scenePhase

    @State private var hasLoaded = false
    @State private var selectedQRCodePhoto: PhotosPickerItem?
    @State private var appAlert: AppAlert?
    @State private var isDeleteAccountReauthenticationPresented = false
    @State private var privacyMessage: AppMessage?
    @StateObject private var groupsViewModel = SettingsGroupsViewModel()
    @StateObject private var profileViewModel = SettingsProfileViewModel()

    private var groupLoadingMessageKey: LocalizedStringKey? {
        if groupsViewModel.isPreparingGroupQRCode {
            return "groups.loading.qr_code"
        }
        if groupsViewModel.isJoiningGroup {
            return "groups.loading.joining"
        }
        return nil
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    ProfileView(
                        viewModel: profileViewModel,
                        onSignOut: {
                            Task {
                                await appState.signOut()
                            }
                        }
                    )
                    GroupsSectionView(viewModel: groupsViewModel)
                    SubscriptionView(usageMB: profileViewModel.usageMB)
                    FooterView(
                        showsPrivacyChoices: consentStore.isPrivacyOptionsRequired,
                        onPrivacyChoices: {
                            Task {
                                await presentPrivacyChoices()
                            }
                        },
                        onDeleteAccount: {
                            appAlert = AppAlert(.deleteAccountConfirm) {
                                isDeleteAccountReauthenticationPresented = true
                            }
                        }
                    )
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
            .overlay {
                if let messageKey = groupLoadingMessageKey {
                    SettingsLoadingOverlay(messageKey: messageKey)
                } else if appState.isDeletingAccount {
                    SettingsLoadingOverlay(messageKey: "settings.delete_account.deleting")
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .task {
                if !hasLoaded {
                    groupsViewModel.bindGroupStore(groupStore)
                    await subscriptionStore.prepare()
                    await profileViewModel.loadProfile()
                    await groupsViewModel.loadGroups()
                    groupsViewModel.updateCurrentPlan(subscriptionStore.isPremiumActive ? .premium : .free)
                    hasLoaded = true
                }
            }
            .onChange(of: subscriptionStore.isPremiumActive) { _, _ in
                groupsViewModel.updateCurrentPlan(subscriptionStore.isPremiumActive ? .premium : .free)
            }
            .onChange(of: scenePhase) { _, newPhase in
                guard newPhase == .active else { return }
                Task {
                    await subscriptionStore.prepare()
                    groupsViewModel.updateCurrentPlan(subscriptionStore.isPremiumActive ? .premium : .free)
                }
            }
            .photosPicker(
                isPresented: $groupsViewModel.isPhotoPickerPresented,
                selection: $selectedQRCodePhoto,
                matching: .images
            )
            .sheet(isPresented: $groupsViewModel.isGroupQRCodeOverlayPresented) {
                if let payload = groupsViewModel.selectedGroupInvitePayload {
                    GroupQRCodeOverlayView(
                        groupName: groupsViewModel.selectedGroup?.name ?? groupsViewModel.editableGroupName,
                        payload: payload
                    )
                        .presentationDetents([.height(440)])
                        .presentationDragIndicator(.visible)
                }
            }
            .sheet(isPresented: $groupsViewModel.isQRCodeScannerPresented) {
                QRCodeScannerView(
                    onScan: { payload in
                        groupsViewModel.isQRCodeScannerPresented = false
                        Task {
                            await groupsViewModel.joinGroupFromQRCodePayload(payload)
                        }
                    },
                    onError: { error in
                        groupsViewModel.isQRCodeScannerPresented = false
                        groupsViewModel.handleQRCodeScannerError(error)
                    }
                )
            }
            .sheet(isPresented: $groupsViewModel.isMemberListPresented) {
                GroupMembersOverlayView(
                    groupName: groupsViewModel.selectedGroup?.name ?? groupsViewModel.editableGroupName,
                    members: groupsViewModel.selectedGroupMembers,
                    currentUserIsOwner: groupsViewModel.currentUserIsSelectedGroupOwner,
                    removingMemberID: groupsViewModel.removingMemberID,
                    isRefreshing: groupsViewModel.isRefreshingMembers,
                    onRefresh: {
                        Task {
                            await groupsViewModel.refreshSelectedGroupMembers()
                        }
                    },
                    onRemoveMember: { member in
                        Task {
                            await groupsViewModel.removeMemberFromSelectedGroup(member)
                        }
                    }
                )
                    .presentationDetents([.height(280), .medium, .large])
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $isDeleteAccountReauthenticationPresented) {
                DeleteAccountReauthenticationView {
                    isDeleteAccountReauthenticationPresented = false
                }
                .presentationDetents([.height(260)])
                .presentationDragIndicator(.visible)
            }
            .onChange(of: groupsViewModel.isDeleteConfirmPresented) { _, isPresented in
                guard isPresented else { return }
                appAlert = AppAlert(
                    .destructiveGroupConfirm(
                        title: groupsViewModel.destructiveActionTitle,
                        message: groupsViewModel.destructiveActionMessage,
                        confirmButtonTitle: groupsViewModel.destructiveActionButtonTitle
                    )
                ) {
                    Task {
                        if groupsViewModel.selectedOrDefaultDestructiveAction == .delete {
                            await groupsViewModel.deleteSelectedGroup()
                        } else {
                            await groupsViewModel.leaveSelectedGroup()
                        }
                    }
                } onCancel: {
                    groupsViewModel.isDeleteConfirmPresented = false
                    groupsViewModel.selectedDestructiveAction = nil
                }
                groupsViewModel.isDeleteConfirmPresented = false
            }
            .appAlert($appAlert)
            .onChange(of: selectedQRCodePhoto) { _, newValue in
                guard let newValue else { return }
                Task {
                    let data = try? await newValue.loadTransferable(type: Data.self)
                    await groupsViewModel.handleSelectedQRCodePhotoData(data)
                    selectedQRCodePhoto = nil
                }
            }
            .onDisappear {
                groupsViewModel.onDisappear()
            }
            .appToastMessage(profileViewModel.toastMessage) {
                profileViewModel.clearToastMessage()
            }
            .appToastMessage(privacyMessage) {
                privacyMessage = nil
            }
            .appToastMessage(groupsViewModel.createStatusMessage)
            .appToastMessage(groupsViewModel.saveStatusMessage)
            .appToastHost()
        }
    }

    private func presentPrivacyChoices() async {
        do {
            try await consentStore.presentPrivacyOptions()
        } catch {
            privacyMessage = AppMessage(.failedToOpenPrivacyChoices, .error)
        }
    }
}

private struct DeleteAccountReauthenticationView: View {
    @EnvironmentObject private var appState: AppState
    @State private var currentNonce: String?

    let onFinished: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("settings.delete_account.reauth.title")
                .font(.headline)

            Text("settings.delete_account.reauth.message")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            SignInWithAppleButton(.continue, onRequest: { request in
                let nonce = CryptoNonce.randomNonceString()
                currentNonce = nonce
                request.nonce = CryptoNonce.sha256(nonce)
            }, onCompletion: { result in
                handleAuthorizationResult(result)
            })
            .signInWithAppleButtonStyle(.whiteOutline)
            .frame(maxWidth: .infinity, minHeight: 44, maxHeight: 44)
            .accessibilityIdentifier("delete-account-reauthenticate-button")

            Button("common.cancel") {
                onFinished()
            }
            .buttonStyle(.plain)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(Color.accentColor)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .appOverlayTheme()
    }

    private func handleAuthorizationResult(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case let .success(authorization):
            guard
                let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
                let nonce = currentNonce
            else {
                appState.toastMessage = AppMessage(.failedToDeleteAccount, .error)
                onFinished()
                return
            }

            Task {
                onFinished()
                await appState.reauthenticateWithAppleAndDelete(credential: credential, rawNonce: nonce)
            }
        case let .failure(error):
            if !Self.isCancellation(error) {
                appState.toastMessage = AppMessage(.failedToDeleteAccount, .error)
            }
            onFinished()
        }
    }

    private static func isCancellation(_ error: Error) -> Bool {
        let nsError = error as NSError
        return nsError.domain == ASAuthorizationError.errorDomain
            && nsError.code == ASAuthorizationError.canceled.rawValue
    }
}

private struct SettingsLoadingOverlay: View {
    let messageKey: LocalizedStringKey

    var body: some View {
        ZStack {
            Color.black.opacity(0.16)
                .ignoresSafeArea()

            VStack(spacing: 12) {
                ProgressView()

                Text(messageKey)
                    .font(.subheadline.weight(.semibold))
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 18)
            .appCardSurface(cornerRadius: 18, shadowRadius: 10, shadowOpacityMultiplier: 0.8)
        }
        .transition(.opacity)
        .accessibilityElement(children: .combine)
    }
}
