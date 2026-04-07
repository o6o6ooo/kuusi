import SwiftUI

@MainActor
struct YearsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var photoCollection = PhotoCollectionViewModel()
    @State private var selectedYear: Int?
    @State private var selectedPhoto: FeedPhoto?

    private var accentColor: Color { AppTheme.accent(for: colorScheme) }

    private var currentGroupPhotos: [FeedPhoto] {
        photoCollection.currentGroupPhotos
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
                    if photoCollection.groups.isEmpty {
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
                if photoCollection.groups.isEmpty {
                    await photoCollection.loadInitial(limit: 8)
                    applySelectedYear(from: currentGroupPhotos)
                }
            }
            .onChange(of: photoCollection.currentGroupPhotoSignature) { _, _ in
                applySelectedYear(from: currentGroupPhotos)
            }
            .sheet(item: $selectedPhoto) { photo in
                PhotoPreviewOverlayView(photo: photo)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
        }
    }

    @ViewBuilder
    private func content(for availableWidth: CGFloat) -> some View {
        if photoCollection.isLoading {
            ProgressView("Loading years...")
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        } else if let errorMessage = photoCollection.errorMessage {
            ContentUnavailableView("Failed to load years", systemImage: "exclamationmark.triangle", description: Text(errorMessage))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if currentGroupPhotos.isEmpty {
            ContentUnavailableView("No photos yet", systemImage: "photo")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if displayedPhotos.isEmpty {
            ContentUnavailableView("No photos for this year", systemImage: "calendar")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            PhotoGridView(
                photos: displayedPhotos,
                availableWidth: availableWidth,
                measuredAspectRatios: photoCollection.measuredAspectRatios,
                onTap: { selectedPhoto = $0 },
                onRequireAspectRatio: photoCollection.requestAspectRatioIfNeeded
            ) { photo, columnWidth, displayAspectRatio, onTap, onRequireAspectRatio in
                YearsPhotoTile(
                    photo: photo,
                    width: columnWidth,
                    displayAspectRatio: displayAspectRatio,
                    onTap: onTap,
                    onRequireAspectRatio: onRequireAspectRatio
                )
            }
            .refreshable {
                await refreshCurrentGroup()
            }
        }
    }

    private var yearGroupTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 10) {
                ForEach(photoCollection.groups) { group in
                    let isSelected = photoCollection.selectedGroupID == group.id
                    Button(group.name) {
                        photoCollection.selectGroup(group.id, limit: 8)
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

    private func refreshCurrentGroup() async {
        await photoCollection.refresh(limit: 8)
        applySelectedYear(from: currentGroupPhotos)
    }

    private func applySelectedYear(from photos: [FeedPhoto]) {
        let years = Array(Set(photos.compactMap(\.year))).sorted(by: >)
        if let selectedYear, years.contains(selectedYear) {
            self.selectedYear = selectedYear
        } else {
            selectedYear = years.first
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
