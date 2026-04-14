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
    @State private var isYearPickerPresented = false
    @State private var yearSelection = Calendar.current.component(.year, from: Date())
    @State private var toastMessage: AppMessage?
    @State private var isSaving = false
    @State private var clearToastTask: Task<Void, Never>?

    init(photo: FeedPhoto, onSave: @escaping @MainActor (_ year: Int, _ hashtags: [String]) async -> Result<Void, FeedEditError>) {
        self.photo = photo
        self.onSave = onSave
        _yearText = State(initialValue: photo.year.map(String.init) ?? "")
        _hashtags = State(initialValue: photo.hashtags)
    }

    private var surfaceBackground: Color {
        AppTheme.pageBackground(for: colorScheme)
            .opacity(0.7)
    }
    private var surfaceBorder: Color { AppTheme.cardBackground(for: colorScheme) }
    private var primaryText: Color { AppTheme.primaryText(for: colorScheme) }
    private var yearOptions: [Int] {
        Array(2000...Calendar.current.component(.year, from: Date()))
    }
    private var parsedYear: Int? {
        Int(yearText.trimmingCharacters(in: .whitespacesAndNewlines))
    }
    private var selectedYearLabel: String {
        parsedYear.map(String.init) ?? "year"
    }

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
            .onChange(of: yearSelection) { _, newValue in
                yearText = String(newValue)
            }
            .onDisappear {
                clearToastTask?.cancel()
                clearToastTask = nil
            }
            .appToastMessage(toastMessage) {
                toastMessage = nil
            }
            .appToastHost()
            .sheet(isPresented: $isYearPickerPresented) {
                YearWheelPickerSheet(
                    years: yearOptions,
                    selectedYear: $yearSelection
                )
                .presentationDetents([.height(300)])
                .presentationDragIndicator(.visible)
            }
        }
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

    private var yearField: some View {
        Button {
            yearSelection = parsedYear ?? Calendar.current.component(.year, from: Date())
            isYearPickerPresented = true
        } label: {
            liftedField {
                Text(selectedYearLabel)
                    .foregroundStyle(parsedYear == nil ? .secondary : primaryText)
                Spacer()
                Image(systemName: "chevron.up.chevron.down")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
    }

    private var hashtagsField: some View {
        liftedField {
            TextField("hashtags", text: $hashtagInput)
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
