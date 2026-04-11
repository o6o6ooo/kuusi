# Kuusi

Kuusi is a private family photo-sharing iOS app built with SwiftUI and Firebase.
It is designed for small trusted groups who want a calmer, invite-only space for sharing photos.

## Overview

Kuusi focuses on private sharing rather than public social posting.
Users sign in with Apple, join family groups, upload photos, and browse shared memories inside a simple iOS-native experience.

## Features

- Sign in with Apple for primary authentication
- Invite-only groups with QR-based join and share flows
- Personal profile with emoji icon and background color
- Photo upload flow for private group sharing
- Feed browsing for shared photos
- Optional Google account linking for Google Photos import
- iPhone and iPad support through SwiftUI

## Authentication And Data

- Primary sign-in: Sign in with Apple
- Optional linked account: Google Sign-In, used only for Google Photos import
- Backend services:
  - Cloud Firestore for app data
  - Firebase Storage for uploaded photos
- User profile data includes display name, emoji icon, background color, group membership, and usage metadata

## Privacy Notes

Kuusi handles personal photos and account data, so privacy-related documentation should stay easy to find.

- Explain clearly what user data is stored and why
- Keep your App Store privacy details aligned with actual app behavior
- Link your Privacy Policy and Terms of Use here once they are public
- Treat Google account linking as optional and separate from primary app authentication

## Status

This project is actively maintained.

Current implemented areas include:

- Authentication flow
- Profile and settings
- Group management
- QR join/share flows
- Photo upload UI
- Optional Google account linking for Google Photos import

## Tech Stack

- iOS app: SwiftUI
- Language: Swift
- Backend: Firebase
- Auth: Sign in with Apple
- Optional account linking: Google Sign-In
- Database: Cloud Firestore
- File storage: Firebase Storage

## Project Structure

```text
kuusi/
├── Kuusi/
│   ├── Kuusi.xcodeproj
│   ├── Kuusi/
│   │   ├── App/
│   │   ├── Assets.xcassets/
│   │   ├── Core/
│   │   └── Features/
│   │       ├── Auth/
│   │       ├── Feed/
│   │       ├── Settings/
│   │       └── Shared/
│   ├── KuusiTests/
│   └── KuusiUITests/
├── docs/
│   └── swift-migration-plan.md
└── README.md
```

## Requirements

- macOS with a current version of Xcode
- iOS simulator or physical iPhone/iPad for testing
- Firebase project configured for the app
- Google Cloud project configuration if using Google Photos import

## Getting Started

### 1. Open the project

Open `Kuusi/Kuusi.xcodeproj` in Xcode.

### 2. Add Firebase configuration

- Place `GoogleService-Info.plist` in the `Kuusi` app target
- Make sure the Firebase iOS app bundle identifier matches the Xcode target bundle identifier
- Set `GOOGLE_REVERSED_CLIENT_ID` in the `Kuusi` target build settings to the `REVERSED_CLIENT_ID` value from `GoogleService-Info.plist`

### 3. Configure Google Photos import

- Enable the Google Photos Picker API in your Google Cloud project
- Add the iOS OAuth configuration required by Google Sign-In
- Keep Sign in with Apple as the app's primary login
- Use Google only as a linked account for photo import

### 4. Review Google OAuth rollout state

- Google Photos import is currently configured for OAuth Testing mode
- Test users may see an unverified app warning during testing
- For local or internal testing, add tester accounts as test users in Google Cloud
- Before broader release, review the OAuth consent screen, complete any required Google verification, and switch the OAuth app to Production

### 5. Run the app

- Select an iPhone or iPad simulator, or a real device
- Build and run from Xcode

## Debug Sign-In

Debug sign-in is available in `DEBUG` builds only.

`LoginView` supports local debug sign-in with Xcode scheme environment variables.

Use either:

- Single account:
  - `DEBUG_TEST_EMAIL`
  - `DEBUG_TEST_PASSWORD`
  - `DEBUG_TEST_NAME` (optional)
- Multiple accounts:
  - `DEBUG_TEST_USER_1_EMAIL`, `DEBUG_TEST_USER_1_PASSWORD`, `DEBUG_TEST_USER_1_NAME` (optional)
  - `DEBUG_TEST_USER_2_EMAIL`, `DEBUG_TEST_USER_2_PASSWORD`, `DEBUG_TEST_USER_2_NAME` (optional)

Configure them in Xcode:

- Product > Scheme > Edit Scheme > Run > Environment Variables

## Release Checklist Notes

For an App Store release, keep these aligned with the shipped app:

- App Store screenshots and feature description
- Privacy Nutrition Label answers
- Sign in with Apple behavior
- Camera or photo library usage descriptions, if applicable
- Privacy Policy and support URL
- Google OAuth production approval, if Google Photos import is included in release builds

## Security Notes

- `GoogleService-Info.plist` should not be committed
- Keep test credentials only in local Xcode scheme environment variables
- Restrict Firebase rules and monitor usage, quota, and alerts in Firebase and GCP

## Support

If you publish Kuusi publicly, add at least one support contact here:

- Support email
- Website
- GitHub Issues, if appropriate for your release workflow

## Author

Sakura Wallace
