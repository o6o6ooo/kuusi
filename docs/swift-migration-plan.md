# Kuusi React Native -> SwiftUI Migration Plan

## Goal
- Rebuild the current iOS app as a native SwiftUI app.
- Keep Firebase backend/data model compatible so users/data can be reused.
- Migrate in phases so auth + photo feed works first, then posting, then user/group settings.

## Current RN Feature Map
- Root flow: `Onboarding -> SignIn -> MainTabs`
- Tabs: `Home`, `Browse`, `Post`, `User`
- Firebase usage:
  - Auth: Google Sign-In + Firebase Auth
  - Firestore: users/groups/photos/hashtags
  - Storage: image uploads (preview + thumbnail)

## Firebase Data Model (from existing code)

### `users/{uid}`
- `name: string`
- `email: string`
- `icon: string` (emoji)
- `bgColour: string` (hex)
- `premium: boolean`
- `plan?: string`
- `nextBillingDate?: timestamp`
- `upload_count: number`
- `upload_total_mb: number`
- `groups: string[]`
- `createdAt?: timestamp`
- `updatedAt?: timestamp`

### `groups/{groupId}`
- `name: string`
- `password: string`
- `members: string[]`
- `createdAt: timestamp`

### `photos/{photoId}`
- `photo_url: string`
- `thumbnail_url: string`
- `group_id: string`
- `posted_by: string`
- `year: number`
- `hashtags: string[]`
- `size_mb: number`
- `created_at: timestamp`

### `hashtags/{docId}`
- `hashtag: string`
- `group_id: string`
- `user_id: string`
- `show_in_feed: boolean`
- `updated_at: timestamp`

## Recommended Native Stack
- UI: SwiftUI
- Navigation: `NavigationStack` + `TabView`
- Concurrency: `async/await`
- Firebase iOS SDK:
  - `FirebaseAuth`
  - `FirebaseFirestore`
  - `FirebaseStorage`
- Sign-in:
  - `GoogleSignIn` SDK + Firebase credential exchange
  - (Optional) add Apple Sign In later
- Image handling:
  - `PhotosPicker`
  - thumbnail/preview generation via `CoreGraphics` or `UIKit` image resize

## Proposed iOS Project Structure
- `apps/ios-native/KuusiApp/`
  - `App/`
    - `KuusiApp.swift`
    - `AppState.swift`
  - `Core/`
    - `Firebase/FirebaseClient.swift`
    - `Models/` (`User.swift`, `Group.swift`, `Photo.swift`, `Hashtag.swift`)
    - `Services/`
      - `AuthService.swift`
      - `UserService.swift`
      - `PhotoService.swift`
      - `GroupService.swift`
      - `StorageService.swift`
  - `Features/`
    - `Onboarding/`
    - `Auth/`
    - `Home/`
    - `Post/`
    - `User/`
    - `Browse/`

## Migration Phases

### Phase 1 (MVP, first delivery)
- Setup new Xcode project (SwiftUI lifecycle).
- Install Firebase + Google Sign-In (SPM).
- Configure `GoogleService-Info.plist`.
- Implement:
  - Onboarding (simple static)
  - Google Sign-In
  - create/read `users/{uid}`
  - Main `TabView` shell
  - Home feed read (`photos` query + group/hashtag filters)

Success criteria:
- Existing account can sign in.
- Existing photos from Firestore/Storage are visible.

### Phase 2
- Post flow:
  - multi-image picker
  - image resize/compress (preview + thumbnail)
  - upload to Storage
  - write `photos` and `hashtags`
  - update user upload counters

### Phase 3
- User tab:
  - profile edit
  - create/join/edit groups
  - sign out
  - subscription display (read-only)

### Phase 4
- Polish:
  - offline caching strategy
  - loading/error states
  - analytics/crash reporting
  - test coverage (unit + snapshot/UI)

## Key Differences to Handle Carefully
- RN local cache code (`getDocFromCache/getDocsFromCache`) has no 1:1 API style in Swift; decide offline policy with Firestore persistence + source options.
- Current group password is plain text in Firestore. Keep compatibility for now, but plan to move validation to Cloud Functions and hashed secrets.
- iOS image processing and memory usage need tighter control than RN.
- Google Sign-In callback URL + Firebase config must exactly match the iOS bundle identifier.

## Suggested Execution Order (fastest path)
1. Create native project + Firebase init.
2. Port SignIn and session handling.
3. Port Home read-only feed.
4. Port Post upload.
5. Port User/group management.

## Cutover Strategy
- Keep existing RN app runnable until native MVP is complete.
- Reuse same Firebase project initially.
- Release native app to TestFlight internal testers.
- After validation, archive RN mobile app path and keep web/PWA plan separate.
