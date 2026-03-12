import FirebaseAuth
import SwiftUI
import UIKit

@MainActor
struct YearsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var groups: [GroupSummary] = []
    @State private var selectedGroupID: String?
    @State private var selectedYear: Int?
    @State private var photosByGroupID: [String: [FeedPhoto]] = [:]
    @State private var selectedPhoto: FeedPhoto?
    @State private var measuredAspectRatios: [String: CGFloat] = [:]
    @State private var measuringAspectRatioIDs: Set<String> = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    private let feedService = FeedService()
    private let groupService = GroupService()
    private var accentColor: Color { AppTheme.accent(for: colorScheme) }

    private var currentGroupPhotos: [FeedPhoto] {
        guard let selectedGroupID else { return [] }
        return photosByGroupID[selectedGroupID] ?? []
    }

    private var availableYears: [Int] {
        Array(Set(currentGroupPhotos.compactMap(\.year))).sorted(by: >)
    }

    private var displayedPhotos: [FeedPhoto] {
        guard let selectedYear else { return currentGroupPhotos }
        return currentGroupPhotos.filter { $0.year == selectedYear }
    }

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                VStack(spacing: 8) {
                    if groups.isEmpty {
                        ContentUnavailableView("No groups yet", systemImage: "person.3")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        yearGroupTabs

                        if !availableYears.isEmpty {
                            yearTabs
                        }

                        content(for: proxy.size.width)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .screenTheme()
            .toolbar(.hidden, for: .navigationBar)
            .task {
                if groups.isEmpty {
                    await loadInitialYears()
                }
            }
            .sheet(item: $selectedPhoto) { photo in
                YearsPreviewSheet(photo: photo)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
        }
    }

    @ViewBuilder
    private func content(for availableWidth: CGFloat) -> some View {
        if isLoading {
            ProgressView("Loading years...")
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        } else if let errorMessage {
            ContentUnavailableView("Failed to load years", systemImage: "exclamationmark.triangle", description: Text(errorMessage))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if currentGroupPhotos.isEmpty {
            ContentUnavailableView("No photos yet", systemImage: "photo")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if displayedPhotos.isEmpty {
            ContentUnavailableView("No photos for this year", systemImage: "calendar")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            let spacing: CGFloat = 8
            let horizontalPadding: CGFloat = 12
            let columnCount = UIDevice.current.userInterfaceIdiom == .pad ? 3 : 2
            let totalSpacing = spacing * CGFloat(columnCount - 1)
            let contentWidth = availableWidth - (horizontalPadding * 2)
            let columnWidth = max(80, (contentWidth - totalSpacing) / CGFloat(columnCount))
            let columns = makeWaterfallColumns(
                photos: displayedPhotos,
                columnCount: columnCount,
                columnWidth: columnWidth,
                spacing: spacing
            )

            ScrollView {
                HStack(alignment: .top, spacing: spacing) {
                    ForEach(0..<columnCount, id: \.self) { columnIndex in
                        LazyVStack(spacing: spacing) {
                            ForEach(columns[columnIndex]) { photo in
                                YearsPhotoTile(
                                    photo: photo,
                                    width: columnWidth,
                                    displayAspectRatio: CGFloat(
                                        photo.aspectRatio ?? Double(measuredAspectRatios[photo.id] ?? 1.0)
                                    ),
                                    onTap: { selectedPhoto = photo },
                                    onRequireAspectRatio: {
                                        requestAspectRatioIfNeeded(for: photo)
                                    }
                                )
                            }
                        }
                    }
                }
                .padding(.horizontal, horizontalPadding)
                .padding(.top, 2)
                .padding(.bottom, 8)
            }
            .refreshable {
                await refreshCurrentGroup()
            }
        }
    }

    private var yearGroupTabs: some View {
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
            .padding(.leading, 12)
            .padding(.trailing, 12)
            .padding(.top, 8)
            .padding(.bottom, 2)
        }
        .frame(height: 52)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var yearTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 8) {
                ForEach(availableYears, id: \.self) { year in
                    let isSelected = selectedYear == year
                    Button(String(year)) {
                        selectedYear = year
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

    private func loadInitialYears() async {
        guard let uid = Auth.auth().currentUser?.uid else {
            groups = []
            selectedGroupID = nil
            selectedYear = nil
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
                selectedGroupID = nil
                selectedYear = nil
                photosByGroupID = [:]
                errorMessage = error.localizedDescription
                return
            }
        }

        groups = cachedGroups
        selectedGroupID = cachedGroups.first?.id
        errorMessage = nil
        await fetchPhotosForSelectedGroup(forceReload: false)
    }

    private func refreshCurrentGroup() async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        do {
            let freshGroups = try await groupService.fetchGroups(for: uid)
            groups = freshGroups
            if let selectedGroupID, freshGroups.contains(where: { $0.id == selectedGroupID }) {
                self.selectedGroupID = selectedGroupID
            } else {
                selectedGroupID = freshGroups.first?.id
            }
            await fetchPhotosForSelectedGroup(forceReload: true)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func fetchPhotosForSelectedGroup(forceReload: Bool) async {
        isLoading = true
        defer { isLoading = false }

        do {
            guard let uid = Auth.auth().currentUser?.uid else {
                errorMessage = nil
                return
            }
            guard let selectedGroupID else {
                selectedYear = nil
                errorMessage = nil
                return
            }

            if !forceReload, let cachedPhotos = photosByGroupID[selectedGroupID] {
                applySelectedYear(from: cachedPhotos)
                errorMessage = nil
                return
            }

            let loadedPhotos = try await feedService.fetchRecentPhotos(
                userID: uid,
                groupIDs: [selectedGroupID],
                limit: 8
            )
            photosByGroupID[selectedGroupID] = loadedPhotos
            applySelectedYear(from: loadedPhotos)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func applySelectedYear(from photos: [FeedPhoto]) {
        let years = Array(Set(photos.compactMap(\.year))).sorted(by: >)
        if let selectedYear, years.contains(selectedYear) {
            self.selectedYear = selectedYear
        } else {
            selectedYear = years.first
        }
    }

    private func selectGroup(_ groupID: String) {
        selectedGroupID = groupID
        errorMessage = nil
        Task {
            await fetchPhotosForSelectedGroup(forceReload: false)
        }
    }

    private func makeWaterfallColumns(
        photos: [FeedPhoto],
        columnCount: Int,
        columnWidth: CGFloat,
        spacing: CGFloat
    ) -> [[FeedPhoto]] {
        guard columnCount > 0 else { return [] }
        var columns = Array(repeating: [FeedPhoto](), count: columnCount)
        var heights = Array(repeating: CGFloat.zero, count: columnCount)

        for photo in photos {
            let ratio = max(
                CGFloat(photo.aspectRatio ?? Double(measuredAspectRatios[photo.id] ?? 1.0)),
                0.35
            )
            let tileHeight = columnWidth / ratio
            let shortest = heights.enumerated().min(by: { $0.element < $1.element })?.offset ?? 0
            columns[shortest].append(photo)
            heights[shortest] += tileHeight + spacing
        }
        return columns
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
}

private struct YearsPhotoTile: View {
    @Environment(\.colorScheme) private var colorScheme
    let photo: FeedPhoto
    let width: CGFloat
    let displayAspectRatio: CGFloat
    let onTap: () -> Void
    let onRequireAspectRatio: () -> Void

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
        .task {
            onRequireAspectRatio()
        }
    }
}

private struct YearsPreviewSheet: View {
    @Environment(\.colorScheme) private var colorScheme
    let photo: FeedPhoto

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            AsyncImage(url: URL(string: photo.photoURL ?? photo.thumbnailURL ?? "")) { image in
                image
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            } placeholder: {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.gray.opacity(colorScheme == .dark ? 0.25 : 0.15))
                    .overlay(ProgressView())
                    .frame(height: 260)
            }

            if !photo.hashtags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(photo.hashtags, id: \.self) { hashtag in
                            Text("#\(hashtag)")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Text(String(photo.year ?? 0))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .screenTheme()
    }
}
