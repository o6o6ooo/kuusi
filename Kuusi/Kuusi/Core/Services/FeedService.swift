import FirebaseFirestore
import FirebaseFunctions
import Foundation

enum FeedServiceError: Error {
    case cannotEditOthersPhotos
    case cannotDeleteOthersPhotos
}

struct FeedPageCursor: Equatable {
    let createdAt: Date
    let documentID: String
}

struct RecentPhotoFetchResult {
    let photos: [FeedPhoto]
    let hasMore: Bool
    let nextCursor: FeedPageCursor?
}

final class FeedService {
    private let db = Firestore.firestore()
    private let favouritesField = "favourites"
    private let functions = Functions.functions()

    func fetchRecentPhotoBatch(
        userID: String,
        groupIDs: [String],
        limit: Int = 15,
        startAfter cursor: FeedPageCursor? = nil
    ) async throws -> RecentPhotoFetchResult {
        let visibleGroupIDs = Self.visibleGroupIDs(from: groupIDs)
        guard !visibleGroupIDs.isEmpty else {
            return RecentPhotoFetchResult(photos: [], hasMore: false, nextCursor: nil)
        }
        let favouriteIDs = try await fetchFavouriteIDs(userID: userID)
        let orderedFetchLimit = max(limit, 1) + 1

        do {
            var orderedQuery = db.collection("photos")
                .whereField("group_id", in: visibleGroupIDs)
                .order(by: "created_at", descending: true)
                .order(by: FieldPath.documentID(), descending: true)
                .limit(to: orderedFetchLimit)
            if let cursor {
                orderedQuery = orderedQuery.start(after: [Timestamp(date: cursor.createdAt), cursor.documentID])
            }

            let snapshot = try await fetchQuery(orderedQuery)
            let photos = snapshot.documents.map { doc in
                FeedPhoto(id: doc.documentID, data: doc.data())
            }
            let presentedPhotos = Self.presentRecentPhotos(photos, favouriteIDs: favouriteIDs, limit: limit)

            return RecentPhotoFetchResult(
                photos: presentedPhotos,
                hasMore: snapshot.documents.count > limit,
                nextCursor: Self.makeNextCursor(from: presentedPhotos)
            )
        } catch {
            guard Self.isMissingIndexError(error) else { throw error }

            let fallbackFetchLimit = max(limit + 12, limit)
            let fallbackQuery = db.collection("photos")
                .whereField("group_id", in: visibleGroupIDs)
                .limit(to: fallbackFetchLimit)

            let snapshot = try await fetchQuery(fallbackQuery)
            let photos = snapshot.documents.map { doc in
                FeedPhoto(id: doc.documentID, data: doc.data())
            }
            let filteredPhotos = Self.filteredRecentPhotosFromUnorderedResults(
                photos,
                favouriteIDs: favouriteIDs,
                startAfter: cursor
            )
            let presentedPhotos = Array(filteredPhotos.prefix(limit))

            return RecentPhotoFetchResult(
                photos: presentedPhotos,
                hasMore: filteredPhotos.count > limit,
                nextCursor: Self.makeNextCursor(from: presentedPhotos)
            )
        }
    }

    func fetchFavouritePhotos(userID: String, groupIDs: [String], limit: Int = 10) async throws -> [FeedPhoto] {
        let visibleGroupIDs = Self.visibleGroupIDs(from: groupIDs)
        guard !visibleGroupIDs.isEmpty else { return [] }
        let favouriteIDs = Array(try await fetchFavouriteIDs(userID: userID))
        guard !favouriteIDs.isEmpty else { return [] }

        let chunks = favouriteIDs.chunked(into: 10)
        var docs: [QueryDocumentSnapshot] = []
        docs.reserveCapacity(favouriteIDs.count)

        for chunk in chunks {
            let query = db.collection("photos")
                .whereField(FieldPath.documentID(), in: chunk)
            let snapshot = try await fetchQuery(query)
            docs.append(contentsOf: snapshot.documents)
        }

        let photos = docs
            .map { FeedPhoto(id: $0.documentID, data: $0.data()) }

        return Self.presentFavouritePhotos(photos, visibleGroupIDs: visibleGroupIDs, limit: limit)
    }

