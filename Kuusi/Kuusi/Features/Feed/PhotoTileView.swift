import Combine
import Foundation
import SwiftUI

@MainActor
private final class PhotoAuthorIconViewModel: ObservableObject {
    @Published private(set) var user: AppUser?
    private let userService = UserService()

    func loadProfile(for uid: String?) async {
        guard let uid, !uid.isEmpty else {
            user = nil
            return
        }

        user = userService.cachedAuthorProfile(uid: uid)

        if user == nil {
            user = await userService.fetchCachedAuthorProfile(uid: uid)
            return
        }

        guard userService.shouldRefreshCachedAuthorProfile(uid: uid) else { return }
        let refreshedUser = await userService.refreshAuthorProfile(uid: uid)
        if let refreshedUser, shouldApplyProfile(refreshedUser) {
            user = refreshedUser
        }
    }

    private func shouldApplyProfile(_ refreshedUser: AppUser) -> Bool {
        guard let user else { return true }
        return refreshedUser.icon != user.icon
            || refreshedUser.bgColour != user.bgColour
            || refreshedUser.name != user.name
    }
}

private struct PhotoAuthorIconView: View {
    let uid: String?

    @StateObject private var viewModel = PhotoAuthorIconViewModel()

    var body: some View {
        Group {
            if let user = viewModel.user {
                Text(user.icon)
                    .font(.system(size: 10))
                    .frame(width: 24, height: 24)
                    .background(Color(hex: user.bgColour))
                    .clipShape(Circle())
                    .overlay {
                        Circle()
                            .stroke(Color.white.opacity(0.82), lineWidth: 1.5)
                    }
                    .accessibilityLabel(String(format: String(localized: "photo.posted_by_accessibility"), user.name))
            } else {
                Circle()
                    .fill(Color.white.opacity(0.16))
                    .frame(width: 24, height: 24)
                    .accessibilityHidden(true)
            }
        }
        .task(id: uid) {
            await viewModel.loadProfile(for: uid)
        }
    }
}

private struct ZoomablePreviewImageView<Placeholder: View>: View {
    let source: FeedImageSource?
    let isZoomEnabled: Bool
    let onZoomChanged: (Bool) -> Void
    let placeholder: () -> Placeholder

    @State private var scale: CGFloat = 1
    @State private var committedScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var committedOffset: CGSize = .zero

    private let minimumScale: CGFloat = 1
    private let maximumScale: CGFloat = 4

    var body: some View {
        GeometryReader { proxy in
            imageContent(in: proxy.size)
        }
        .clipped()
        .onChange(of: source) { _, _ in
            resetZoom()
        }
        .onChange(of: isZoomEnabled) { _, newValue in
            guard !newValue else { return }
            resetZoom()
        }
    }

    @ViewBuilder
    private func imageContent(in size: CGSize) -> some View {
        let image = CachedRemoteImageView(source: source) { image in
            image
                .resizable()
                .scaledToFit()
                .scaleEffect(scale)
                .offset(offset)
        } placeholder: {
            placeholder()
        }
        .frame(width: size.width, height: size.height)
        .contentShape(Rectangle())

        if isZoomEnabled {
            if committedScale > minimumScale {
                image
                    .simultaneousGesture(magnifyGesture(in: size))
                    .simultaneousGesture(panGesture(in: size))
            } else {
                image
                    .simultaneousGesture(magnifyGesture(in: size))
            }
        } else {
            image
        }
    }

    private func magnifyGesture(in size: CGSize) -> some Gesture {
        MagnifyGesture()
            .onChanged { value in
                guard isZoomEnabled else { return }
                let nextScale = clampedScale(committedScale * value.magnification)
                let anchorOffset = offset(for: value.startAnchor, in: size)
                let nextOffset = offset(
                    scalingFrom: committedScale,
                    to: nextScale,
                    around: anchorOffset
                )

                scale = nextScale
                offset = clampedOffset(nextOffset, scale: nextScale, size: size)
                onZoomChanged(scale > minimumScale)
            }
            .onEnded { _ in
                guard isZoomEnabled else {
                    resetZoom()
                    return
                }

                if scale <= minimumScale {
                    resetZoom()
                } else {
                    scale = clampedScale(scale)
                    offset = clampedOffset(offset, scale: scale, size: size)
                    committedScale = scale
                    committedOffset = offset
                    onZoomChanged(true)
                }
            }
    }

