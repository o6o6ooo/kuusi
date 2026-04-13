import SwiftUI

struct FeedEditError: Error {
    let toastMessage: AppMessage
}

struct EditOverlayView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    let photo: FeedPhoto
    let onSave: @MainActor (_ year: Int, _ hashtags: [String]) async -> Result<Void, FeedEditError>

    @State private var yearText: String
    @State private var hashtagInput = ""
    @State private var hashtags: [String]
    @State private var toastMessage: AppMessage?
    @State private var isSaving = false
    @State private var clearToastTask: Task<Void, Never>?

    init(photo: FeedPhoto, onSave: @escaping @MainActor (_ year: Int, _ hashtags: [String]) async -> Result<Void, FeedEditError>) {
        self.photo = photo
        self.onSave = onSave
        _yearText = State(initialValue: photo.year.map(String.init) ?? "")
        _hashtags = State(initialValue: photo.hashtags)
    }

    private var cardBackground: Color { AppTheme.cardBackground(for: colorScheme) }
    private var fieldBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.08) : Color.white.opacity(0.85)
    }
    private var primaryText: Color { AppTheme.primaryText(for: colorScheme) }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Spacer()
                    Button("Save") {
                        Task {
                            await save()
                        }
                    }
                    .buttonStyle(.appPrimaryCapsule)
                    .disabled(isSaving)
                }

                VStack(spacing: 12) {
                    yearField
                    hashtagsField
                }
                .padding(14)
                .background(cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 20))

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
        }
    }

    private var yearField: some View {
        TextField("year", text: $yearText)
            .keyboardType(.numberPad)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled(true)
            .padding(.horizontal, 16)
            .frame(height: 62)
            .background(fieldBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .foregroundStyle(primaryText)
    }

    private var hashtagsField: some View {
        TextField("hashtags", text: $hashtagInput)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled(true)
            .padding(.horizontal, 16)
            .frame(height: 62)
            .background(fieldBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .foregroundStyle(primaryText)
            .onSubmit {
                addHashtagsFromInput()
            }
            .onChange(of: hashtagInput) { _, newValue in
                if newValue.contains("\n") || newValue.contains(",") {
                    addHashtagsFromInput()
                }
            }
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
        let trimmedYear = yearText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let year = Int(trimmedYear), (1900...3000).contains(year) else {
            showToastMessage(AppMessage(.enterValidYear, .error))
            return
        }

        isSaving = true
        defer { isSaving = false }

        switch await onSave(year, hashtags) {
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
}
