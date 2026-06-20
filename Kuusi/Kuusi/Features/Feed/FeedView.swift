import AppTrackingTransparency
import FirebaseAuth
import SwiftUI

enum FeedAdRules {
    static func shouldShowFeedAds(isPremiumActive: Bool) -> Bool {
        !isPremiumActive
    }

    static func canLoadFeedAds(isPremiumActive: Bool, canRequestAds: Bool) -> Bool {
        shouldShowFeedAds(isPremiumActive: isPremiumActive) && canRequestAds
    }

    static func shouldRequestTrackingAuthorization(
        isPremiumActive: Bool,
        scenePhase: ScenePhase,
        trackingAuthorizationStatus: ATTrackingManager.AuthorizationStatus,
        hasStartedTrackingAuthorizationRequest: Bool
    ) -> Bool {
        shouldShowFeedAds(isPremiumActive: isPremiumActive)
        && scenePhase == .active
        && trackingAuthorizationStatus == .notDetermined
        && !hasStartedTrackingAuthorizationRequest
    }

    static func shouldGatherConsent(
        isPremiumActive: Bool,
        scenePhase: ScenePhase
    ) -> Bool {
        shouldShowFeedAds(isPremiumActive: isPremiumActive) && scenePhase == .active
    }
}

private extension FeedServiceError {
    var appMessageID: AppMessage.ID {
        switch self {
        case .cannotDeleteOthersPhotos:
            return .cannotDeleteOthersPhotos
        }
    }
}

@MainActor
struct FeedView: View {
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var consentStore: ConsentStore
    @EnvironmentObject private var groupStore: GroupStore
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
    @State private var hiddenInlineAdPhotoIDs: Set<String> = []

    private let feedService = FeedService()
    private var currentGroupPhotos: [FeedPhoto] {
        photoCollection.currentGroupPhotos
    }

    private var currentGroupName: String {
        groupStore.groups.first(where: { $0.id == groupStore.selectedGroupID })?.name ?? "Feed"
    }

    private var groupStoreSignature: [String] {
        groupStore.groups.map { "\($0.id)-\($0.name)-\($0.totalMemberCount)" }
    }

    private var availableHashtags: [String] {
        photoCollection.currentGroupAvailableHashtags
    }

    private var currentUserID: String? {
#if DEBUG
        UITestEnvironment.currentUserID ?? Auth.auth().currentUser?.uid
#else
        Auth.auth().currentUser?.uid
#endif
    }

    private var feedPageSize: Int {
        UIDevice.current.userInterfaceIdiom == .pad ? 24 : 18
    }

    private var uploadOverlayDetents: Set<PresentationDetent> {
        UIDevice.current.userInterfaceIdiom == .pad ? [.fraction(0.80)] : [.fraction(0.60)]
    }

    private var shouldShowFeedAds: Bool {
        FeedAdRules.shouldShowFeedAds(isPremiumActive: subscriptionStore.isPremiumActive)
    }

