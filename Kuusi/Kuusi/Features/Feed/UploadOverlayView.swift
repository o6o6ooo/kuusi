import FirebaseAuth
import PhotosUI
import SwiftUI
import UIKit

struct UploadOverlayView: View {
    @Environment(\.colorScheme) private var colorScheme

    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var selectedImages: [UIImage] = []
    @State private var groups: [GroupSummary] = []
    @State private var selectedGroupID: String?
    @State private var yearText = String(Calendar.current.component(.year, from: Date()))
    @State private var hashtagInput = ""
    @State private var hashtags: [String] = []
    @State private var isUploading = false
    @State private var isImportingGooglePhotos = false
    @State private var inlineMessage: InlineMessage?
    @State private var googlePickerSession: GooglePhotosPickingSession?
    @State private var clearMessageTask: Task<Void, Never>?
    @State private var googleImportTask: Task<Void, Never>?

    private let uploadService = UploadService()
    private let groupService = GroupService()
    private let googleAccountService = GoogleAccountService()
    private let googlePhotosPickerService = GooglePhotosPickerService()

    private var cardBackground: Color { AppTheme.cardBackground(for: colorScheme) }
    private var fieldBackground: Color {
        colorScheme == .dark ? Color.white.opacity(0.08) : Color.white.opacity(0.85)
    }
    private var primaryText: Color { AppTheme.primaryText(for: colorScheme) }

    private var selectedGroupName: String {
        guard let selectedGroupID else { return "group" }
        return groups.first(where: { $0.id == selectedGroupID })?.name ?? "group"
    }

    private var parsedYear: Int? {
        let trimmed = yearText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return Int(trimmed)
    }

    private var canUpload: Bool {
        !selectedImages.isEmpty &&
        !isUploading &&
        selectedGroupID != nil &&
        parsedYear != nil
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    topContent

                    VStack(spacing: 12) {
                        groupPicker
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

                    HStack {
                        Spacer()
                        Button {
                            Task { await upload() }
                        } label: {
                            if isUploading {
                                ProgressView()
                                    .tint(.white)
                                    .frame(minWidth: 54)
                            } else {
                                Text("Upload")
                            }
                        }
                        .frame(minWidth: 96)
                        .buttonStyle(.appPrimaryCapsule)
                        .controlSize(.regular)
                        .disabled(!canUpload)
                    }

                    if let inlineMessage {
                        InlineMessageView(message: inlineMessage)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .foregroundStyle(primaryText)
            }
            .screenTheme()
            .toolbar(.hidden, for: .navigationBar)
            .onChange(of: pickerItems) { _, newValue in
                Task { await loadImages(from: newValue) }
            }
            .onChange(of: inlineMessage) { _, newValue in
                scheduleMessageAutoClear(for: newValue)
            }
            .onDisappear {
                clearMessageTask?.cancel()
                clearMessageTask = nil
                googleImportTask?.cancel()
                googleImportTask = nil
            }
            .task {
                loadCachedGroupsOnly()
            }
            .sheet(item: $googlePickerSession, onDismiss: cancelGoogleImportIfNeeded) { session in
                SafariSheetView(url: session.pickerURL)
            }
        }
    }

