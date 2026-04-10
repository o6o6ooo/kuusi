import FirebaseAuth
import SwiftUI
import UIKit

private struct FeedEditError: LocalizedError {
    let inlineMessage: InlineMessage

    var message: String { inlineMessage.text }
    var errorDescription: String? { inlineMessage.text }
}

@MainActor
struct FeedView: View {
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var photoCollection = PhotoCollectionViewModel()
    @StateObject private var profileViewModel = SettingsProfileViewModel()

    @State private var selectedHashtag: String?
    @State private var isUploadOverlayPresented = false
    @State private var isSettingsPresented = false
    @State private var isHashtagBarExpanded = false
    @State private var isFavouritesFilterEnabled = false
    @State private var selectedPhoto: FeedPhoto?
    @State private var feedMessage: InlineMessage?
    @State private var deletingPhotoIDs: Set<String> = []
    @State private var favouritingPhotoIDs: Set<String> = []
    @State private var editingPhotoIDs: Set<String> = []
    @State private var pendingDeletePhoto: FeedPhoto?
    @State private var editingPhoto: FeedPhoto?
    @State private var clearFeedMessageTask: Task<Void, Never>?

    private let feedService = FeedService()

    private var currentGroupPhotos: [FeedPhoto] {
        photoCollection.currentGroupPhotos
    }

    private var currentGroupName: String {
        photoCollection.groups.first(where: { $0.id == photoCollection.selectedGroupID })?.name ?? "Feed"
    }