    private var canLoadFeedAds: Bool {
        FeedAdRules.canLoadFeedAds(
            isPremiumActive: subscriptionStore.isPremiumActive,
            canRequestAds: consentStore.canRequestAds
        )
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
                        hasGroups: !groupStore.groups.isEmpty,
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
                            groups: groupStore.groups,
                            availableHashtags: availableHashtags,
                            selectedHashtag: $selectedHashtag,
                            isHashtagBarExpanded: $isHashtagBarExpanded,
                            onSelectGroup: { groupID in
                                withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                                    selectedHashtag = nil
                                    hiddenInlineAdPhotoIDs.removeAll()
                                    groupStore.selectedGroupID = groupID
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

                    if groupStore.groups.isEmpty {
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
                await loadGroupsAndPhotosIfNeeded()
                if profileViewModel.name.isEmpty {
                    await profileViewModel.loadProfile()
                }
                await gatherAdConsentIfNeeded()
                requestTrackingAuthorizationForAdsIfNeeded()
            }
            .onChange(of: scenePhase) { _, _ in
                Task {
                    await gatherAdConsentIfNeeded()
                }
                requestTrackingAuthorizationForAdsIfNeeded()
            }
            .onChange(of: subscriptionStore.isPremiumActive) { _, _ in
                Task {
                    await gatherAdConsentIfNeeded()
                }
                requestTrackingAuthorizationForAdsIfNeeded()
            }
            .onChange(of: groupStoreSignature) { _, _ in
                syncPhotoCollectionGroups()
            }
            .onChange(of: groupStore.selectedGroupID) { _, newValue in
                syncPhotoCollectionGroups()
                guard let newValue else { return }
                guard !isSettingsPresented else { return }
                selectedHashtag = nil
                hiddenInlineAdPhotoIDs.removeAll()
                photoCollection.selectGroup(newValue, limit: feedPageSize)
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
                    isPremiumActive: subscriptionStore.isPremiumActive,
                    onUploadCompleted: { uploadedPhotos in
                        profileViewModel.addUploadedUsage(uploadedPhotos.reduce(0) { $0 + ($1.sizeMB ?? 0) })
                        if let uploadedGroupID = uploadedPhotos.first?.groupID {
                            selectedHashtag = nil
                            hiddenInlineAdPhotoIDs.removeAll()
                            groupStore.selectedGroupID = uploadedGroupID
                            photoCollection.selectedGroupID = uploadedGroupID
                            photoCollection.replaceWithUploadedPhotosPendingReload(uploadedPhotos)
                            Task {
                                await photoCollection.reloadPhotosFromSource(limit: feedPageSize)
                            }
                        } else {
                            photoCollection.replaceWithUploadedPhotosPendingReload(uploadedPhotos)
                        }
                    }
                )
                    .presentationDetents(uploadOverlayDetents)
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $isSettingsPresented, onDismiss: {
                syncPhotoCollectionGroups()
                if let selectedGroupID = groupStore.selectedGroupID {
                    photoCollection.selectGroup(selectedGroupID, limit: feedPageSize)
                }
                Task { await profileViewModel.loadProfile() }
            }) {
                SettingsView()
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
            .sheet(item: $editingPhoto) { photo in
                EditOverlayView(photo: photo) { update in
                    await savePhotoEdits(photo: photo, update: update)
                }
                .presentationDetents([.height(editOverlayHeight)])
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
        if groupStore.groups.isEmpty {
            emptyFeedState(
                in: proxy,
                title: String(localized: "feed.empty.no_groups.title"),
                systemImage: "person.3",
                description: String(localized: "feed.empty.no_groups.description")
            )
        } else if photoCollection.isLoading {
            ProgressView("feed.loading")
                .font(.headline.weight(.semibold))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                .padding(.top, 116)
                .padding(.bottom, 120)
        } else if currentGroupPhotos.isEmpty {
            emptyFeedState(
                in: proxy,
                title: String(localized: "feed.empty.no_photos.title"),
                systemImage: "photo",
                description: String(localized: "feed.empty.no_photos.description")
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
                showsInlineAds: canLoadFeedAds,
                hiddenInlineAdPhotoIDs: hiddenInlineAdPhotoIDs,
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
            } inlineAd: { photo, width in
                FeedNativeAdTileView(width: width, canLoadAds: canLoadFeedAds) {
                    hiddenInlineAdPhotoIDs.insert(photo.id)
                }
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
            return String(format: String(localized: "feed.subtitle.favourites_in_hashtag"), selectedHashtag)
        }
        if isFavouritesFilterEnabled {
            return String(localized: "feed.subtitle.favourites")
        }
        if let selectedHashtag {
            return "#\(selectedHashtag)"
        }
        return String(format: String(localized: "feed.subtitle.photo_count"), photoCollection.currentGroupPhotoCount)
    }

    private var emptyStateTitle: String {
        if isFavouritesFilterEnabled && selectedHashtag != nil {
            return String(localized: "feed.empty.no_favourites_for_hashtag.title")
        }
        if isFavouritesFilterEnabled {
            return String(localized: "feed.empty.no_favourites.title")
        }
        if selectedHashtag != nil {
            return String(localized: "feed.empty.no_photos_for_hashtag.title")
        }
        return String(localized: "feed.empty.no_photos.title")
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
            return String(localized: "feed.empty.no_favourites_for_hashtag.description")
        }
        if isFavouritesFilterEnabled {
            return String(localized: "feed.empty.no_favourites.description")
        }
        if selectedHashtag != nil {
            return String(localized: "feed.empty.no_photos_for_hashtag.description")
        }
        return String(localized: "feed.empty.no_photos.description")
    }

    private func glassUnavailableView(title: String, systemImage: String, description: String) -> some View {
        ContentUnavailableView(
            title,
            systemImage: systemImage,
            description: Text(description)
        )
        .accessibilityIdentifier("feed-empty-state")
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
    }

    private func requestTrackingAuthorizationForAdsIfNeeded() {
        trackingAuthorizationStatus = ATTrackingManager.trackingAuthorizationStatus

        guard FeedAdRules.shouldRequestTrackingAuthorization(
            isPremiumActive: subscriptionStore.isPremiumActive,
            scenePhase: scenePhase,
            trackingAuthorizationStatus: trackingAuthorizationStatus,
            hasStartedTrackingAuthorizationRequest: hasStartedTrackingAuthorizationRequest
        ) else {
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

    private func gatherAdConsentIfNeeded() async {
        guard FeedAdRules.shouldGatherConsent(
            isPremiumActive: subscriptionStore.isPremiumActive,
            scenePhase: scenePhase
        ) else { return }
        await consentStore.gatherConsentIfNeeded()
    }

    @MainActor
    private func refreshCurrentGroup() async {
        selectedHashtag = nil
        hiddenInlineAdPhotoIDs.removeAll()
        await photoCollection.refreshPhotos(limit: feedPageSize)
    }

    @MainActor
    private func loadGroupsAndPhotosIfNeeded() async {
        do {
            try await groupStore.loadCachedThenFetchIfNeeded()
        } catch {
            photoCollection.errorMessageID = .failedToLoadGroups
            return
        }

        photoCollection.syncGroups(groupStore.groups, selectedGroupID: groupStore.selectedGroupID)
        await photoCollection.loadInitial(
            groups: groupStore.groups,
            selectedGroupID: groupStore.selectedGroupID,
            limit: feedPageSize
        )
    }

    @MainActor
    private func syncPhotoCollectionGroups() {
        photoCollection.syncGroups(groupStore.groups, selectedGroupID: groupStore.selectedGroupID)
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

    private var editOverlayHeight: CGFloat {
        #if DEBUG
        480
        #else
        405
        #endif
    }

    private func savePhotoEdits(photo: FeedPhoto, update: FeedPhotoMetadataUpdate) async -> Result<Void, FeedEditError> {
        guard !editingPhotoIDs.contains(photo.id) else { return .failure(FeedEditError(toastMessage: AppMessage(.photoAlreadyBeingUpdated, .error))) }
        guard currentUserID != nil else {
            return .failure(FeedEditError(toastMessage: AppMessage(.pleaseSignInFirst, .error)))
        }

        editingPhotoIDs.insert(photo.id)
        defer { editingPhotoIDs.remove(photo.id) }

        do {
            try await feedService.updatePhotoMetadata(photo, update: update)
            let updated = photo.withMetadata(update)
            photoCollection.replacePhoto(updated)
            feedMessage = AppMessage(.photoUpdated, .success)
            editingPhoto = nil
            return .success(())
        } catch {
            return .failure(FeedEditError(toastMessage: AppMessage(.failedToUpdatePhoto, .error)))
        }
    }
}