    @ViewBuilder
    private var topContent: some View {
        if selectedImages.isEmpty {
            VStack(spacing: 12) {
                PhotosPicker(
                    selection: $pickerItems,
                    maxSelectionCount: 10,
                    matching: .images
                ) {
                    HStack(spacing: 10) {
                        Image(systemName: "photo.on.rectangle")
                            .font(.title3.weight(.semibold))
                        Text("Import from photo library")
                            .font(.headline.weight(.semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                }
                .buttonStyle(.plain)
                .padding(.top, 6)

                Button {
                    Task { await importFromGooglePhotos() }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "globe")
                            .font(.title3.weight(.semibold))
                        if isImportingGooglePhotos {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Text("Import from Google Photos")
                                .font(.headline.weight(.semibold))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                }
                .buttonStyle(.plain)
                .disabled(isImportingGooglePhotos)
            }
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(Array(selectedImages.enumerated()), id: \.offset) { idx, image in
                        ZStack(alignment: .topLeading) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 120, height: 120)
                                .clipShape(RoundedRectangle(cornerRadius: 18))

                            Button {
                                selectedImages.remove(at: idx)
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(primaryText)
                                    .frame(width: 26, height: 26)
                                    .background(.ultraThinMaterial)
                                    .clipShape(Circle())
                            }
                            .buttonStyle(.plain)
                            .offset(x: -8, y: -8)
                        }
                    }
                }
                .padding(.top, 6)
                .padding(.leading, 8)
            }
            .frame(height: 132)
        }
    }

    private var groupPicker: some View {
        Menu {
            if groups.isEmpty {
                Text("No groups")
            } else {
                ForEach(groups) { group in
                    Button(group.name) {
                        selectedGroupID = group.id
                    }
                }
            }
        } label: {
            HStack {
                Text(selectedGroupName)
                    .foregroundStyle(.secondary)
                Spacer()
                Image(systemName: "checkmark")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(primaryText)
            }
            .padding(.horizontal, 16)
            .frame(height: 62)
            .background(fieldBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
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
    }

    private var hashtagsField: some View {
        TextField("hashtags", text: $hashtagInput)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled(true)
            .padding(.horizontal, 16)
            .frame(height: 62)
            .background(fieldBackground)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .onSubmit {
                addHashtagsFromInput()
            }
            .onChange(of: hashtagInput) { _, newValue in
                if newValue.contains("\n") || newValue.contains(",") {
                    addHashtagsFromInput()
                }
            }
    }

    private func loadCachedGroupsOnly() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let cached = groupService.cachedGroups(for: uid)
        groups = cached
        if selectedGroupID == nil {
            selectedGroupID = cached.first?.id
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
            inlineMessage = .error("Please sign in first.")
            return
        }

        guard let groupID = selectedGroupID else {
            inlineMessage = .error("Select a group.")
            return
        }

        guard let year = parsedYear else {
            inlineMessage = .error("Enter a valid year.")
            return
        }

        isUploading = true
        defer { isUploading = false }

        do {
            try await uploadService.upload(
                images: selectedImages,
                userID: uid,
                groupID: groupID,
                year: year,
                hashtags: hashtags
            )
            selectedImages = []
            pickerItems = []
            hashtagInput = ""
            hashtags = []
            inlineMessage = .success("Upload completed.")
        } catch {
            inlineMessage = .error(error.localizedDescription)
        }
    }

    private func scheduleMessageAutoClear(for value: InlineMessage?) {
        clearMessageTask?.cancel()
        clearMessageTask = InlineMessageAutoClear.schedule(
            for: value,
            currentMessage: { inlineMessage },
            clear: { inlineMessage = nil }
        )
    }

    @MainActor
    private func importFromGooglePhotos() async {
        guard let presentingViewController = UIApplication.topViewController() else {
            inlineMessage = .error("Could not open Google Photos.")
            return
        }

        isImportingGooglePhotos = true

        do {
            let authorizedSession = try await googleAccountService.preparePickerAuthorization(
                presentingViewController: presentingViewController
            )
            let session = try await googlePhotosPickerService.createSession(
                accessToken: authorizedSession.accessToken,
                maxItemCount: 10
            )

            googlePickerSession = session
            googleImportTask?.cancel()
            googleImportTask = Task {
                do {
                    let images = try await googlePhotosPickerService.waitForSelection(
                        session: session,
                        accessToken: authorizedSession.accessToken
                    )
                    await MainActor.run {
                        selectedImages = images
                        pickerItems = []
                        googlePickerSession = nil
                        isImportingGooglePhotos = false
                        inlineMessage = .success("\(images.count) photos imported from Google Photos")
                    }
                } catch is CancellationError {
                    await MainActor.run {
                        isImportingGooglePhotos = false
                    }
                } catch {
                    await MainActor.run {
                        googlePickerSession = nil
                        isImportingGooglePhotos = false
                        inlineMessage = .error(error.localizedDescription)
                    }
                }
            }
        } catch {
            isImportingGooglePhotos = false
            inlineMessage = .error(error.localizedDescription)
        }
    }

    @MainActor
    private func cancelGoogleImportIfNeeded() {
        guard isImportingGooglePhotos else { return }
        googleImportTask?.cancel()
        googleImportTask = nil
        googlePickerSession = nil
        isImportingGooglePhotos = false
    }
}
