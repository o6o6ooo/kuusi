import Foundation
import PhotosUI
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var subscriptionStore: SubscriptionStore
    @Environment(\.scenePhase) private var scenePhase

    @State private var hasLoaded = false
    @State private var isEmojiPickerPresented = false
    @State private var isBackgroundPickerPresented = false
    @State private var pendingName = ""
    @State private var selectedQRCodePhoto: PhotosPickerItem?
    @State private var appAlert: AppAlert?
    @StateObject private var groupsViewModel = SettingsGroupsViewModel()
    @StateObject private var profileViewModel = SettingsProfileViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    ProfileView(
                        viewModel: profileViewModel,
                        onEditName: {
                            pendingName = profileViewModel.name
                            appAlert = AppAlert(.editNamePrompt, text: $pendingName) {
                                let updatedName = pendingName
                                Task {
                                    await profileViewModel.saveProfile(
                                        name: updatedName,
                                        icon: profileViewModel.icon,
                                        bgColour: profileViewModel.bgColour
                                    )
                                }
                            }
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
                    GroupsSectionView(viewModel: groupsViewModel)
                    SubscriptionView(usageMB: profileViewModel.usageMB)
                    FooterView {
                        appAlert = AppAlert(.deleteAccountConfirm) {
                            Task {
                                await appState.deleteCurrentUserAccount()
                            }
                        }
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
                        if groupsViewModel.currentUserIsSelectedGroupOwner {
                            await groupsViewModel.deleteSelectedGroup()
                        } else {
                            await groupsViewModel.leaveSelectedGroup()
                        }
                    }
                } onCancel: {
                    groupsViewModel.isDeleteConfirmPresented = false
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
            .appToastMessage(groupsViewModel.createStatusMessage)
            .appToastMessage(groupsViewModel.saveStatusMessage)
            .appToastHost()
        }
    }
}
