import FirebaseAuth
import PhotosUI
import SwiftUI
import UIKit

struct UploadView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var selectedImages: [UIImage] = []
    @State private var isUploading = false
    @State private var message: String?
    @State private var isError = false

    private let uploadService = UploadService()
    private var cardBackground: Color { AppTheme.cardBackground(for: colorScheme) }
    private var primaryText: Color { AppTheme.primaryText(for: colorScheme) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    PhotosPicker(
                        selection: $pickerItems,
                        maxSelectionCount: 10,
                        matching: .images
                    ) {
                        Label("Choose photos", systemImage: "photo.badge.plus")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)

                    if !selectedImages.isEmpty {
                        Text("\(selectedImages.count) selected")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        ScrollView(.horizontal) {
                            HStack(spacing: 10) {
                                ForEach(Array(selectedImages.enumerated()), id: \.offset) { idx, image in
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 84, height: 84)
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                        .overlay(alignment: .topTrailing) {
                                            Button {
                                                selectedImages.remove(at: idx)
                                            } label: {
                                                Image(systemName: "xmark.circle.fill")
                                                    .foregroundStyle(.white, .black.opacity(0.7))
                                            }
                                            .padding(4)
                                        }
                                }
                            }
                        }
                    }

                    Button {
                        Task { await upload() }
                    } label: {
                        if isUploading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Upload")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(selectedImages.isEmpty || isUploading)

                    if let message {
                        Text(message)
                            .font(.footnote)
                            .foregroundStyle(isError ? AppTheme.errorText : primaryText.opacity(0.8))
                    }
                }
                .padding()
                .foregroundStyle(primaryText)
                .background(cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .navigationTitle("Upload")
            .navigationBarTitleDisplayMode(.inline)
            .screenTheme()
            .onChange(of: pickerItems) { _, newValue in
                Task {
                    await loadImages(from: newValue)
                }
            }
        }
    }

    @MainActor
    private func loadImages(from items: [PhotosPickerItem]) async {
        var loaded: [UIImage] = []
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                loaded.append(image)
            }
        }
        selectedImages = loaded
    }

    @MainActor
    private func upload() async {
        guard let uid = Auth.auth().currentUser?.uid else {
            message = "Please sign in first."
            isError = true
            return
        }
        isUploading = true
        defer { isUploading = false }

        do {
            try await uploadService.upload(images: selectedImages, userID: uid)
            selectedImages = []
            pickerItems = []
            message = "Upload completed."
            isError = false
        } catch {
            message = error.localizedDescription
            isError = true
        }
    }
}
