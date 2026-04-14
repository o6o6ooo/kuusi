import SwiftUI

private struct MasonryExpandedKey: LayoutValueKey {
    nonisolated static let defaultValue = false
}

private struct MasonryGridLayout: Layout {
    struct Cache {
        var width: CGFloat = 0
        var expandedStates: [Bool] = []
        var frames: [CGRect] = []
    }

    let columnCount: Int
    let spacing: CGFloat

    func makeCache(subviews: Subviews) -> Cache {
        Cache()
    }

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout Cache
    ) -> CGSize {
        let width = proposal.width ?? 0
        let frames = resolveFrames(for: subviews, width: width, cache: &cache)
        let height = frames.map(\.maxY).max() ?? 0
        return CGSize(width: width, height: height)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout Cache
    ) {
        let frames = resolveFrames(for: subviews, width: bounds.width, cache: &cache)

        for (index, subview) in subviews.enumerated() {
            guard index < frames.count else { continue }
            let frame = frames[index]
            subview.place(
                at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                proposal: ProposedViewSize(width: frame.width, height: frame.height)
            )
        }
    }

    private func resolveFrames(for subviews: Subviews, width: CGFloat, cache: inout Cache) -> [CGRect] {
        let expandedStates = subviews.map { $0[MasonryExpandedKey.self] }
        if cache.width == width, cache.expandedStates == expandedStates, cache.frames.count == subviews.count {
            return cache.frames
        }

        let frames = makeFrames(for: subviews, width: width)
        cache.width = width
        cache.expandedStates = expandedStates
        cache.frames = frames
        return frames
    }

    private func makeFrames(for subviews: Subviews, width: CGFloat) -> [CGRect] {
        guard columnCount > 0, width > 0 else {
            return Array(repeating: .zero, count: subviews.count)
        }

        let totalSpacing = spacing * CGFloat(columnCount - 1)
        let columnWidth = max(80, (width - totalSpacing) / CGFloat(columnCount))
        let fullWidth = columnWidth * CGFloat(columnCount) + totalSpacing

        var frames: [CGRect] = []
        frames.reserveCapacity(subviews.count)

        var columnHeights = Array(repeating: CGFloat.zero, count: columnCount)

        for subview in subviews {
            let isExpanded = subview[MasonryExpandedKey.self]

            if isExpanded {
                let y = columnHeights.max() ?? 0
                let size = subview.sizeThatFits(.init(width: fullWidth, height: nil))
                let height = size.height
                frames.append(CGRect(x: 0, y: y, width: fullWidth, height: height))
                let nextY = y + height + spacing
                for index in columnHeights.indices {
                    columnHeights[index] = nextY
                }
            } else {
                let columnIndex = columnHeights.enumerated().min(by: { $0.element < $1.element })?.offset ?? 0
                let x = CGFloat(columnIndex) * (columnWidth + spacing)
                let y = columnHeights[columnIndex]
                let size = subview.sizeThatFits(.init(width: columnWidth, height: nil))
                let height = size.height
                frames.append(CGRect(x: x, y: y, width: columnWidth, height: height))
                columnHeights[columnIndex] = y + height + spacing
            }
        }

        return frames
    }
}

struct PhotoGridView<Tile: View, Footer: View>: View {
    let photos: [FeedPhoto]
    let availableWidth: CGFloat
    let expandedPhotoID: String?
    let onTap: (FeedPhoto) -> Void
    let tile: (FeedPhoto, CGFloat, CGFloat, Bool, @escaping () -> Void) -> Tile
    let footer: () -> Footer

    private let spacing: CGFloat = 8
    private let horizontalPadding: CGFloat = 12

    init(
        photos: [FeedPhoto],
        availableWidth: CGFloat,
        expandedPhotoID: String? = nil,
        onTap: @escaping (FeedPhoto) -> Void,
        @ViewBuilder tile: @escaping (FeedPhoto, CGFloat, CGFloat, Bool, @escaping () -> Void) -> Tile,
        @ViewBuilder footer: @escaping () -> Footer
    ) {
        self.photos = photos
        self.availableWidth = availableWidth
        self.expandedPhotoID = expandedPhotoID
        self.onTap = onTap
        self.tile = tile
        self.footer = footer
    }

    var body: some View {
        let columnCount = UIDevice.current.userInterfaceIdiom == .pad ? 3 : 2
        let totalSpacing = spacing * CGFloat(columnCount - 1)
        let contentWidth = availableWidth - (horizontalPadding * 2)
        let columnWidth = max(80, (contentWidth - totalSpacing) / CGFloat(columnCount))

        ScrollView {
            MasonryGridLayout(columnCount: columnCount, spacing: spacing) {
                ForEach(photos) { photo in
                    let isExpanded = expandedPhotoID == photo.id
                    let onPhotoTap = { onTap(photo) }
                    tile(
                        photo,
                        isExpanded ? contentWidth : columnWidth,
                        displayAspectRatio(for: photo),
                        isExpanded,
                        onPhotoTap
                    )
                    .layoutValue(key: MasonryExpandedKey.self, value: isExpanded)
                }
            }
            .padding(.horizontal, horizontalPadding)
            .padding(.top, 2)
            .padding(.bottom, 8)

            footer()
        }
    }

    private func displayAspectRatio(for photo: FeedPhoto) -> CGFloat {
        CGFloat(photo.aspectRatio ?? 1.0)
    }
}

extension PhotoGridView where Footer == EmptyView {
    init(
        photos: [FeedPhoto],
        availableWidth: CGFloat,
        expandedPhotoID: String? = nil,
        onTap: @escaping (FeedPhoto) -> Void,
        @ViewBuilder tile: @escaping (FeedPhoto, CGFloat, CGFloat, Bool, @escaping () -> Void) -> Tile
    ) {
        self.init(
            photos: photos,
            availableWidth: availableWidth,
            expandedPhotoID: expandedPhotoID,
            onTap: onTap,
            tile: tile,
            footer: { EmptyView() }
        )
    }
}
