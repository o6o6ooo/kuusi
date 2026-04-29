import AppTrackingTransparency
import FirebaseAuth
import SwiftUI

private extension FeedServiceError {
    var appMessageID: AppMessage.ID {
        switch self {
        case .cannotEditOthersPhotos:
            return .cannotEditOthersPhotos
        case .cannotDeleteOthersPhotos:
            return .cannotDeleteOthersPhotos
        }
    }
}

@MainActor
struct FeedView: View {
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var subscriptionStore: SubscriptionStore
    @StateObject private var photoCollection = PhotoCollectionViewModel()
    @StateObject private var profileViewModel = SettingsProfileViewModel()

    @State private var selectedHashtag: String?
    @State private var isUploadOverlayPresented = false
    @State private var isSettingsPresented = false
    @State private var isHashtagBarExpanded = false
    @State private var isFavouritesFilterEnabled = false
    @State private var selectedPhotoID: String?
    @State private var feedMessage: AppMessage?
    @State private var deletingPhotoIDs: Set<String> = []
    @State private var favouritingPhotoIDs: Set<String> = []
    @State private var editingPhotoIDs: Set<String> = []
    @State private var appAlert: AppAlert?
    @State private var editingPhoto: FeedPhoto?
    @State private var clearFeedMessageTask: Task<Void, Never>?
    @State private var trackingAuthorizationStatus = ATTrackingManager.trackingAuthorizationStatus
    @State private var hasStartedTrackingAuthorizationRequest = false

    private let feedService = FeedService()
    private var currentGroupPhotos: [FeedPhoto] {
        photoCollection.currentGroupPhotos
    }

    private var currentGroupName: String {
        photoCollection.groups.first(where: { $0.id == photoCollection.selectedGroupID })?.name ?? "Feed"
    }

    private var availableHashtags: [String] {
        photoCollection.currentGroupAvailableHashtags
    }

    private var currentUserID: String? {
        Auth.auth().currentUser?.uid
    }

    private var feedPageSize: Int {
        UIDevice.current.userInterfaceIdiom == .pad ? 24 : 18
    }

    private var shouldShowFeedAds: Bool {
        !subscriptionStore.isPremiumActive
    }

    private var canLoadFeedAds: Bool {
        shouldShowFeedAds && trackingAuthorizationStatus != .notDetermined
    }

