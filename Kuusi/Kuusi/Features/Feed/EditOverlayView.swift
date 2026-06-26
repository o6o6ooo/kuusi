import SwiftUI

struct FeedEditError: Error {
    let toastMessage: AppMessage
}

struct EditOverlayView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    let photo: FeedPhoto
    let onSave: @MainActor (_ update: FeedPhotoMetadataUpdate) async -> Result<Void, FeedEditError>

    @State private var captionInput: String
    @State private var hashtagInput = ""
    @State private var hashtags: [String]
    @State private var isDatePickerPresented = false
    @State private var dateSelection: Date
    @State private var toastMessage: AppMessage?
    @State private var isSaving = false
    @State private var clearToastTask: Task<Void, Never>?

    init(photo: FeedPhoto, onSave: @escaping @MainActor (_ update: FeedPhotoMetadataUpdate) async -> Result<Void, FeedEditError>) {
        self.photo = photo
        self.onSave = onSave
        _captionInput = State(initialValue: photo.caption ?? "")
        _hashtags = State(initialValue: photo.hashtags)
        _dateSelection = State(initialValue: photo.date ?? Date())
    }

    private var surfaceBackground: Color {
        AppTheme.cardSurfaceBackground(for: colorScheme)
    }
    private var surfaceBorder: Color { AppTheme.cardSurfaceBorder(for: colorScheme) }
    private var primaryText: Color { AppTheme.primaryText(for: colorScheme) }
    private var selectedDateLabel: String {
        Self.dateFormatter.string(from: dateSelection)
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 14) {
                header

                HStack {
                    Spacer()
                    photoPreview
                    Spacer()
                }

                VStack(spacing: 12) {
                    dateField
                    captionField
                    hashtagsField
                }

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

                Spacer()
            }
            .padding(16)
            .padding(.top, 12)
            .appOverlayTheme()
            .toolbar(.hidden, for: .navigationBar)
            .onDisappear {
                clearToastTask?.cancel()
                clearToastTask = nil
            }
            .appToastMessage(toastMessage) {
                toastMessage = nil
            }
            .appToastHost()
            .sheet(isPresented: $isDatePickerPresented) {
                PhotoDatePickerSheet(selectedDate: $dateSelection)
                    .presentationDetents([.height(520)])
                    .presentationDragIndicator(.visible)
            }
        }
    }

    private var header: some View {
        ZStack {
            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .frame(width: 40, height: 40)
                        .appFeedGlassCircle()
                }
                .buttonStyle(.plain)
                .accessibilityLabel("common.close")

                Spacer()

                saveButton
            }

            Text("photo.menu.edit")
                .font(.title3.weight(.bold))
        }
        .padding(.bottom, 4)
    }

    private var saveButton: some View {
        Button("common.save") {
            Task {
                await save()
            }
        }
        .buttonStyle(.appPrimaryCapsule(isLoading: isSaving))
        .disabled(isSaving)
    }

    private var photoPreview: some View {
        CachedRemoteImageView(source: photoImageSource) { image in
            image
                .resizable()
                .scaledToFill()
        } placeholder: {
            ProgressView()
        }
        .frame(width: 120, height: 120)
        .background(surfaceBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private var photoImageSource: FeedImageSource? {
        if let thumbnailStoragePath = photo.thumbnailStoragePath, !thumbnailStoragePath.isEmpty {
            return .storagePath(thumbnailStoragePath)
        }

        if let previewStoragePath = photo.previewStoragePath, !previewStoragePath.isEmpty {
            return .storagePath(previewStoragePath)
        }

        return nil
    }

    private func liftedField<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> some View {
        HStack(spacing: 12) {
            content()
        }
        .padding(.horizontal, 16)
        .frame(height: 62)
        .background(surfaceBackground)
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .stroke(surfaceBorder, lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(
            color: Color.black.opacity(colorScheme == .dark ? 0.18 : 0.08),
            radius: colorScheme == .dark ? 10 : 14,
            x: 0,
            y: 4
        )
    }

    private var hashtagsField: some View {
        liftedField {
            TextField("photo.hashtags.placeholder", text: $hashtagInput)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                .foregroundStyle(primaryText)
        }
            .onSubmit {
                addHashtagsFromInput()
            }
            .onChange(of: hashtagInput) { _, newValue in
                if newValue.contains("\n") || newValue.contains(",") {
                    addHashtagsFromInput()
                }
            }
    }

    private var captionField: some View {
        liftedField {
            TextField("photo.caption.placeholder", text: $captionInput)
                .lineLimit(1)
                .foregroundStyle(primaryText)
        }
            .onChange(of: captionInput) { _, newValue in
                limitCaptionInput(newValue)
            }
    }

    private var dateField: some View {
        Button {
            isDatePickerPresented = true
        } label: {
            liftedField {
                VStack(alignment: .leading, spacing: 4) {
                    Text("photo.date.label")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(selectedDateLabel)
                        .foregroundStyle(primaryText)
                }
                Spacer()
                Image(systemName: "calendar")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
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
        isSaving = true
        defer { isSaving = false }

        switch await onSave(FeedPhotoMetadataUpdate(
            date: dateSelection,
            hashtags: hashtags,
            rawCaption: captionInput
        )) {
        case .success:
            dismiss()
        case .failure(let error):
            showToastMessage(error.toastMessage)
        }
    }

    private func showToastMessage(_ message: AppMessage) {
        clearToastTask?.cancel()
        toastMessage = message
        clearToastTask = AppMessageAutoClear.schedule(
            for: message,
            currentMessage: { toastMessage },
            clear: { toastMessage = nil }
        )
    }

    private func limitCaptionInput(_ value: String) {
        guard value.count > FeedPhotoMetadataUpdate.captionCharacterLimit else { return }
        captionInput = String(value.prefix(FeedPhotoMetadataUpdate.captionCharacterLimit))
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}

private struct PhotoDatePickerSheet: View {
    @Binding var selectedDate: Date

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                DatePicker(
                    String(localized: "photo.date.title"),
                    selection: $selectedDate,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .datePickerStyle(.graphical)
                .labelsHidden()
            }
            .padding(16)
            .navigationTitle("photo.date.title")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
