# Kuusi

Kuusi is a private family photo-sharing iOS app built with SwiftUI and Firebase.

## Status

This project is actively in development.

- Implemented: authentication flow, profile/settings, groups management, QR join/share, upload overlay UI
- In progress: core upload pipeline and production feed behavior

## Tech Stack

- iOS: SwiftUI (Xcode project)
- Backend: Firebase
- Auth: Sign in with Apple (plus Debug-only Email/Password sign-in)
- Database: Cloud Firestore
- Storage: Firebase Storage

## Project Structure

```text
kuusi/
├── Kuusi/                        # Xcode project root
│   ├── Kuusi.xcodeproj
│   └── Kuusi/
│       ├── App/
│       ├── Core/
│       ├── Features/
│       │   ├── Auth/
│       │   ├── Feed/
│       │   ├── Calendar/
│       │   ├── Favorites/
│       │   └── Settings/
│       └── Assets.xcassets/
├── docs/
│   └── swift-migration-plan.md
└── README.md
```

## Getting Started

### 1. Open project

Open:

- `Kuusi/Kuusi.xcodeproj`

### 2. Firebase config

- Place `GoogleService-Info.plist` under the app target (`Kuusi` group in Xcode)
- Ensure Firebase iOS app bundle identifier matches the Xcode target bundle identifier

### 3. Run

- Select iPhone/iPad simulator or real device
- Build and run from Xcode

## Debug Sign-In (DEBUG builds only)

`LoginView` supports Debug sign-in with environment variables from Xcode Scheme.

Use either:

- Single account
  - `DEBUG_TEST_EMAIL`
  - `DEBUG_TEST_PASSWORD`
  - `DEBUG_TEST_NAME` (optional)

- Multiple accounts
  - `DEBUG_TEST_USER_1_EMAIL`, `DEBUG_TEST_USER_1_PASSWORD`, `DEBUG_TEST_USER_1_NAME` (optional)
  - `DEBUG_TEST_USER_2_EMAIL`, `DEBUG_TEST_USER_2_PASSWORD`, `DEBUG_TEST_USER_2_NAME` (optional)
  - ...

Configure in:

- Xcode > Product > Scheme > Edit Scheme > Run > Environment Variables

## Security Notes

- `GoogleService-Info.plist` is ignored and should not be committed
- Keep test credentials only in local scheme environment variables
- Restrict Firebase rules and monitor usage/alerts in Firebase/GCP

## Roadmap (Short-Term)

- Finalize upload implementation (thumbnails/preview generation + metadata write)
- Finalize feed loading/pagination behavior
- Continue UI cleanup and component/view-model separation

## Author

Sakura Wallace