    private var availableHashtags: [String] {
        var seen = Set<String>()
        var ordered: [String] = []
        for photo in currentGroupPhotos {
            for hashtag in photo.hashtags {
                let trimmed = hashtag.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { continue }
                let normalized = trimmed.lowercased()
                guard seen.insert(normalized).inserted else { continue }
                ordered.append(trimmed)
            }
        }
        return ordered
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

                    topChrome(topInset: proxy.safeAreaInsets.top)

                    VStack {
                        Spacer()
                        bottomChrome
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
                              photoCollection.errorMessage == nil,
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
                    await photoCollection.loadInitial(limit: 6)
                }
                if profileViewModel.name.isEmpty {
                    await profileViewModel.loadProfile()
                }
            }
            .onChange(of: feedMessage) { _, newValue in
                scheduleFeedMessageAutoClear(for: newValue)
            }
            .sheet(isPresented: $isUploadOverlayPresented) {
                UploadOverlayView()
                    .presentationDetents([.fraction(0.68), .large])
                    .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $isSettingsPresented, onDismiss: {
                Task { await profileViewModel.loadProfile() }
            }) {
                SettingsView()
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
            .sheet(item: $selectedPhoto) { photo in
                PhotoPreviewOverlayView(photo: photo)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
            .sheet(item: $editingPhoto) { photo in
                FeedEditSheet(photo: photo) { year, hashtags in
                    await savePhotoEdits(photo: photo, year: year, hashtags: hashtags)
                }
                .presentationDetents([.height(330)])
                .presentationDragIndicator(.visible)
            }
            .alert("Delete photo?", isPresented: Binding(
                get: { pendingDeletePhoto != nil },
                set: { isPresented in
                    if !isPresented {
                        pendingDeletePhoto = nil
                    }
                }
            )) {
                Button("Delete", role: .destructive) {
                    guard let photo = pendingDeletePhoto else { return }
                    pendingDeletePhoto = nil
                    Task {
                        await deletePhoto(photo)
                    }
                }
                Button("Cancel", role: .cancel) {
                    pendingDeletePhoto = nil
                }
            } message: {
                Text("This will permanently delete the photo.")
            }
            .onDisappear {
                clearFeedMessageTask?.cancel()
                clearFeedMessageTask = nil
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
        } else if let errorMessage = photoCollection.errorMessage {
            emptyFeedState(
                in: proxy,
                title: "Failed to load feed",
                systemImage: "exclamationmark.triangle",
                description: errorMessage
            )
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
                measuredAspectRatios: photoCollection.measuredAspectRatios,
                onTap: { selectedPhoto = $0 },
                onRequireAspectRatio: photoCollection.requestAspectRatioIfNeeded
            ) { photo, columnWidth, displayAspectRatio, onTap, onRequireAspectRatio in
                PhotoTile(
                    photo: photo,
                    width: columnWidth,
                    displayAspectRatio: displayAspectRatio,
                    onTap: onTap,
                    onEdit: { editingPhoto = photo },
                    onDelete: {
                        pendingDeletePhoto = photo
                    },
                    onToggleFavourite: {
                        Task { await toggleFavourite(photo) }
                    },
                    onRequireAspectRatio: onRequireAspectRatio,
                    isDeleting: deletingPhotoIDs.contains(photo.id),
                    isFavouriting: favouritingPhotoIDs.contains(photo.id),
                    isEditing: editingPhotoIDs.contains(photo.id)
                )
            } footer: {
                if let feedMessage {
                    InlineMessageView(message: feedMessage)
                        .padding(.horizontal, 16)
                        .padding(.top, 10)
                        .padding(.bottom, 12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .refreshable {
                await refreshCurrentGroup()
                await profileViewModel.loadProfile()
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
            await profileViewModel.loadProfile()
        }
    }

    private func topChrome(topInset: CGFloat) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(currentGroupName)
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(feedSubtitle)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 12)

            HStack(spacing: 10) {
                if !photoCollection.groups.isEmpty {
                    roundChromeButton(
                        systemName: "plus",
                        isSelected: false,
                        accessibilityIdentifier: "feed-upload-button"
                    ) {
                        isUploadOverlayPresented = true
                    }

                    roundChromeButton(
                        systemName: isFavouritesFilterEnabled ? "heart.fill" : "heart",
                        isSelected: isFavouritesFilterEnabled,
                        accessibilityIdentifier: "feed-favourites-filter-button"
                    ) {
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.84)) {
                            isFavouritesFilterEnabled.toggle()
                        }
                    }
                }

                Button {
                    isSettingsPresented = true
                } label: {
                    avatarBadge
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("feed-settings-button")
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, max(0, topInset - 24))
    }

    private var bottomChrome: some View {
        HStack(alignment: .bottom, spacing: 12) {
            if !photoCollection.groups.isEmpty {
                Menu {
                    ForEach(photoCollection.groups) { group in
                        Button(group.name) {
                            withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                                selectedHashtag = nil
                                photoCollection.selectGroup(group.id, limit: 6)
                            }
                        }
                    }
                } label: {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .frame(width: 54, height: 54)
                        .background(glassCircleBackground)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("feed-group-button")
            }

            Spacer(minLength: 0)

            if !availableHashtags.isEmpty {
                hashtagBar
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 10)
        .padding(.bottom, 6)
        .background(.clear)
    }

    private var hashtagBar: some View {
        HStack(spacing: 10) {
            Button {
                withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
                    isHashtagBarExpanded.toggle()
                }
            } label: {
                Image(systemName: "number")
                    .font(.system(size: 18, weight: .bold))
                    .frame(width: 54, height: 54)
                    .background(glassCircleBackground)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("feed-hashtag-toggle-button")

            if isHashtagBarExpanded {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        hashtagChip(
                            title: "All",
                            isSelected: selectedHashtag == nil,
                            action: { selectedHashtag = nil }
                        )

                        ForEach(availableHashtags, id: \.self) { hashtag in
                            hashtagChip(
                                title: "#\(hashtag)",
                                isSelected: selectedHashtag == hashtag,
                                action: { selectedHashtag = hashtag }
                            )
                        }
                    }
                    .padding(.horizontal, 8)
                }
                .frame(height: 54)
                .frame(maxWidth: 280)
                .padding(.horizontal, 6)
                .background(
                    RoundedRectangle(cornerRadius: 27, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 27, style: .continuous)
                                .strokeBorder(Color.white.opacity(colorScheme == .dark ? 0.14 : 0.4), lineWidth: 1)
                        )
                )
                .shadow(color: .black.opacity(colorScheme == .dark ? 0.28 : 0.08), radius: 18, x: 0, y: 8)
            }
        }
    }

    private func hashtagChip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isSelected ? .primary : .secondary)
                .lineLimit(1)
                .padding(.horizontal, 14)
                .frame(height: 38)
                .background(
                    Capsule()
                        .fill(isSelected ? Color.white.opacity(colorScheme == .dark ? 0.14 : 0.92) : Color.clear)
                )
                .overlay {
                    Capsule()
                        .strokeBorder(Color.clear, lineWidth: 0)
                }
        }
        .buttonStyle(.plain)
    }

    private func roundChromeButton(
        systemName: String,
        isSelected: Bool,
        accessibilityIdentifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(isSelected ? Color.white : .primary)
                .frame(width: 54, height: 54)
                .background(
                    Circle()
                        .fill(isSelected ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.ultraThinMaterial))
                        .overlay(
                            Circle()
                                .strokeBorder(Color.white.opacity(isSelected ? 0.18 : 0.42), lineWidth: 1)
                        )
                )
                .shadow(color: .black.opacity(colorScheme == .dark ? 0.28 : 0.08), radius: 18, x: 0, y: 8)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(accessibilityIdentifier)
    }

    private var avatarBadge: some View {
        ZStack {
            Circle()
                .fill(Color(hex: profileViewModel.bgColour))

            Text(profileViewModel.icon)
                .font(.system(size: 26))
        }
        .frame(width: 54, height: 54)
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.28 : 0.08), radius: 18, x: 0, y: 8)
    }

    private var glassCircleBackground: some View {
        Circle()
            .fill(.ultraThinMaterial)
            .overlay(
                Circle()
                    .strokeBorder(Color.white.opacity(colorScheme == .dark ? 0.16 : 0.42), lineWidth: 1)
            )
            .shadow(color: .black.opacity(colorScheme == .dark ? 0.28 : 0.08), radius: 18, x: 0, y: 8)
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

    @MainActor
    private func refreshCurrentGroup() async {
        selectedHashtag = nil
        await photoCollection.refresh(limit: 6)
    }

    private func deletePhoto(_ photo: FeedPhoto) async {
        guard !deletingPhotoIDs.contains(photo.id) else { return }
        guard let uid = Auth.auth().currentUser?.uid else {
            feedMessage = .error("Please sign in first.")
            return
        }

        deletingPhotoIDs.insert(photo.id)
        defer { deletingPhotoIDs.remove(photo.id) }

        do {
            try await feedService.deletePhoto(photo, requesterUID: uid)
            photoCollection.removePhoto(id: photo.id)
            photoCollection.clearMeasuredAspectRatio(for: photo.id)
            if selectedPhoto?.id == photo.id {
                selectedPhoto = nil
            }
            feedMessage = .success("Photo deleted.")
        } catch {
            feedMessage = .error(error.localizedDescription)
        }
    }

    private func toggleFavourite(_ photo: FeedPhoto) async {
        guard !favouritingPhotoIDs.contains(photo.id) else { return }
        favouritingPhotoIDs.insert(photo.id)
        defer { favouritingPhotoIDs.remove(photo.id) }

        let newValue = !photo.isFavourite
        do {
            guard let uid = Auth.auth().currentUser?.uid else {
                feedMessage = .error("Please sign in first.")
                return
            }
            try await feedService.setFavourite(photoID: photo.id, userID: uid, isFavourite: newValue)
            photoCollection.replacePhoto(photo.withFavourite(newValue))
            feedMessage = .success(newValue ? "Added to favourites." : "Removed from favourites.")
        } catch {
            feedMessage = .error(error.localizedDescription)
        }
    }

    private func scheduleFeedMessageAutoClear(for value: InlineMessage?) {
        clearFeedMessageTask?.cancel()
        clearFeedMessageTask = InlineMessageAutoClear.schedule(
            for: value,
            currentMessage: { feedMessage },
            clear: { feedMessage = nil }
        )
    }

    private func savePhotoEdits(photo: FeedPhoto, year: Int, hashtags: [String]) async -> Result<Void, FeedEditError> {
        guard !editingPhotoIDs.contains(photo.id) else { return .failure(FeedEditError(inlineMessage: .error("Photo is already being updated."))) }
        guard let uid = Auth.auth().currentUser?.uid else {
            return .failure(FeedEditError(inlineMessage: .error("Please sign in first.")))
        }

        editingPhotoIDs.insert(photo.id)
        defer { editingPhotoIDs.remove(photo.id) }

        do {
            try await feedService.updatePhotoMetadata(photo, requesterUID: uid, year: year, hashtags: hashtags)
            let updated = photo.withMetadata(year: year, hashtags: hashtags)
            photoCollection.replacePhoto(updated)
            if selectedPhoto?.id == photo.id {
                selectedPhoto = updated
            }
            editingPhoto = nil
            return .success(())
        } catch {
            return .failure(FeedEditError(inlineMessage: .error(error.localizedDescription)))
        }
    }
}

