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

enum UploadOverlayRules {
    static func parseYear(from text: String) -> Int? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return Int(trimmed)
    }

    static func canUpload(
        selectedImageCount: Int,
        isUploading: Bool,
        isImportingGooglePhotos: Bool,
        isEstimatingUploadSize: Bool,
        selectedGroupID: String?,
        yearText: String,
        effectiveUsageMB: Double,
        estimatedUploadSizeMB: Double,
        isPremiumActive: Bool
    ) -> Bool {
        selectedImageCount > 0 &&
        !isUploading &&
        !isImportingGooglePhotos &&
        !isEstimatingUploadSize &&
        selectedGroupID != nil &&
        parseYear(from: yearText) != nil &&
        !PlanAccessPolicy.isStorageLimitReached(
            usageMB: effectiveUsageMB,
            isPremiumActive: isPremiumActive
        ) &&
        PlanAccessPolicy.canUpload(
            currentUsageMB: effectiveUsageMB,
            additionalUsageMB: estimatedUploadSizeMB,
            isPremiumActive: isPremiumActive
        )
    }

    static func uploadValidationMessageID(
        currentUserID: String?,
        selectedGroupID: String?,
        yearText: String,
        effectiveUsageMB: Double,
        estimatedUploadSizeMB: Double,
        isPremiumActive: Bool
    ) -> AppMessage.ID? {
        if PlanAccessPolicy.isStorageLimitReached(
            usageMB: effectiveUsageMB,
            isPremiumActive: isPremiumActive
        ) {
            return .storageLimitReached
        }
        guard currentUserID != nil else { return .pleaseSignInFirst }
        guard selectedGroupID != nil else { return .selectGroup }
        guard parseYear(from: yearText) != nil else { return .enterValidYear }
        guard PlanAccessPolicy.canUpload(
            currentUsageMB: effectiveUsageMB,
            additionalUsageMB: estimatedUploadSizeMB,
            isPremiumActive: isPremiumActive
        ) else {
            return .storageLimitReached
        }
        return nil
    }

    static func normalizedHashtags(from input: String) -> [String] {
        let separators = CharacterSet(charactersIn: ",\n\t ")
        return input
            .components(separatedBy: separators)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .map { token -> String in
                let clean = token.hasPrefix("#") ? String(token.dropFirst()) : token
                return clean.lowercased()
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
    @State private var isYearPickerPresented = false
    @State private var yearSelection = Calendar.current.component(.year, from: Date())
    @State private var toastMessage: AppMessage?
    @State private var googlePickerSession: GooglePhotosPickingSession?
    @State private var clearMessageTask: Task<Void, Never>?
    @State private var googleImportTask: Task<Void, Never>?
    @State private var estimatedUploadSizeMB = 0.0
    @State private var isEstimatingUploadSize = false
    @State private var effectiveUsageMB = 0.0

    private let uploadService = UploadService()
    private let groupService = GroupService()
    private let googleAccountService = GoogleAccountService()
    private let googlePhotosPickerService = GooglePhotosPickerService()
    let currentUsageMB: Double
    let isPremiumActive: Bool

    init(currentUsageMB: Double, isPremiumActive: Bool) {
        self.currentUsageMB = currentUsageMB
        self.isPremiumActive = isPremiumActive
        _effectiveUsageMB = State(initialValue: currentUsageMB)
    }

    private var surfaceBackground: Color {
        AppTheme.cardSurfaceBackground(for: colorScheme)
    }
    private var surfaceBorder: Color { AppTheme.cardSurfaceBorder(for: colorScheme) }
    private var primaryText: Color { AppTheme.primaryText(for: colorScheme) }

    private var selectedGroupName: String {
        guard let selectedGroupID else { return "group" }
        return groups.first(where: { $0.id == selectedGroupID })?.name ?? "group"
    }

    private var yearOptions: [Int] {
        Array(2000...Calendar.current.component(.year, from: Date()))
    }

    private var selectedYearLabel: String {
        parsedYear.map(String.init) ?? "year"
    }

    private var parsedYear: Int? {
        UploadOverlayRules.parseYear(from: yearText)
    }

    private var canUpload: Bool {
        UploadOverlayRules.canUpload(
            selectedImageCount: selectedImages.count,
            isUploading: isUploading,
            isImportingGooglePhotos: isImportingGooglePhotos,
            isEstimatingUploadSize: isEstimatingUploadSize,
            selectedGroupID: selectedGroupID,
            yearText: yearText,
            effectiveUsageMB: effectiveUsageMB,
            estimatedUploadSizeMB: estimatedUploadSizeMB,
            isPremiumActive: isPremiumActive
        )
    }

    private var wouldExceedStorageLimit: Bool {
        !selectedImages.isEmpty &&
        !PlanAccessPolicy.canUpload(
            currentUsageMB: effectiveUsageMB,
            additionalUsageMB: estimatedUploadSizeMB,
            isPremiumActive: isPremiumActive
        )
    }

    private var isStorageLimitReached: Bool {
        PlanAccessPolicy.isStorageLimitReached(
            usageMB: effectiveUsageMB,
            isPremiumActive: isPremiumActive
        )
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

                    if isEstimatingUploadSize {
                        HStack(spacing: 10) {
                            ProgressView()
                                .controlSize(.small)
                            Text("Checking storage...")
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
            .onChange(of: selectedImages.count) { _, _ in
                Task { await refreshEstimatedUploadSize() }
            }
            .onChange(of: yearSelection) { _, newValue in
                yearText = String(newValue)
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
                await showStorageLimitToastIfNeeded()
            }
            .sheet(isPresented: $isYearPickerPresented) {
                YearWheelPickerSheet(
                    years: yearOptions,
                    selectedYear: $yearSelection
                )
                .presentationDetents([.height(300)])
                .presentationDragIndicator(.visible)
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
        let tokens = UploadOverlayRules.normalizedHashtags(from: hashtagInput)

        for token in tokens where !hashtags.contains(token) {
            hashtags.append(token)
        }
        hashtagInput = ""
    }

    private func loadImages(from items: [PhotosPickerItem]) async {
        let loaded = await withTaskGroup(of: (Int, UIImage?).self) { group in
            for (index, item) in items.enumerated() {
                group.addTask {
                    guard let data = try? await item.loadTransferable(type: Data.self),
                          let image = UIImage(data: data) else {
                        return (index, nil)
                    }
                    return (index, image)
                }
            }

            var imagesByIndex: [Int: UIImage] = [:]
            for await (index, image) in group {
                if let image {
                    imagesByIndex[index] = image
                }
            }

            return imagesByIndex
                .sorted { $0.key < $1.key }
                .map(\.value)
        }

        await MainActor.run {
            selectedImages = loaded
        }
    }

    @MainActor
    private func upload() async {
        if let messageID = UploadOverlayRules.uploadValidationMessageID(
            currentUserID: Auth.auth().currentUser?.uid,
            selectedGroupID: selectedGroupID,
            yearText: yearText,
            effectiveUsageMB: effectiveUsageMB,
            estimatedUploadSizeMB: estimatedUploadSizeMB,
            isPremiumActive: isPremiumActive
        ) {
            toastMessage = AppMessage(messageID, .error)
            return
        }

        guard let uid = Auth.auth().currentUser?.uid else { return }
        guard let groupID = selectedGroupID else { return }
        guard let year = parsedYear else { return }

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
            effectiveUsageMB += estimatedUploadSizeMB
            estimatedUploadSizeMB = 0
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
        guard !isStorageLimitReached else {
            toastMessage = AppMessage(.storageLimitReached, .error)
            return
        }

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

    @MainActor
    private func refreshEstimatedUploadSize() async {
        guard !selectedImages.isEmpty else {
            estimatedUploadSizeMB = 0
            isEstimatingUploadSize = false
            return
        }

        isEstimatingUploadSize = true
        defer { isEstimatingUploadSize = false }

        do {
            estimatedUploadSizeMB = try await uploadService.estimatedUploadSizeMB(for: selectedImages)
            if wouldExceedStorageLimit {
                toastMessage = AppMessage(.storageLimitReached, .error)
            }
        } catch {
            estimatedUploadSizeMB = 0
        }
    }

    @MainActor
    private func showStorageLimitToastIfNeeded() async {
        guard isStorageLimitReached else { return }
        toastMessage = AppMessage(.storageLimitReached, .error)
    }
}