    func setFavourite(photoID: String, userID: String, isFavourite: Bool) async throws {
        let ref = db.collection("users").document(userID)
        let payload: [String: Any] = [
            favouritesField: isFavourite
                ? FieldValue.arrayUnion([photoID])
                : FieldValue.arrayRemove([photoID])
        ]
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            ref.setData(payload, merge: true) { error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: ())
            }
        }
    }

    func updatePhotoMetadata(_ photo: FeedPhoto, requesterUID _: String, year: Int, hashtags: [String]) async throws {
        let ref = db.collection("photos").document(photo.id)
        let payload: [String: Any] = [
            "year": year,
            "hashtags": hashtags
        ]

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            ref.setData(payload, merge: true) { error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                continuation.resume(returning: ())
            }
        }
    }

    func deletePhoto(_ photo: FeedPhoto, requesterUID: String) async throws {
        if let postedBy = photo.postedBy, postedBy != requesterUID {
            throw FeedServiceError.cannotDeleteOthersPhotos
        }

        do {
            _ = try await functions.httpsCallable("deletePhoto").call(["photoId": photo.id])
        } catch {
            throw mapDeletePhotoError(error)
        }
    }

    private func fetchQuery(_ query: Query) async throws -> QuerySnapshot {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<QuerySnapshot, Error>) in
            query.getDocuments { snapshot, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let snapshot else {
                    continuation.resume(throwing: NSError(domain: "Firestore", code: -1))
                    return
                }
                continuation.resume(returning: snapshot)
            }
        }
    }

    private func fetchFavouriteIDs(userID: String) async throws -> Set<String> {
        let ref = db.collection("users").document(userID)
        let snapshot = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<DocumentSnapshot, Error>) in
            ref.getDocument { snapshot, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let snapshot else {
                    continuation.resume(throwing: NSError(domain: "Firestore", code: -1))
                    return
                }
                continuation.resume(returning: snapshot)
            }
        }
        let ids = (snapshot.data()?[favouritesField] as? [String]) ?? []
        return Set(ids)
    }

    static func visibleGroupIDs(from groupIDs: [String]) -> [String] {
        var seen: Set<String> = []
        var result: [String] = []
        result.reserveCapacity(Swift.min(groupIDs.count, 10))

        for groupID in groupIDs {
            if seen.contains(groupID) { continue }
            seen.insert(groupID)
            result.append(groupID)
            if result.count == 10 { break }
        }

        return result
    }

    static func presentRecentPhotos(_ photos: [FeedPhoto], favouriteIDs: Set<String>, limit: Int) -> [FeedPhoto] {
        photos
            .map { $0.withFavourite(favouriteIDs.contains($0.id)) }
            .prefix(limit)
            .map { $0 }
    }

    static func presentRecentPhotosFromUnorderedResults(
        _ photos: [FeedPhoto],
        favouriteIDs: Set<String>,
        limit: Int,
        startAfter cursor: FeedPageCursor? = nil
    ) -> [FeedPhoto] {
        Array(filteredRecentPhotosFromUnorderedResults(
            photos,
            favouriteIDs: favouriteIDs,
            startAfter: cursor
        ).prefix(limit))
    }

    static func filteredRecentPhotosFromUnorderedResults(
        _ photos: [FeedPhoto],
        favouriteIDs: Set<String>,
        startAfter cursor: FeedPageCursor? = nil
    ) -> [FeedPhoto] {
        photos
            .filter { photo in
                guard let cursor else { return true }
                return compareFeedPhoto(photo, against: cursor) == .orderedDescending
            }
            .map { $0.withFavourite(favouriteIDs.contains($0.id)) }
            .sorted(by: feedPhotosAreOrderedBefore)
    }

    static func presentFavouritePhotos(_ photos: [FeedPhoto], visibleGroupIDs: [String], limit: Int) -> [FeedPhoto] {
        let visibleGroups = Set(visibleGroupIDs)
        return photos
            .filter { photo in
                guard let groupID = photo.groupID else { return false }
                return visibleGroups.contains(groupID)
            }
            .map { $0.withFavourite(true) }
            .sorted { ($0.createdAt ?? .distantPast) > ($1.createdAt ?? .distantPast) }
            .prefix(limit)
            .map { $0 }
    }

    private static func isMissingIndexError(_ error: Error) -> Bool {
        let nsError = error as NSError
        guard nsError.domain == FirestoreErrorDomain else { return false }
        return nsError.code == FirestoreErrorCode.failedPrecondition.rawValue
    }

    private static func makeNextCursor(from photos: [FeedPhoto]) -> FeedPageCursor? {
        guard let lastPhoto = photos.last, let createdAt = lastPhoto.createdAt else { return nil }
        return FeedPageCursor(createdAt: createdAt, documentID: lastPhoto.id)
    }

    private func mapDeletePhotoError(_ error: Error) -> Error {
        let nsError = error as NSError

        if nsError.domain == FunctionsErrorDomain,
           let code = FunctionsErrorCode(rawValue: nsError.code),
           code == .permissionDenied {
            return FeedServiceError.cannotDeleteOthersPhotos
        }

        return error
    }
}

private func compareFeedPhoto(_ photo: FeedPhoto, against cursor: FeedPageCursor) -> ComparisonResult {
    let photoCreatedAt = photo.createdAt ?? .distantPast
    if photoCreatedAt != cursor.createdAt {
        return photoCreatedAt > cursor.createdAt ? .orderedAscending : .orderedDescending
    }
    if photo.id == cursor.documentID {
        return .orderedSame
    }
    return photo.id > cursor.documentID ? .orderedAscending : .orderedDescending
}

private func feedPhotosAreOrderedBefore(_ lhs: FeedPhoto, _ rhs: FeedPhoto) -> Bool {
    let lhsCreatedAt = lhs.createdAt ?? .distantPast
    let rhsCreatedAt = rhs.createdAt ?? .distantPast
    if lhsCreatedAt != rhsCreatedAt {
        return lhsCreatedAt > rhsCreatedAt
    }
    return lhs.id > rhs.id
}

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else { return [self] }
        var result: [[Element]] = []
        result.reserveCapacity((count + size - 1) / size)
        var index = 0
        while index < count {
            let end = Swift.min(index + size, count)
            result.append(Array(self[index..<end]))
            index += size
        }
        return result
    }
}