    private func panGesture(in size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 1)
            .onChanged { value in
                guard isZoomEnabled, scale > minimumScale else { return }
                let proposedOffset = CGSize(
                    width: committedOffset.width + value.translation.width,
                    height: committedOffset.height + value.translation.height
                )
                offset = clampedOffset(proposedOffset, scale: scale, size: size)
            }
            .onEnded { _ in
                guard isZoomEnabled, scale > minimumScale else { return }
                offset = clampedOffset(offset, scale: scale, size: size)
                committedOffset = offset
            }
    }

    private func clampedScale(_ value: CGFloat) -> CGFloat {
        min(max(value, minimumScale), maximumScale)
    }

    private func offset(for anchor: UnitPoint, in size: CGSize) -> CGPoint {
        CGPoint(
            x: (anchor.x - 0.5) * size.width,
            y: (anchor.y - 0.5) * size.height
        )
    }

    private func offset(
        scalingFrom startScale: CGFloat,
        to nextScale: CGFloat,
        around anchorOffset: CGPoint
    ) -> CGSize {
        guard startScale > 0 else { return committedOffset }

        let scaleChange = nextScale / startScale

        return CGSize(
            width: anchorOffset.x * (1 - scaleChange) + committedOffset.width * scaleChange,
            height: anchorOffset.y * (1 - scaleChange) + committedOffset.height * scaleChange
        )
    }

    private func clampedOffset(_ value: CGSize, scale: CGFloat, size: CGSize) -> CGSize {
        guard scale > minimumScale else { return .zero }

        let horizontalLimit = max(0, size.width * (scale - minimumScale) / 2)
        let verticalLimit = max(0, size.height * (scale - minimumScale) / 2)

        return CGSize(
            width: min(max(value.width, -horizontalLimit), horizontalLimit),
            height: min(max(value.height, -verticalLimit), verticalLimit)
        )
    }

    private func resetZoom() {
        scale = minimumScale
        committedScale = minimumScale
        offset = .zero
        committedOffset = .zero
        onZoomChanged(false)
    }
}

