import Foundation
import UIKit

struct GooglePhotosPickingSession: Identifiable {
    let id: String
    let pickerURL: URL
    let pollingInterval: TimeInterval
    let timeout: TimeInterval
}

enum GooglePhotosPickerError: Error {
    case invalidSessionURL
    case noSelectedPhotos
    case timedOut
    case invalidResponse
    case requestFailed(String)
}

final class GooglePhotosPickerService {
    private let session = URLSession.shared
    private let baseAPIURL = URL(string: "https://photospicker.googleapis.com/v1")!

    func createSession(accessToken: String, maxItemCount: Int = 10) async throws -> GooglePhotosPickingSession {
        let requestBody = SessionCreateRequest(
            pickingConfig: SessionPickingConfig(maxItemCount: maxItemCount)
        )
        let response: PickingSessionResponse = try await sendRequest(
            path: "sessions",
            method: "POST",
            accessToken: accessToken,
            body: requestBody
        )

        guard
            let sessionID = response.id,
            let pickerURI = response.pickerUri,
            let pickerURL = URL(string: pickerURI)
        else {
            throw GooglePhotosPickerError.invalidSessionURL
        }

        return GooglePhotosPickingSession(
            id: sessionID,
            pickerURL: pickerURL,
            pollingInterval: response.pollingConfig?.pollInterval.durationSeconds ?? 2,
            timeout: response.pollingConfig?.timeoutIn.durationSeconds ?? 180
        )
    }

    func waitForSelection(session pickingSession: GooglePhotosPickingSession, accessToken: String) async throws -> [UIImage] {
        let deadline = Date().addingTimeInterval(max(pickingSession.timeout, 30))
        var pollingInterval = max(pickingSession.pollingInterval, 1)

        while Date() < deadline {
            try Task.checkCancellation()
            let response: PickingSessionResponse = try await sendRequest(
                path: "sessions/\(pickingSession.id)",
                method: "GET",
                accessToken: accessToken
            )

            if response.mediaItemsSet == true {
                let mediaItems = try await listMediaItems(sessionID: pickingSession.id, accessToken: accessToken)
                let images = try await downloadImages(from: mediaItems, accessToken: accessToken)
                guard !images.isEmpty else {
                    throw GooglePhotosPickerError.noSelectedPhotos
                }
                return images
            }

            if let nextInterval = response.pollingConfig?.pollInterval.durationSeconds {
                pollingInterval = max(nextInterval, 1)
            }

            try await Task.sleep(nanoseconds: UInt64(pollingInterval * 1_000_000_000))
        }

        throw GooglePhotosPickerError.timedOut
    }

    private func listMediaItems(sessionID: String, accessToken: String) async throws -> [PickerMediaItem] {
        var items: [PickerMediaItem] = []
        var nextPageToken: String?

        repeat {
            var queryItems = [URLQueryItem(name: "sessionId", value: sessionID)]
            if let nextPageToken {
                queryItems.append(URLQueryItem(name: "pageToken", value: nextPageToken))
            }

            let response: PickerMediaItemsResponse = try await sendRequest(
                path: "mediaItems",
                method: "GET",
                queryItems: queryItems,
                accessToken: accessToken
            )
            items.append(contentsOf: response.mediaItems ?? [])
            nextPageToken = response.nextPageToken
        } while nextPageToken != nil

        return items
    }

    private func downloadImages(from mediaItems: [PickerMediaItem], accessToken: String) async throws -> [UIImage] {
        let imageItems = mediaItems.filter { ($0.mediaFile?.mimeType ?? "").hasPrefix("image/") }

        return try await withThrowingTaskGroup(of: UIImage?.self) { group in
            for item in imageItems {
                guard let baseURL = item.mediaFile?.baseUrl else { continue }
                group.addTask { [session] in
                    let downloadURL = URL(string: "\(baseURL)=w2400-h2400")!
                    var request = URLRequest(url: downloadURL)
                    request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
                    let (data, _) = try await session.data(for: request)
                    return UIImage(data: data)
                }
            }

            var images: [UIImage] = []
            for try await image in group {
                if let image {
                    images.append(image)
                }
            }
            return images
        }
    }

    private func sendRequest<Response: Decodable, Body: Encodable>(
        path: String,
        method: String,
        queryItems: [URLQueryItem] = [],
        accessToken: String,
        body: Body?
    ) async throws -> Response {
        var components = URLComponents(url: baseAPIURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }

        var request = URLRequest(url: components.url!)
        request.httpMethod = method
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        if let body {
            request.httpBody = try JSONEncoder().encode(body)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        let (data, response) = try await session.data(for: request)
        try validateResponse(data: data, response: response)
        return try JSONDecoder().decode(Response.self, from: data)
    }

    private func sendRequest<Response: Decodable>(
        path: String,
        method: String,
        queryItems: [URLQueryItem] = [],
        accessToken: String
    ) async throws -> Response {
        var components = URLComponents(url: baseAPIURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }

        var request = URLRequest(url: components.url!)
        request.httpMethod = method
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)
        try validateResponse(data: data, response: response)
        return try JSONDecoder().decode(Response.self, from: data)
    }

    private func validateResponse(data: Data, response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw GooglePhotosPickerError.invalidResponse
        }

        guard (200 ..< 300).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "Google Photos request failed."
            throw GooglePhotosPickerError.requestFailed(message)
        }
    }
}

private struct SessionCreateRequest: Encodable {
    let pickingConfig: SessionPickingConfig
}

private struct SessionPickingConfig: Encodable {
    let maxItemCount: Int
}

private struct PickingSessionResponse: Decodable {
    let id: String?
    let pickerUri: String?
    let pollingConfig: SessionPollingConfig?
    let mediaItemsSet: Bool?
}

private struct SessionPollingConfig: Decodable {
    let pollInterval: String?
    let timeoutIn: String?
}

private struct PickerMediaItemsResponse: Decodable {
    let mediaItems: [PickerMediaItem]?
    let nextPageToken: String?
}

private struct PickerMediaItem: Decodable {
    let id: String?
    let mediaFile: PickerMediaFile?
}

private struct PickerMediaFile: Decodable {
    let baseUrl: String?
    let mimeType: String?
    let filename: String?
}

private extension Optional where Wrapped == String {
    var durationSeconds: TimeInterval {
        guard let value = self else { return 0 }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasSuffix("s") else { return 0 }
        return TimeInterval(trimmed.dropLast()) ?? 0
    }
}
