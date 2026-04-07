import SwiftUI

struct PhotoGridView<Tile: View, Footer: View>: View {
    let photos: [FeedPhoto]
    let availableWidth: CGFloat
    let measuredAspectRatios: [String: CGFloat]
    let onTap: (FeedPhoto) -> Void
    let onRequireAspectRatio: (FeedPhoto) -> Void
    let tile: (FeedPhoto, CGFloat, CGFloat, @escaping () -> Void, @escaping () -> Void) -> Tile
    let footer: () -> Footer

    private let spacing: CGFloat = 8
    private let horizontalPadding: CGFloat = 12

    init(
        photos: [FeedPhoto],
        availableWidth: CGFloat,
        measuredAspectRatios: [String: CGFloat],
        onTap: @escaping (FeedPhoto) -> Void,
        onRequireAspectRatio: @escaping (FeedPhoto) -> Void,
        @ViewBuilder tile: @escaping (FeedPhoto, CGFloat, CGFloat, @escaping () -> Void, @escaping () -> Void) -> Tile,
        @ViewBuilder footer: @escaping () -> Footer
    ) {
        self.photos = photos
        self.availableWidth = availableWidth
        self.measuredAspectRatios = measuredAspectRatios
        self.onTap = onTap
        self.onRequireAspectRatio = onRequireAspectRatio
        self.tile = tile
        self.footer = footer
    }

    var body: some View {
        let columnCount = UIDevice.current.userInterfaceIdiom == .pad ? 3 : 2
        let totalSpacing = spacing * CGFloat(columnCount - 1)
        let contentWidth = availableWidth - (horizontalPadding * 2)
        let columnWidth = max(80, (contentWidth - totalSpacing) / CGFloat(columnCount))
        let columns = makeWaterfallColumns(
            photos: photos,
            columnCount: columnCount,
            columnWidth: columnWidth
        )

        ScrollView {
            HStack(alignment: .top, spacing: spacing) {
                ForEach(0..<columnCount, id: \.self) { columnIndex in
                    LazyVStack(spacing: spacing) {
                        ForEach(columns[columnIndex]) { photo in
                            let onPhotoTap = { onTap(photo) }
                            let onPhotoRequireAspectRatio = { onRequireAspectRatio(photo) }
                            tile(
                                photo,
                                columnWidth,
                                displayAspectRatio(for: photo),
                                onPhotoTap,
                                onPhotoRequireAspectRatio
                            )
                        }
                    }
                }
            }
            .padding(.horizontal, horizontalPadding)
            .padding(.top, 2)
            .padding(.bottom, 8)

            footer()
        }
    }

    private func displayAspectRatio(for photo: FeedPhoto) -> CGFloat {
        CGFloat(photo.aspectRatio ?? Double(measuredAspectRatios[photo.id] ?? 1.0))
    }

    private func makeWaterfallColumns(
        photos: [FeedPhoto],
        columnCount: Int,
        columnWidth: CGFloat
    ) -> [[FeedPhoto]] {
        guard columnCount > 0 else { return [] }

        var columns = Array(repeating: [FeedPhoto](), count: columnCount)
        var heights = Array(repeating: CGFloat.zero, count: columnCount)

        for photo in photos {
            let ratio = max(displayAspectRatio(for: photo), 0.35)
            let tileHeight = columnWidth / ratio
            let shortest = heights.enumerated().min(by: { $0.element < $1.element })?.offset ?? 0
            columns[shortest].append(photo)
            heights[shortest] += tileHeight + spacing
        }

        return columns
    }
}

extension PhotoGridView where Footer == EmptyView {
    init(
        photos: [FeedPhoto],
        availableWidth: CGFloat,
        measuredAspectRatios: [String: CGFloat],
        onTap: @escaping (FeedPhoto) -> Void,
        onRequireAspectRatio: @escaping (FeedPhoto) -> Void,
        @ViewBuilder tile: @escaping (FeedPhoto, CGFloat, CGFloat, @escaping () -> Void, @escaping () -> Void) -> Tile
    ) {
        self.init(
            photos: photos,
            availableWidth: availableWidth,
            measuredAspectRatios: measuredAspectRatios,
            onTap: onTap,
            onRequireAspectRatio: onRequireAspectRatio,
            tile: tile,
            footer: { EmptyView() }
        )
    }
}
