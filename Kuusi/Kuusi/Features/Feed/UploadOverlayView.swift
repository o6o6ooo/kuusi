import FirebaseAuth
import PhotosUI
import SwiftUI
import UIKit

private extension GoogleAccountError {
    var appMessageID: AppMessage.ID {
        switch self {
        case .missingFirebaseUser:
            return .pleaseSignInFirst
        case .missingClientID:
            return .googleSignInNotConfigured
        case .missingGoogleIDToken:
            return .googleSignInReturnedInvalidToken
        case .missingGoogleEmail:
            return .googleSignInReturnedIncompleteAccount
        case .noLinkedGoogleAccount:
            return .noLinkedGoogleAccount
        case .mismatchedLinkedAccount:
            return .googleAccountMismatch
        }
    }
}

private extension GooglePhotosPickerError {
    var appMessageID: AppMessage.ID {
        switch self {
        case .invalidSessionURL:
            return .googlePhotosPickerReturnedInvalidLink
        case .noSelectedPhotos:
            return .noPhotosSelectedFromGooglePhotos
        case .timedOut:
            return .googlePhotosPickerTimedOut
        case .invalidResponse, .requestFailed:
            return .googlePhotosRequestFailed
        }
    }
}

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
    @State private var toastMessage: AppMessage?
    @State private var googlePickerSession: GooglePhotosPickingSession?
    @State private var clearMessageTask: Task<Void, Never>?
    @State private var googleImportTask: Task<Void, Never>?

    private let uploadService = UploadService()
    private let groupService = GroupService()
    private let googleAccountService = GoogleAccountService()
    private let googlePhotosPickerService = GooglePhotosPickerService()

    private var surfaceBackground: Color {
        AppTheme.pageBackground(for: colorScheme)
            .opacity(0.7)
    }
    private var surfaceBorder: Color { AppTheme.cardBackground(for: colorScheme) }
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
        !isImportingGooglePhotos &&
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

                    if isImportingGooglePhotos {
                        HStack(spacing: 10) {
                            ProgressView()
                                .controlSize(.small)
                            Text("Importing photos from Google Photos...")
                                .font(.footnote.weight(.medium))
                                .foregroundStyle(.secondary)
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
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .foregroundStyle(primaryText)
            }
            .appOverlayTheme()
            .toolbar(.hidden, for: .navigationBar)
            .onChange(of: pickerItems) { _, newValue in
                Task { await loadImages(from: newValue) }
            }
            .onChange(of: toastMessage) { _, newValue in
                scheduleMessageAutoClear(for: newValue)
            }
            .onDisappear {
                clearMessageTask?.cancel()
                clearMessageTask = nil
                googleImportTask?.cancel()
                googleImportTask = nil
            }
            .appToastMessage(toastMessage) {
                toastMessage = nil
            }
            .appToastHost()
            .task {
                loadCachedGroupsOnly()
            }
            .sheet(item: $googlePickerSession) { session in
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
                    importRow(
                        title: "Import from photo library",
                        systemImage: "photo.on.rectangle"
                    )
                }
                .buttonStyle(.plain)
                .padding(.top, 6)

                Button {
                    Task { await importFromGooglePhotos() }
                } label: {
                    importRow(
                        title: "Import from Google Photos",
                        systemImage: "globe",
                        showsProgress: isImportingGooglePhotos
                    )
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

    private func importRow(
        title: String,
        systemImage: String,
        showsProgress: Bool = false
    ) -> some View {
        HStack(spacing: 10) {
            if showsProgress {
                ProgressView()
                    .controlSize(.small)
                    .frame(width: 24)
            } else {
                Image(systemName: systemImage)
                    .font(.title3.weight(.semibold))
                    .frame(width: 24)
            }

            Text(title)
                .font(.headline.weight(.semibold))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(surfaceBackground)
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .stroke(surfaceBorder, lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(
            color: Color.black.opacity(colorScheme == .dark ? 0.18 : 0.08),
            radius: colorScheme == .dark ? 12 : 16,
            x: 0,
            y: 4
        )
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
            liftedField {
                Text(selectedGroupName)
                    .foregroundStyle(.secondary)
                Spacer()
                Image(systemName: "chevron.up.chevron.down")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
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
        TextField("hashtags", text: $hashtagInput)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled(true)
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
            toastMessage = AppMessage(.pleaseSignInFirst, .error)
            return
        }

        guard let groupID = selectedGroupID else {
            toastMessage = AppMessage(.selectGroup, .error)
            return
        }

        guard let year = parsedYear else {
            toastMessage = AppMessage(.enterValidYear, .error)
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
            toastMessage = AppMessage(.uploadCompleted, .success)
        } catch {
            toastMessage = AppMessage(.failedToLoadImage, .error)
        }
    }

    private func scheduleMessageAutoClear(for value: AppMessage?) {
        clearMessageTask?.cancel()
        clearMessageTask = AppMessageAutoClear.schedule(
            for: value,
            currentMessage: { toastMessage },
            clear: { toastMessage = nil }
        )
    }

    @MainActor
    private func importFromGooglePhotos() async {
        guard let presentingViewController = UIApplication.topViewController() else {
            toastMessage = AppMessage(.couldNotOpenGooglePhotos, .error)
            return
        }

        isImportingGooglePhotos = true
        toastMessage = nil

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
                        googleImportTask = nil
                        isImportingGooglePhotos = false
                        toastMessage = AppMessage(.photosImportedFromGooglePhotos(images.count), .success)
                    }
                } catch is CancellationError {
                    await MainActor.run {
                        googleImportTask = nil
                        isImportingGooglePhotos = false
                    }
                } catch let error as GooglePhotosPickerError {
                    await MainActor.run {
                        googlePickerSession = nil
                        googleImportTask = nil
                        isImportingGooglePhotos = false
                        toastMessage = AppMessage(error.appMessageID, .error)
                    }
                } catch {
                    await MainActor.run {
                        googlePickerSession = nil
                        googleImportTask = nil
                        isImportingGooglePhotos = false
                        toastMessage = AppMessage(.failedToImportFromGooglePhotos, .error)
                    }
                }
            }
        } catch let error as GoogleAccountError {
            isImportingGooglePhotos = false
            toastMessage = AppMessage(error.appMessageID, .error)
        } catch let error as GooglePhotosPickerError {
            isImportingGooglePhotos = false
            toastMessage = AppMessage(error.appMessageID, .error)
        } catch {
            isImportingGooglePhotos = false
            toastMessage = AppMessage(.failedToImportFromGooglePhotos, .error)
        }
    }
}
