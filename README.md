# Kuusi

Kuusi is a private family photo-sharing iOS app built with SwiftUI and Firebase.
It is designed for small trusted groups who want a calmer, invite-only space for sharing photos.

## Overview

Kuusi focuses on private sharing rather than public social posting.
Users sign in with Apple, join family groups, upload photos, import from Google Photos, and browse shared memories inside a simple iOS-native experience.

## Features

- Sign in with Apple for primary authentication
- Biometric app locking after sign-in
- Invite-only groups with QR-based join and share flows
- Group tools for viewing members, leaving groups, owner transfer, removing members, and deleting groups
- Personal profile with emoji icon and background color
- Photo upload flow for private group sharing, including date and hashtag metadata
- Feed browsing with grouped access, favourites, photo editing, and photo deletion
- Optional Google account linking and Google Photos Picker import
- Push notifications for new photo batches and app announcements
- Free and Premium plan handling with StoreKit subscriptions and server-side entitlement verification
- Transactional email for Premium and legal account updates
- Native feed advertising for free users
- iPhone and iPad support through SwiftUI

## Authentication And Data

- Primary sign-in: Sign in with Apple
- Optional linked account: Google Sign-In, used only for Google Photos import
- Backend services:
  - Cloud Firestore for app data
  - Firebase Storage for uploaded photos
  - Firebase Cloud Functions for upload commits, destructive cleanup, subscription verification, notification fan-out, and transactional email
  - Firebase Cloud Messaging for device and announcement notifications
  - Firebase App Check for Firebase request protection
- User profile data includes display name, emoji icon, background color, group membership, usage metadata, and server-owned Premium entitlement fields
- User email addresses are not stored in Firestore user profile documents

## Plans And Limits

Kuusi has Free and Premium plans.

- Free:
  - 1 GB storage quota
  - Up to 3 groups
  - Older photo previews become thumbnail-only after 2 years
  - Feed ads are shown
- Premium:
  - 30 GB storage quota
  - Up to 10 groups
  - Full photo previews remain available
  - Feed ads are hidden

Premium is configured as an annual StoreKit product:

- `com.swallace.kuusi.premium.annual`

The iOS app syncs StoreKit signed transaction and renewal data to Cloud Functions. Functions verify Premium entitlement state server-side and use that cache for upload quota checks.

## Privacy Notes

Kuusi handles personal photos and account data, so privacy-related documentation should stay easy to find.

- Explain clearly what user data is stored and why
- Keep your App Store privacy details aligned with actual app behavior
- Keep Privacy Policy and Terms of Use links aligned with `kuusi.app`
- Treat Google account linking as optional and separate from primary app authentication
- Treat transactional subscription and legal emails as account/service emails, not marketing emails

## Status

This project is actively maintained.

Current implemented areas include:

- Authentication flow
- Biometric unlock flow
- Profile and settings
- Group management
- QR join/share flows
- Photo upload and Google Photos import UI
- Feed browsing, filtering, editing, favourites, and deletion
- Subscription and storage usage UI
- Native ad placement
- Push notification registration and handling
- Optional Google account linking for Google Photos import
- Cloud Functions for account, group, photo, subscription, notification, and email operations

## Tech Stack

- iOS app: SwiftUI
- Language: Swift
- Backend: Firebase
- Auth: Sign in with Apple
- Local unlock: LocalAuthentication
- Optional account linking: Google Sign-In
- Database: Cloud Firestore
- File storage: Firebase Storage
- Server-side functions: Firebase Cloud Functions for Node.js and TypeScript
- Push notifications: Firebase Cloud Messaging
- Subscriptions: StoreKit
- Ads: Google Mobile Ads
- Google photo import: Google Photos Picker API
- Transactional email: Resend

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
│   ├── cloud-functions.md
│   └── firebase-schema.md
├── functions/
│   ├── scripts/
│   └── src/
└── README.md
```

## Requirements

- macOS with a current version of Xcode
- iOS simulator or physical iPhone/iPad for testing
- Firebase project configured for the app
- Google Cloud project configuration if using Google Photos import
- Apple Developer account capabilities for Sign in with Apple, Push Notifications, and In-App Purchase
- AdMob app and native ad unit configuration for release ads
- Firebase CLI and Node.js if deploying Cloud Functions
- Resend account and API key if sending transactional email

## Getting Started

### 1. Open the project

Open `Kuusi/Kuusi.xcodeproj` in Xcode.

### 2. Add Firebase configuration

- Place `GoogleService-Info.plist` in the `Kuusi` app target
- Make sure the Firebase iOS app bundle identifier matches the Xcode target bundle identifier
- Set `GOOGLE_REVERSED_CLIENT_ID` in the `Kuusi` target build settings to the `REVERSED_CLIENT_ID` value from `GoogleService-Info.plist`
- Enable Firebase App Check for the app before relying on production enforcement

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

### 5. Configure subscriptions and ads

- Create the annual Premium StoreKit product with product ID `com.swallace.kuusi.premium.annual`
- Keep the app's StoreKit configuration and App Store Connect product metadata aligned
- Set `APP_STORE_APP_APPLE_ID` for production subscription verification in the Functions runtime environment
- Confirm the AdMob app ID and production native ad unit ID in `AppAdConfiguration`
- Debug builds use Google's native ad test unit

### 6. Configure transactional email

- Store the Resend API key in Firebase Secret Manager as `RESEND_API_KEY`
- Keep the sender domain and support inbox aligned with `hi@kuusi.app`
- Premium purchase, cancellation, expiry warning, expiry, and legal update emails are sent from Functions

### 7. Deploy Firebase backend changes when needed

Cloud Functions live in `functions/` and are documented in `docs/cloud-functions.md`.

- Callable functions handle upload commits, group deletion, group leaving, photo deletion, member removal, current-user data deletion, and Premium subscription sync
- Firestore triggers send photo-batch notifications, admin announcement notifications, and legal update emails
- Scheduled functions send Premium expiry emails
- Firestore rules live in `firestore.rules`
- Storage rules live in `storage.rules`
- Functions are deployed in `europe-west2`

### 8. Run the app

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
- Camera, photo library, notification, and biometric usage descriptions
- Privacy Policy and support URL
- Google OAuth production approval, if Google Photos import is included in release builds
- StoreKit product metadata and subscription review details
- AdMob production ad unit configuration
- Firebase App Check, Firestore rules, Storage rules, Cloud Functions deployment region, and old-region trigger cleanup
- App Store server verification environment variables and Resend Secret Manager configuration
- Transactional email copy for subscription and legal update messages
- dSYM upload warnings for third-party frameworks, if App Store Connect reports missing symbols

## Security Notes

- `GoogleService-Info.plist` should not be committed
- `.env` files, service account files, Firebase credentials, Resend keys, and local secret folders should not be committed
- Keep test credentials only in local Xcode scheme environment variables
- Restrict Firebase rules and monitor usage, quota, and alerts in Firebase and GCP
- Keep server-owned fields such as `usage_mb` and Premium entitlement data writable only from trusted backend code

## Support

- Support email: `hi@kuusi.app`
- Website: `https://kuusi.app`

## Author

Sakura Wallace
