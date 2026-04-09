import Combine
import FirebaseAuth
import SwiftUI
import UIKit

protocol PhotoCollectionFeedServicing {
    func fetchRecentPhotos(userID: String, groupIDs: [String], limit: Int) async throws -> [FeedPhoto]
}

protocol PhotoCollectionGroupServicing {
    func cachedGroups(for uid: String) -> [GroupSummary]
    func fetchGroups(for uid: String) async throws -> [GroupSummary]
}

extension FeedService: PhotoCollectionFeedServicing {}
extension GroupService: PhotoCollectionGroupServicing {}

@MainActor
final class PhotoCollectionViewModel: ObservableObject {
    @Published var groups: [GroupSummary] = []
    @Published var selectedGroupID: String?
    @Published var photosByGroupID: [String: [FeedPhoto]] = [:]
    @Published var measuredAspectRatios: [String: CGFloat] = [:]
    @Published var isLoading = false
    @Published var errorMessage: String?

    private var measuringAspectRatioIDs: Set<String> = []

    private let feedService: PhotoCollectionFeedServicing
    private let groupService: PhotoCollectionGroupServicing
    private let currentUserIDProvider: @MainActor () -> String?
    private let aspectRatioMeasurer: (String) async -> CGFloat?

    init(
        feedService: PhotoCollectionFeedServicing,
        groupService: PhotoCollectionGroupServicing,
        currentUserIDProvider: @escaping @MainActor () -> String?,
        aspectRatioMeasurer: @escaping (String) async -> CGFloat?
    ) {
        self.feedService = feedService
        self.groupService = groupService
        self.currentUserIDProvider = currentUserIDProvider
        self.aspectRatioMeasurer = aspectRatioMeasurer
    }

    convenience init() {
        self.init(
            feedService: FeedService(),
            groupService: GroupService(),
            currentUserIDProvider: { Auth.auth().currentUser?.uid },
            aspectRatioMeasurer: { urlString in
                await PhotoCollectionViewModel.measureAspectRatioFromURL(urlString)
            }
        )
    }

    var currentGroupPhotos: [FeedPhoto] {
        guard let selectedGroupID else { return [] }
        return photosByGroupID[selectedGroupID] ?? []
    }

    var currentGroupPhotoSignature: [String] {
        currentGroupPhotos.map { "\($0.id)-\($0.year ?? 0)" }
    }

    func loadInitial(limit: Int) async {
        guard let uid = currentUserIDProvider() else {
            resetState()
            return
        }

        var cachedGroups = groupService.cachedGroups(for: uid)
        if cachedGroups.isEmpty {
            do {
                cachedGroups = try await groupService.fetchGroups(for: uid)
            } catch {
                resetState()
                errorMessage = error.localizedDescription
                return
            }
        }

        groups = cachedGroups
        selectedGroupID = cachedGroups.first?.id
        errorMessage = nil
        await fetchPhotosForSelectedGroup(forceReload: false, limit: limit)
    }

    func refresh(limit: Int) async {
        guard let uid = currentUserIDProvider() else { return }

        do {
            let freshGroups = try await groupService.fetchGroups(for: uid)
            groups = freshGroups
            if let selectedGroupID, freshGroups.contains(where: { $0.id == selectedGroupID }) {
                self.selectedGroupID = selectedGroupID
            } else {
                selectedGroupID = freshGroups.first?.id
            }
            await fetchPhotosForSelectedGroup(forceReload: true, limit: limit)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func selectGroup(_ groupID: String, limit: Int) {
        selectedGroupID = groupID
        errorMessage = nil
        Task {
            await fetchPhotosForSelectedGroup(forceReload: false, limit: limit)
        }
    }

    func replacePhoto(_ updatedPhoto: FeedPhoto) {
        guard let selectedGroupID else { return }
        guard var cachedPhotos = photosByGroupID[selectedGroupID],
              let index = cachedPhotos.firstIndex(where: { $0.id == updatedPhoto.id }) else {
            return
        }

        cachedPhotos[index] = updatedPhoto
        photosByGroupID[selectedGroupID] = cachedPhotos
    }

    func removePhoto(id: String) {
        guard let selectedGroupID else { return }
        guard var cachedPhotos = photosByGroupID[selectedGroupID] else { return }

        cachedPhotos.removeAll { $0.id == id }
        photosByGroupID[selectedGroupID] = cachedPhotos
    }

    func clearMeasuredAspectRatio(for photoID: String) {
        measuredAspectRatios[photoID] = nil
    }

    func requestAspectRatioIfNeeded(for photo: FeedPhoto) {
        // TODO: Remove this fallback after all legacy photos have aspect_ratio.
        if photo.aspectRatio != nil { return }
        if measuredAspectRatios[photo.id] != nil { return }
        if measuringAspectRatioIDs.contains(photo.id) { return }
        guard let urlString = photo.thumbnailURL ?? photo.photoURL else { return }

        measuringAspectRatioIDs.insert(photo.id)
        Task {
            let ratio = await aspectRatioMeasurer(urlString)
            await MainActor.run {
                self.measuringAspectRatioIDs.remove(photo.id)
                guard let ratio else { return }
                self.measuredAspectRatios[photo.id] = ratio
            }
        }
    }

    private func fetchPhotosForSelectedGroup(forceReload: Bool, limit: Int) async {
        isLoading = true
        defer { isLoading = false }

        do {
            guard let uid = currentUserIDProvider() else {
                errorMessage = nil
                return
            }
            guard let selectedGroupID else {
                errorMessage = nil
                return
            }

            if !forceReload, photosByGroupID[selectedGroupID] != nil {
                errorMessage = nil
                return
            }

            let loadedPhotos = try await feedService.fetchRecentPhotos(
                userID: uid,
                groupIDs: [selectedGroupID],
                limit: limit
            )
            photosByGroupID[selectedGroupID] = loadedPhotos
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    nonisolated private static func measureAspectRatioFromURL(_ urlString: String) async -> CGFloat? {
        guard let url = URL(string: urlString) else { return nil }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let image = UIImage(data: data), image.size.height > 0 else { return nil }
            return CGFloat(image.size.width / image.size.height)
        } catch {
            return nil
        }
    }

    private func resetState() {
        groups = []
        selectedGroupID = nil
        photosByGroupID = [:]
        measuredAspectRatios = [:]
        errorMessage = nil
    }
}