    private var displayedPhotos: [FeedPhoto] {
        currentGroupPhotos.filter { photo in
            let matchesHashtag = selectedHashtag == nil || photo.hashtags.contains {
                $0.caseInsensitiveCompare(selectedHashtag ?? "") == .orderedSame
            }
            let matchesFavourite = !isFavouritesFilterEnabled || photo.isFavourite
            return matchesHashtag && matchesFavourite
        }
    }

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                ZStack(alignment: .top) {
                    content(for: proxy)

                    FeedTopChromeView(
                        groupName: currentGroupName,
                        subtitle: feedSubtitle,
                        hasGroups: !photoCollection.groups.isEmpty,
                        profileIcon: profileViewModel.icon,
                        profileBackgroundColour: profileViewModel.bgColour,
                        isFavouritesFilterEnabled: isFavouritesFilterEnabled,
                        topInset: proxy.safeAreaInsets.top,
                        onUpload: {
                            isUploadOverlayPresented = true
                        },
                        onToggleFavourites: {
                            withAnimation(.spring(response: 0.32, dampingFraction: 0.84)) {
                                isFavouritesFilterEnabled.toggle()
                            }
                        },
                        onOpenSettings: {
                            isSettingsPresented = true
                        }
                    )

                    VStack {
                        Spacer()
                        FeedBottomChromeView(
                            groups: photoCollection.groups,
                            availableHashtags: availableHashtags,
                            selectedHashtag: $selectedHashtag,
                            isHashtagBarExpanded: $isHashtagBarExpanded,
                            onSelectGroup: { groupID in
                                withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                                    selectedHashtag = nil
                                    photoCollection.selectGroup(groupID, limit: feedPageSize)
                                }
                            }
                        )
                    }
                }
            }
            .overlay(alignment: .topLeading) {
                Group {
                    Text("ui-screen-feed")
                        .accessibilityIdentifier("ui-screen-feed")

                    if photoCollection.groups.isEmpty {
                        Text("ui-feed-no-groups")
                            .accessibilityIdentifier("ui-feed-no-groups")
                    } else if !photoCollection.isLoading,
                              photoCollection.errorMessageID == nil,
                              currentGroupPhotos.isEmpty {
                        Text("ui-feed-no-photos")
                            .accessibilityIdentifier("ui-feed-no-photos")
                    }
                }
                .font(.caption2)
                .foregroundStyle(.clear)
                .frame(width: 0, height: 0)
                .clipped()
                .allowsHitTesting(false)
            }
            .toolbar(.hidden, for: .navigationBar)
            .appFeedBackground()
            .task {
                if photoCollection.groups.isEmpty {
                    await photoCollection.loadInitial(limit: feedPageSize)
                }
                if profileViewModel.name.isEmpty {
                    await profileViewModel.loadProfile()
                }
                requestTrackingAuthorizationForAdsIfNeeded()
            }
            .onChange(of: scenePhase) { _, _ in
                requestTrackingAuthorizationForAdsIfNeeded()
            }
            .onChange(of: subscriptionStore.isPremiumActive) { _, _ in
                requestTrackingAuthorizationForAdsIfNeeded()
            }
            .onChange(of: feedMessage) { _, newValue in
                scheduleFeedMessageAutoClear(for: newValue)
            }
            .onChange(of: photoCollection.errorMessageID) { _, newValue in
                guard let newValue else { return }
                feedMessage = AppMessage(newValue, .error)
                photoCollection.clearErrorMessage()
            }
            .sheet(isPresented: $isUploadOverlayPresented) {
                UploadOverlayView(
                    currentUsageMB: profileViewModel.usageMB,
                    isPremiumActive: subscriptionStore.isPremiumActive
                )
                    .presentationDetents([.fraction(0.60)])
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $isSettingsPresented, onDismiss: {
                Task { await profileViewModel.loadProfile() }
            }) {
                SettingsView()
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
            .sheet(item: $editingPhoto) { photo in
                EditOverlayView(photo: photo) { year, hashtags in
                    await savePhotoEdits(photo: photo, year: year, hashtags: hashtags)
                }
                .presentationDetents([.height(330)])
                .presentationDragIndicator(.visible)
            }
            .onChange(of: displayedPhotos.map(\.id)) { _, ids in
                guard let selectedPhotoID, !ids.contains(selectedPhotoID) else { return }
                self.selectedPhotoID = nil
            }
            .appAlert($appAlert)
            .onDisappear {
                clearFeedMessageTask?.cancel()
                clearFeedMessageTask = nil
            }
            .appToastMessage(feedMessage) {
                feedMessage = nil
            }
        }
    }

    @ViewBuilder
    private func content(for proxy: GeometryProxy) -> some View {
        if photoCollection.groups.isEmpty {
            emptyFeedState(
                in: proxy,
                title: "No groups yet",
                systemImage: "person.3",
                description: "Create or join a group in Settings to start sharing."
            )
        } else if photoCollection.isLoading {
            ProgressView("Loading feed...")
                .font(.headline.weight(.semibold))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .padding(.top, 116)
                .padding(.bottom, 120)
        } else if currentGroupPhotos.isEmpty {
            emptyFeedState(
                in: proxy,
                title: "No photos yet",
                systemImage: "photo",
                description: "Plus button to upload photos."
            )
        } else if displayedPhotos.isEmpty {
            emptyFeedState(
                in: proxy,
                title: emptyStateTitle,
                systemImage: emptyStateSymbol,
                description: emptyStateDescription
            )
        } else {
            PhotoGridView(
                photos: displayedPhotos,
                availableWidth: proxy.size.width,
                availableHeight: proxy.size.height,
                expandedPhotoID: selectedPhotoID,
                showsInlineAds: shouldShowFeedAds,
                onTap: { photo in
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedPhotoID = selectedPhotoID == photo.id ? nil : photo.id
                    }
                },
                onLoadMore: {
                    photoCollection.loadMoreIfNeeded(pageSize: feedPageSize)
                }
            ) { photo, tileWidth, displayAspectRatio, isExpanded, onTap in
                PhotoTileView(
                    photo: photo,
                    previewAccess: PlanAccessPolicy.previewAccess(
                        for: photo,
                        isPremiumActive: subscriptionStore.isPremiumActive
                    ),
                    width: tileWidth,
                    displayAspectRatio: displayAspectRatio,
                    isExpanded: isExpanded,
                    canDelete: photo.isOwned(by: currentUserID),
                    onTap: onTap,
                    onEdit: { editingPhoto = photo },
                    onDelete: {
                        appAlert = AppAlert(.deletePhotoConfirm) {
                            Task {
                                await deletePhoto(photo)
                            }
                        }
                    },
                    onToggleFavourite: {
                        Task { await toggleFavourite(photo) }
                    },
                    isDeleting: deletingPhotoIDs.contains(photo.id),
                    isFavouriting: favouritingPhotoIDs.contains(photo.id),
                    isEditing: editingPhotoIDs.contains(photo.id)
                )
            } inlineAd: { width in
                FeedNativeAdTileView(width: width, canLoadAds: canLoadFeedAds)
            } footer: {
                if photoCollection.isLoadingMore {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                } else {
                    EmptyView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .refreshable {
                await refreshCurrentGroup()
            }
        }
    }

    private func emptyFeedState(
        in proxy: GeometryProxy,
        title: String,
        systemImage: String,
        description: String
    ) -> some View {
        ScrollView {
            glassUnavailableView(
                title: title,
                systemImage: systemImage,
                description: description
            )
            .frame(maxWidth: .infinity)
            .frame(minHeight: max(0, proxy.size.height - 236), alignment: .center)
            .padding(.horizontal, 20)
            .padding(.top, 116)
            .padding(.bottom, 120)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .refreshable {
            await refreshCurrentGroup()
        }
    }

    private var feedSubtitle: String {
        if isFavouritesFilterEnabled, let selectedHashtag {
            return "Favourites in #\(selectedHashtag)"
        }
        if isFavouritesFilterEnabled {
            return "Favourites"
        }
        if let selectedHashtag {
            return "#\(selectedHashtag)"
        }
        return "\(currentGroupPhotos.count) photos"
    }

    private var emptyStateTitle: String {
        if isFavouritesFilterEnabled && selectedHashtag != nil {
            return "No favourite photos for this hashtag"
        }
        if isFavouritesFilterEnabled {
            return "No favourite photos yet"
        }
        if selectedHashtag != nil {
            return "No photos for this hashtag"
        }
        return "No photos yet"
    }

    private var emptyStateSymbol: String {
        if isFavouritesFilterEnabled {
            return "heart.slash"
        }
        if selectedHashtag != nil {
            return "number"
        }
        return "photo"
    }

    private var emptyStateDescription: String {
        if isFavouritesFilterEnabled && selectedHashtag != nil {
            return "Try another hashtag or turn off the favourites filter."
        }
        if isFavouritesFilterEnabled {
            return "Mark photos with the heart button to keep them close."
        }
        if selectedHashtag != nil {
            return "Try another hashtag or clear the filter."
        }
        return "Use the plus button to upload the first photo."
    }

    private func glassUnavailableView(title: String, systemImage: String, description: String) -> some View {
        ContentUnavailableView(
            title,
            systemImage: systemImage,
            description: Text(description)
        )
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
    }

    private func requestTrackingAuthorizationForAdsIfNeeded() {
        trackingAuthorizationStatus = ATTrackingManager.trackingAuthorizationStatus

        guard shouldShowFeedAds,
              scenePhase == .active,
              trackingAuthorizationStatus == .notDetermined,
              !hasStartedTrackingAuthorizationRequest else {
            return
        }

        hasStartedTrackingAuthorizationRequest = true

        Task { @MainActor in
            trackingAuthorizationStatus = await withCheckedContinuation { (
                continuation: CheckedContinuation<ATTrackingManager.AuthorizationStatus, Never>
            ) in
                ATTrackingManager.requestTrackingAuthorization { status in
                    continuation.resume(returning: status)
                }
            }
        }
    }

    @MainActor
    private func refreshCurrentGroup() async {
        selectedHashtag = nil
        await photoCollection.refresh(limit: feedPageSize)
    }

    private func deletePhoto(_ photo: FeedPhoto) async {
        guard !deletingPhotoIDs.contains(photo.id) else { return }
        guard let uid = currentUserID else {
            feedMessage = AppMessage(.pleaseSignInFirst, .error)
            return
        }

        deletingPhotoIDs.insert(photo.id)
        defer { deletingPhotoIDs.remove(photo.id) }

        do {
            try await feedService.deletePhoto(photo, requesterUID: uid)
            photoCollection.removePhoto(id: photo.id)
            if selectedPhotoID == photo.id {
                selectedPhotoID = nil
            }
            feedMessage = AppMessage(.photoDeleted, .success)
        } catch let error as FeedServiceError {
            feedMessage = AppMessage(error.appMessageID, .error)
        } catch {
            feedMessage = AppMessage(.failedToDeletePhoto, .error)
        }
    }

    private func toggleFavourite(_ photo: FeedPhoto) async {
        guard !favouritingPhotoIDs.contains(photo.id) else { return }
        favouritingPhotoIDs.insert(photo.id)
        defer { favouritingPhotoIDs.remove(photo.id) }

        let newValue = !photo.isFavourite
        do {
            guard let uid = currentUserID else {
                feedMessage = AppMessage(.pleaseSignInFirst, .error)
                return
            }
            try await feedService.setFavourite(photoID: photo.id, userID: uid, isFavourite: newValue)
            photoCollection.replacePhoto(photo.withFavourite(newValue))
            feedMessage = newValue ? AppMessage(.addedToFavourites, .success) : AppMessage(.removedFromFavourites, .success)
        } catch {
            feedMessage = AppMessage(.failedToUpdateFavourite, .error)
        }
    }

    private func scheduleFeedMessageAutoClear(for value: AppMessage?) {
        clearFeedMessageTask?.cancel()
        clearFeedMessageTask = AppMessageAutoClear.schedule(
            for: value,
            currentMessage: { feedMessage },
            clear: { feedMessage = nil }
        )
    }

    private func savePhotoEdits(photo: FeedPhoto, year: Int, hashtags: [String]) async -> Result<Void, FeedEditError> {
        guard !editingPhotoIDs.contains(photo.id) else { return .failure(FeedEditError(toastMessage: AppMessage(.photoAlreadyBeingUpdated, .error))) }
        guard let uid = currentUserID else {
            return .failure(FeedEditError(toastMessage: AppMessage(.pleaseSignInFirst, .error)))
        }

        editingPhotoIDs.insert(photo.id)
        defer { editingPhotoIDs.remove(photo.id) }

        do {
            try await feedService.updatePhotoMetadata(photo, requesterUID: uid, year: year, hashtags: hashtags)
            let updated = photo.withMetadata(year: year, hashtags: hashtags)
            photoCollection.replacePhoto(updated)
            feedMessage = AppMessage(.photoUpdated, .success)
            editingPhoto = nil
            return .success(())
        } catch let error as FeedServiceError {
            return .failure(FeedEditError(toastMessage: AppMessage(error.appMessageID, .error)))
        } catch {
            return .failure(FeedEditError(toastMessage: AppMessage(.failedToUpdatePhoto, .error)))
        }
    }
}