private struct PhotoTile: View {
    @Environment(\.colorScheme) private var colorScheme

    let photo: FeedPhoto
    let width: CGFloat
    let displayAspectRatio: CGFloat
    let onTap: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onToggleFavourite: () -> Void
    let onRequireAspectRatio: () -> Void
    let isDeleting: Bool
    let isFavouriting: Bool
    let isEditing: Bool

    var body: some View {
        let ratio = max(displayAspectRatio, 0.35)

        AsyncImage(url: URL(string: photo.thumbnailURL ?? photo.photoURL ?? "")) { image in
            image
                .resizable()
                .scaledToFill()
        } placeholder: {
            Rectangle()
                .fill(Color.gray.opacity(colorScheme == .dark ? 0.25 : 0.15))
                .overlay(ProgressView())
        }
        .frame(width: width, height: width / ratio)
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(alignment: .topTrailing) {
            if photo.isFavourite {
                Image(systemName: "heart.fill")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.18), radius: 6, x: 0, y: 2)
                    .padding(12)
            }
        }
        .overlay {
            if isDeleting || isEditing {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(.ultraThinMaterial)
                    ProgressView()
                }
            }
        }
        .onTapGesture {
            onTap()
        }
        .contextMenu {
            Button {
                onEdit()
            } label: {
                Label("Edit", systemImage: "pencil")
            }

            Button {
                onToggleFavourite()
            } label: {
                Label(
                    photo.isFavourite ? "Remove from favourites" : "Add to favourites",
                    systemImage: photo.isFavourite ? "heart.slash" : "heart"
                )
            }

            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
        .disabled(isDeleting || isEditing)
        .task {
            onRequireAspectRatio()
        }
    }
}