struct PhotoTileView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var isPreviewZoomed = false

    let photo: FeedPhoto
    let previewAccess: PreviewAccess
    let width: CGFloat
    let displayAspectRatio: CGFloat
    let isExpanded: Bool
    let canDelete: Bool
    let onTap: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onToggleFavourite: () -> Void
    let isDeleting: Bool
    let isFavouriting: Bool
    let isEditing: Bool

    var body: some View {
        let ratio = max(displayAspectRatio, 0.35)
        let collapsedHeight = width / ratio
        let expandedHeight = width / ratio
        let imageSource = resolvedImageSource

        VStack(alignment: .leading, spacing: 0) {
            ZoomablePreviewImageView(
                source: imageSource,
                isZoomEnabled: isExpanded,
                onZoomChanged: { isPreviewZoomed = $0 }
            ) {
                Rectangle()
                    .fill(Color.gray.opacity(colorScheme == .dark ? 0.25 : 0.15))
                    .overlay(ProgressView())
            }
            .frame(width: width, height: isExpanded ? expandedHeight : collapsedHeight)
            .overlay(alignment: .bottomLeading) {
                if isExpanded && !isPreviewZoomed {
                    expandedMetaOverlay
                }
            }
        }
        .background(tileBackground)
        .contentShape(RoundedRectangle(cornerRadius: isExpanded ? 26 : 18, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: isExpanded ? 26 : 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: isExpanded ? 26 : 18, style: .continuous)
                .strokeBorder(.white.opacity(colorScheme == .dark ? 0.08 : 0.28), lineWidth: 1)
        }
        .overlay(alignment: .topTrailing) {
            statusBadge
                .opacity(isExpanded && isPreviewZoomed ? 0 : 1)
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
        .scaleEffect(1)
        .shadow(color: .black.opacity(isExpanded ? 0.1 : 0.08), radius: isExpanded ? 10 : 8, x: 0, y: isExpanded ? 5 : 4)
        .onTapGesture {
            guard !isPreviewZoomed else { return }
            onTap()
        }
        .onChange(of: isExpanded) { _, newValue in
            guard !newValue else { return }
            isPreviewZoomed = false
        }
        .onChange(of: imageSource) { _, _ in
            isPreviewZoomed = false
        }
        .contextMenu {
            Button {
                onEdit()
            } label: {
                Label("photo.menu.edit", systemImage: "pencil")
            }

            Button {
                onToggleFavourite()
            } label: {
                Label(
                    photo.isFavourite ? String(localized: "photo.menu.remove_from_favourites") : String(localized: "photo.menu.add_to_favourites"),
                    systemImage: photo.isFavourite ? "heart.slash" : "heart"
                )
            }

            if canDelete {
                Button(role: .destructive) {
                    onDelete()
                } label: {
                Label("photo.menu.delete", systemImage: "trash")
                }
            }
        }
        .disabled(isDeleting || isEditing || isFavouriting)
    }

    private var tileBackground: some View {
        Group {
            if isExpanded {
                LinearGradient(
                    colors: [
                        Color.white.opacity(colorScheme == .dark ? 0.06 : 0.96),
                        Color.white.opacity(colorScheme == .dark ? 0.03 : 0.86)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            } else {
                Color.clear
            }
        }
    }

    private var resolvedImageSource: FeedImageSource? {
        switch previewAccess {
        case .full:
            if isExpanded {
                return preferredSource(
                    primaryPath: photo.previewStoragePath,
                    secondaryPath: photo.thumbnailStoragePath
                )
            }
            return preferredSource(
                primaryPath: photo.thumbnailStoragePath,
                secondaryPath: photo.previewStoragePath
            )
        case .thumbnailOnly:
            return preferredSource(
                primaryPath: photo.thumbnailStoragePath,
                secondaryPath: photo.previewStoragePath
            )
        }
    }

    private func preferredSource(
        primaryPath: String?,
        secondaryPath: String?
    ) -> FeedImageSource? {
        if let primaryPath, !primaryPath.isEmpty {
            return .storagePath(primaryPath)
        }

        if let secondaryPath, !secondaryPath.isEmpty {
            return .storagePath(secondaryPath)
        }

        return nil
    }

    @ViewBuilder
    private var statusBadge: some View {
        VStack(alignment: .trailing, spacing: 8) {
            if photo.isFavourite {
                Image(systemName: "heart.fill")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.18), radius: 6, x: 0, y: 2)
            }
        }
        .padding(12)
    }

    private var expandedMetaOverlay: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let caption = photo.caption {
                Text(caption)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white.opacity(0.92))
                    .lineLimit(2)
                    .shadow(color: overlayShadowColor, radius: 8, x: 0, y: 3)
            }

            if !photo.hashtags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(photo.hashtags, id: \.self) { hashtag in
                            Text("#\(hashtag)")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.white.opacity(0.92))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .appFeedGlassCapsule()
                        }
                    }
                }
            }

            HStack(alignment: .center, spacing: 8) {
                PhotoAuthorIconView(uid: photo.postedBy)
                    .shadow(color: overlayShadowColor, radius: 8, x: 0, y: 3)

                Text(photo.date.map { Self.dateFormatter.string(from: $0) } ?? String(localized: "photo.shared_memory"))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(dateOverlayColor)
                    .shadow(color: overlayShadowColor, radius: 8, x: 0, y: 3)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [
                    .clear,
                    .black.opacity(colorScheme == .dark ? 0.18 : 0.22),
                    .black.opacity(colorScheme == .dark ? 0.44 : 0.38)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    private var dateOverlayColor: Color {
        Color.white.opacity(0.72)
    }

    private var overlayShadowColor: Color {
        Color.black.opacity(colorScheme == .dark ? 0.38 : 0.22)
    }
}
