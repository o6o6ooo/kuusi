import FirebaseAuth
import SwiftUI
import UIKit

private struct FeedEditError: LocalizedError {
    let message: String

    var errorDescription: String? { message }
}

@MainActor
struct FeedView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var photos: [FeedPhoto] = []
    @State private var groups: [GroupSummary] = []
    @State private var selectedGroupID: String?
    @State private var selectedHashtag: String?
    @State private var photosByGroupID: [String: [FeedPhoto]] = [:]
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var isUploadOverlayPresented = false
    @State private var selectedPhoto: FeedPhoto?
    @State private var feedMessage: String?
    @State private var measuredAspectRatios: [String: CGFloat] = [:]
    @State private var measuringAspectRatioIDs: Set<String> = []
    @State private var deletingPhotoIDs: Set<String> = []
    @State private var favouritingPhotoIDs: Set<String> = []
    @State private var editingPhotoIDs: Set<String> = []
    @State private var pendingDeletePhoto: FeedPhoto?
    @State private var editingPhoto: FeedPhoto?

    private let feedService = FeedService()
    private let groupService = GroupService()
    private var accentColor: Color { AppTheme.accent(for: colorScheme) }
    private var currentGroupPhotos: [FeedPhoto] {
        guard let selectedGroupID else { return photos }
        return photosByGroupID[selectedGroupID] ?? photos
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
        guard let selectedHashtag else { return photos }
        return photos.filter { photo in
            photo.hashtags.contains { $0.caseInsensitiveCompare(selectedHashtag) == .orderedSame }
        }
    }

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                VStack(spacing: 8) {
                    if groups.isEmpty {
                        ContentUnavailableView("No groups yet", systemImage: "person.3")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        feedGroupTabs
                        if !availableHashtags.isEmpty {
                            feedHashtagTabs
                        }

                        if isLoading {
                            ProgressView("Loading feed...")
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                        } else if let errorMessage {
                            ContentUnavailableView("Failed to load feed", systemImage: "exclamationmark.triangle", description: Text(errorMessage))
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else if currentGroupPhotos.isEmpty {
                            ContentUnavailableView("No photos yet", systemImage: "photo")
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else if displayedPhotos.isEmpty {
                            ContentUnavailableView("No photos for this hashtag", systemImage: "number")
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else {
                            PhotoGridView(
                                photos: displayedPhotos,
                                availableWidth: proxy.size.width,
                                measuredAspectRatios: measuredAspectRatios,
                                onTap: { selectedPhoto = $0 },
                                onRequireAspectRatio: requestAspectRatioIfNeeded
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
                                    Text(feedMessage)
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                        .padding(.top, 4)
                                        .padding(.bottom, 8)
                                }
                            }
                            .refreshable {
                                await refreshCurrentGroup()
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .screenTheme()
            .toolbar(.hidden, for: .navigationBar)
            .overlay(alignment: .topLeading) {
                Button {
                    isUploadOverlayPresented = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(AppTheme.primaryText(for: colorScheme))
                        .padding(10)
                        .background(.ultraThinMaterial, in: Circle())
                }
                .buttonStyle(.plain)
                .padding(.top, 6)
                .padding(.leading, 14)
            }
            .task {
                if groups.isEmpty {
                    await loadInitialFeed()
                }
            }
            .sheet(isPresented: $isUploadOverlayPresented) {
                UploadOverlayView()
                    .presentationDetents([.fraction(0.68), .large])
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
        }
    }

    private var feedGroupTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 10) {
                ForEach(groups) { group in
                    let isSelected = selectedGroupID == group.id
                    Button(group.name) {
                        selectGroup(group.id)
                    }
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(isSelected ? Color.white : accentColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    .padding(.horizontal, 14)
                    .frame(height: 34)
                    .background(
                        Capsule()
                            .fill(isSelected ? accentColor : Color.clear)
                    )
                    .overlay {
                        Capsule()
                            .strokeBorder(accentColor, lineWidth: 1)
                    }
                    .buttonStyle(.plain)
                }
            }
            .fixedSize(horizontal: true, vertical: false)
            .padding(.leading, 66)
            .padding(.trailing, 12)
            .padding(.top, 8)
            .padding(.bottom, 2)
        }
        .frame(height: 52)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var feedHashtagTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 8) {
                Button("All") {
                    selectedHashtag = nil
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(selectedHashtag == nil ? Color.white : accentColor)
                .lineLimit(1)
                .padding(.horizontal, 12)
                .frame(height: 30)
                .background(
                    Capsule()
                        .fill(selectedHashtag == nil ? accentColor : Color.clear)
                )
                .overlay {
                    Capsule()
                        .strokeBorder(accentColor, lineWidth: 1)
                }
                .buttonStyle(.plain)

                ForEach(availableHashtags, id: \.self) { hashtag in
                    let isSelected = selectedHashtag == hashtag
                    Button("#\(hashtag)") {
                        selectedHashtag = hashtag
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(isSelected ? Color.white : accentColor)
                    .lineLimit(1)
                    .padding(.horizontal, 12)
                    .frame(height: 30)
                    .background(
                        Capsule()
                            .fill(isSelected ? accentColor : Color.clear)
                    )
                    .overlay {
                        Capsule()
                            .strokeBorder(accentColor, lineWidth: 1)
                    }
                    .buttonStyle(.plain)
                }
            }
            .fixedSize(horizontal: true, vertical: false)
            .padding(.leading, 12)
            .padding(.trailing, 12)
        }
        .frame(height: 38)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @MainActor
    private func loadInitialFeed() async {
        guard let uid = Auth.auth().currentUser?.uid else {
            groups = []
            photos = []
            selectedGroupID = nil
            photosByGroupID = [:]
            errorMessage = nil
            return
        }

        var cachedGroups = groupService.cachedGroups(for: uid)
        if cachedGroups.isEmpty {
            do {
                cachedGroups = try await groupService.fetchGroups(for: uid)
            } catch {
                groups = []
                photos = []
                selectedGroupID = nil
                photosByGroupID = [:]
                errorMessage = error.localizedDescription
                return
            }
        }

        groups = cachedGroups
        selectedGroupID = cachedGroups.first?.id
        selectedHashtag = nil
        photos = []
        errorMessage = nil
        await fetchPhotosForSelectedGroup(forceReload: false)
    }

    @MainActor
    private func refreshCurrentGroup() async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        do {
            let freshGroups = try await groupService.fetchGroups(for: uid)
            groups = freshGroups
            if let selectedGroupID, freshGroups.contains(where: { $0.id == selectedGroupID }) {
                self.selectedGroupID = selectedGroupID
            } else {
                selectedGroupID = freshGroups.first?.id
                photos = []
            }
            selectedHashtag = nil
            await fetchPhotosForSelectedGroup(forceReload: true)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func fetchPhotosForSelectedGroup(forceReload: Bool) async {
        isLoading = true
        defer { isLoading = false }
        do {
            guard let uid = Auth.auth().currentUser?.uid else {
                photos = []
                errorMessage = nil
                return
            }
            guard let selectedGroupID else {
                photos = []
                errorMessage = nil
                return
            }

            if !forceReload, let cachedPhotos = photosByGroupID[selectedGroupID] {
                photos = cachedPhotos
                errorMessage = nil
                return
            }

            let loadedPhotos = try await feedService.fetchRecentPhotos(
                userID: uid,
                groupIDs: [selectedGroupID],
                limit: 6
            )
            photosByGroupID[selectedGroupID] = loadedPhotos
            photos = loadedPhotos
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func selectGroup(_ groupID: String) {
        selectedGroupID = groupID
        selectedHashtag = nil
        photos = photosByGroupID[groupID] ?? []
        errorMessage = nil
        Task {
            await fetchPhotosForSelectedGroup(forceReload: false)
        }
    }

    private func requestAspectRatioIfNeeded(for photo: FeedPhoto) {
        // TODO: Remove this fallback after all legacy photos have aspect_ratio.
        if photo.aspectRatio != nil { return }
        if measuredAspectRatios[photo.id] != nil { return }
        if measuringAspectRatioIDs.contains(photo.id) { return }
        guard let urlString = photo.thumbnailURL ?? photo.photoURL else { return }

        measuringAspectRatioIDs.insert(photo.id)
        Task {
            let ratio = await measureAspectRatio(from: urlString)
            measuringAspectRatioIDs.remove(photo.id)
            guard let ratio else { return }
            measuredAspectRatios[photo.id] = ratio
        }
    }

    nonisolated private func measureAspectRatio(from urlString: String) async -> CGFloat? {
        guard let url = URL(string: urlString) else { return nil }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let image = UIImage(data: data), image.size.height > 0 else { return nil }
            return CGFloat(image.size.width / image.size.height)
        } catch {
            return nil
        }
    }

    private func deletePhoto(_ photo: FeedPhoto) async {
        guard !deletingPhotoIDs.contains(photo.id) else { return }
        guard let uid = Auth.auth().currentUser?.uid else {
            feedMessage = "Please sign in first."
            return
        }

        deletingPhotoIDs.insert(photo.id)
        defer { deletingPhotoIDs.remove(photo.id) }

        do {
            try await feedService.deletePhoto(photo, requesterUID: uid)
            photos.removeAll { $0.id == photo.id }
            if let selectedGroupID {
                photosByGroupID[selectedGroupID] = photos
            }
            measuredAspectRatios[photo.id] = nil
            if selectedPhoto?.id == photo.id {
                selectedPhoto = nil
            }
            feedMessage = "Photo deleted."
        } catch {
            feedMessage = error.localizedDescription
        }
    }

    private func toggleFavourite(_ photo: FeedPhoto) async {
        guard !favouritingPhotoIDs.contains(photo.id) else { return }
        favouritingPhotoIDs.insert(photo.id)
        defer { favouritingPhotoIDs.remove(photo.id) }

        let newValue = !photo.isFavourite
        do {
            guard let uid = Auth.auth().currentUser?.uid else {
                feedMessage = "Please sign in first."
                return
            }
            try await feedService.setFavourite(photoID: photo.id, userID: uid, isFavourite: newValue)
            if let index = photos.firstIndex(where: { $0.id == photo.id }) {
                photos[index] = photos[index].withFavourite(newValue)
                if let selectedGroupID {
                    photosByGroupID[selectedGroupID] = photos
                }
            }
            feedMessage = newValue ? "Added to favourites." : "Removed from favourites."
        } catch {
            feedMessage = error.localizedDescription
        }
    }

    private func savePhotoEdits(photo: FeedPhoto, year: Int, hashtags: [String]) async -> Result<Void, FeedEditError> {
        guard !editingPhotoIDs.contains(photo.id) else { return .failure(FeedEditError(message: "Photo is already being updated.")) }
        guard let uid = Auth.auth().currentUser?.uid else {
            return .failure(FeedEditError(message: "Please sign in first."))
        }

        editingPhotoIDs.insert(photo.id)
        defer { editingPhotoIDs.remove(photo.id) }

        do {
            try await feedService.updatePhotoMetadata(photo, requesterUID: uid, year: year, hashtags: hashtags)
            let updated = photo.withMetadata(year: year, hashtags: hashtags)

            if let index = photos.firstIndex(where: { $0.id == photo.id }) {
                photos[index] = updated
            }
            if let selectedGroupID, var cached = photosByGroupID[selectedGroupID],
               let index = cached.firstIndex(where: { $0.id == photo.id }) {
                cached[index] = updated
                photosByGroupID[selectedGroupID] = cached
            }
            if selectedPhoto?.id == photo.id {
                selectedPhoto = updated
            }
            editingPhoto = nil
            return .success(())
        } catch {
            return .failure(FeedEditError(message: error.localizedDescription))
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
        .contentShape(RoundedRectangle(cornerRadius: 12))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .onTapGesture {
            onTap()
        }
        .overlay {
            if isDeleting || isEditing {
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(.ultraThinMaterial)
                    ProgressView()
                }
            }
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
        .disabled(isDeleting || isFavouriting || isEditing)
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
    @State private var errorMessage: String?
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

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(AppTheme.errorText)
                }

                Spacer()
            }
            .padding(16)
            .screenTheme()
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
            showError("Enter a valid year.")
            return
        }

        isSaving = true
        defer { isSaving = false }

        switch await onSave(year, hashtags) {
        case .success:
            dismiss()
        case .failure(let error):
            showError(error.message)
        }
    }

    private func showError(_ message: String) {
        errorMessage = message
        clearErrorTask?.cancel()
        clearErrorTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            if !Task.isCancelled, errorMessage == message {
                errorMessage = nil
            }
        }
    }
}