private struct FeedEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    let photo: FeedPhoto
    let onSave: @MainActor (_ year: Int, _ hashtags: [String]) async -> Result<Void, FeedEditError>

    @State private var yearText: String
    @State private var hashtagInput = ""
    @State private var hashtags: [String]
    @State private var inlineMessage: InlineMessage?
    @State private var isSaving = false
    @State private var clearErrorTask: Task<Void, Never>?

    init(photo: FeedPhoto, onSave: @escaping @MainActor (_ year: Int, _ hashtags: [String]) async -> Result<Void, FeedEditError>) {
        self.photo = photo
        self.onSave = onSave
        _yearText = State(initialValue: photo.year.map(String.init) ?? "")
        _hashtags = State(initialValue: photo.hashtags)
    }

    private var cardBackground: Color { AppTheme.cardBackground(for: colorScheme) }
    private var fieldBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.08) : Color.white.opacity(0.85)
    }
    private var primaryText: Color { AppTheme.primaryText(for: colorScheme) }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Spacer()
                    Button("Save") {
                        Task {
                            await save()
                        }
                    }
                    .buttonStyle(.appPrimaryCapsule)
                    .disabled(isSaving)
                }

                VStack(spacing: 12) {
                    yearField
                    hashtagsField
                }
                .padding(14)
                .background(cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 20))

                if !hashtags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(hashtags, id: \.self) { tag in
                                HStack(spacing: 6) {
                                    Image(systemName: "xmark")
                                        .font(.caption.weight(.medium))
                                    Text(tag)
                                        .font(.subheadline.weight(.semibold))
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(Color.accentColor)
                                .foregroundStyle(.white)
                                .clipShape(Capsule())
                                .onTapGesture {
                                    hashtags.removeAll { $0 == tag }
                                }
                            }
                        }
                    }
                }

                if let inlineMessage {
                    InlineMessageView(message: inlineMessage)
                }

                Spacer()
            }
            .padding(16)
            .appOverlayTheme()
            .toolbar(.hidden, for: .navigationBar)
            .onDisappear {
                clearErrorTask?.cancel()
                clearErrorTask = nil
            }
        }
    }

    private var yearField: some View {
        TextField("year", text: $yearText)
            .keyboardType(.numberPad)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled(true)
            .padding(.horizontal, 16)
            .frame(height: 62)
            .background(fieldBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .foregroundStyle(primaryText)
    }

    private var hashtagsField: some View {
        TextField("hashtags", text: $hashtagInput)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled(true)
            .padding(.horizontal, 16)
            .frame(height: 62)
            .background(fieldBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .foregroundStyle(primaryText)
            .onSubmit {
                addHashtagsFromInput()
            }
            .onChange(of: hashtagInput) { _, newValue in
                if newValue.contains("\n") || newValue.contains(",") {
                    addHashtagsFromInput()
                }
            }
    }

    private func addHashtagsFromInput() {
        let separators = CharacterSet(charactersIn: ",\n\t ")
        let tokens = hashtagInput
            .components(separatedBy: separators)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .map { token -> String in
                let clean = token.hasPrefix("#") ? String(token.dropFirst()) : token
                return clean.lowercased()
            }

        for token in tokens where !hashtags.contains(token) {
            hashtags.append(token)
        }
        hashtagInput = ""
    }

    @MainActor
    private func save() async {
        let trimmedYear = yearText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let year = Int(trimmedYear), (1900...3000).contains(year) else {
            showInlineMessage(.error("Enter a valid year."))
            return
        }

        isSaving = true
        defer { isSaving = false }

        switch await onSave(year, hashtags) {
        case .success:
            dismiss()
        case .failure(let error):
            showInlineMessage(error.inlineMessage)
        }
    }

    private func showInlineMessage(_ message: InlineMessage) {
        clearErrorTask?.cancel()
        inlineMessage = message
        clearErrorTask = InlineMessageAutoClear.schedule(
            for: message,
            currentMessage: { inlineMessage },
            clear: { inlineMessage = nil }
        )
    }
}
