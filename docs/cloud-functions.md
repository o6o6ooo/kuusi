# Cloud Functions

Server-side helpers for destructive actions and notification fan-out.

## First-time setup

1. Install the Firebase CLI and log in.
2. From the repo root, run `cd functions && npm install`.
3. Build once with `npm run build`.
4. Deploy with `npm run deploy`.

For production App Store subscription verification, set `APP_STORE_APP_APPLE_ID` in the Functions runtime environment. `APP_STORE_BUNDLE_ID` defaults to `com.swallace.kuusi` and only needs setting if the bundle identifier changes.

For Resend transactional email delivery, store the API key in Secret Manager:

- `firebase functions:secrets:set RESEND_API_KEY`

## Current functions

Callable functions are deployed in `europe-west2`.

- `deleteGroup`
  - Verifies the caller is signed in and owns the group
  - Deletes group photo files from Storage
  - Deletes `photos` documents for the group
  - Removes the group from each member's `users/{uid}.groups`
  - Cleans `favourites` and decrements `usage_mb`
  - Deletes the `groups/{groupId}` document
- `deleteCurrentUserData`
  - Leaves every group the current user belongs to using the same server-side ownership-transfer path as `leaveGroup`
  - Deletes owned groups only when the current user is the final remaining member
  - Transfers owned groups to the next remaining member before removing the current user
  - Deletes the current user's remaining posted photos and related favourites/usage cleanup
  - Deletes the user's `devices` subcollection and Firestore document
  - Leaves Firebase Auth account deletion to the client so recent-login checks still apply
- `leaveGroup`
  - Verifies the caller is signed in and belongs to the group
  - Removes the caller from `groups/{groupId}.members`
  - Removes the `groupId` from the caller's `users/{uid}.groups`
  - Transfers ownership to the next remaining member when the caller owns the group
  - Deletes the group using the normal group cleanup path when the owner is the final member
- `deletePhoto`
  - Verifies the current user is the uploader
  - Deletes the photo's Storage files
  - Deletes the photo Firestore document
  - Cleans favourites and `usage_mb` with the same helper used by group/account deletion
- `commitPhotoUploadBatch`
  - Verifies the caller is signed in and still belongs to the target group
  - Validates the temporary Storage paths uploaded by the iOS app
  - Reads verified Premium entitlement cache from `users/{uid}.premium_expires_at` for quota checks
  - Copies temporary preview and thumbnail files to final photo Storage paths
  - Creates the `photos` documents and increments `users/{uid}.usage_mb` in a transaction
  - Deletes temporary files after a successful commit
  - Deletes copied final files and temporary files if the commit fails
- `syncSubscription`
  - Verifies the caller's StoreKit signed transaction with Apple's signed data verifier
  - Verifies StoreKit renewal info when the client provides it
  - Updates `users/{uid}` with server-owned Premium entitlement fields
  - Clears the server Premium cache when no active transaction is provided
  - Sends deduplicated Resend emails for Premium purchase, cancellation, and expiry transitions
- `sendPremiumExpiryEmails`
  - Runs daily at 09:00 Europe/London
  - Sends `premium_expiring` emails for cancelled Premium subscriptions ending within 7 days
  - Sends `premium_expired` emails for expired Premium subscriptions
  - Uses `email_logs` to prevent duplicate sends
  - Records `accepted` when Resend accepts an email; final delivery, bounce, or suppression status remains in Resend logs
- `removeGroupMember`
  - Verifies the caller owns the group
  - Removes the target user from `groups/{groupId}.members`
  - Removes the `groupId` from the target user's `users/{uid}.groups`
- `onPhotoCreated`
  - Triggers when `photos/{photoId}` is created in `europe-west2`
  - Uses the photo's `upload_batch_id` to reserve a `photo_notification_batches/{uploadBatchId}` document
  - Sends only one notification per upload batch, even when the batch creates multiple photo documents
  - Loads the target group and excludes the uploader from delivery
  - Reads active device tokens from `users/{uid}/devices/{deviceId}`
  - Sends a push notification announcing the new photo or photo batch
  - Deletes stale tokens when FCM reports them invalid
- `onAdminNotificationCreated`
  - Triggers when `admin_notifications/{notificationId}` is created in `europe-west2`
  - Supports `target = "all"` only
  - Sends maintenance or announcement pushes to the FCM topic `announcements`
  - Writes topic delivery metadata plus `status = sent` or `status = failed`
- `onLegalAnnouncementCreated`
  - Triggers when `legal_announcements/{announcementId}` is created in `europe-west2`
  - Sends the announcement body as a legal update email through Resend
  - Sends at most 100 users per announcement for the current free-plan sending limit
  - Uses `email_logs` with the announcement ID as the dedupe key

## Admin notification authoring

Create a Firestore document in `admin_notifications` with at least:

- `title`
- `body`
- `target`
  - `"all"` to notify every signed-in device subscribed to the announcements topic

Optional fields:

- `deep_link`
- `status`
  - Use `"draft"` to save without sending
  - Omit it, or use any non-draft value, to send immediately on create

If `target` is set to anything other than `"all"`, the function marks the document as failed with `failure_reason = "unsupported_target"`.

## Legal announcement email authoring

Create a Firestore document in `legal_announcements` with at least:

- `body`

Optional fields:

- `title`
  - Defaults to `"Important update to Kuusi terms"`
- `effective_at`
- `terms_url`
- `privacy_url`
- `status`
  - Use `"draft"` to save without sending
  - Omit it, or use any non-draft value, to send immediately on create

The first implementation sends up to 100 users per announcement to stay within the Resend free daily sending limit. Revisit this with a queued batch flow once the user base is larger.

## Follow-up

The iOS app now owns device token registration. Deploy the notification functions alongside the client changes so `users/{uid}/devices/{deviceId}` is populated before fan-out is expected to work.

When moving these notification triggers from `us-central1` to `europe-west2`, delete the old `us-central1` copies after the new deployment succeeds so the same Firestore event is not processed twice.

## One-off maintenance scripts

For one-time admin data fixes, prefer local scripts over new deployed functions.

- `npm run backfill:photo-storage-paths`
  - Run from `functions/`
  - Reads every `photos` document and derives:
    - `preview_storage_path` from `photo_url`
    - `thumbnail_storage_path` from `thumbnail_url`
  - Defaults to dry-run mode
  - Add `-- --apply` to write changes
  - Requires Firebase Admin credentials, for example:
    - `GOOGLE_APPLICATION_CREDENTIALS=/path/to/service-account.json npm run backfill:photo-storage-paths`

- `npm run cleanup:legacy-photo-urls`
  - Run from `functions/`
  - Reads every `photos` document and removes:
    - `photo_url`
    - `thumbnail_url`
  - Only updates documents that already have both:
    - `preview_storage_path`
    - `thumbnail_storage_path`
  - Defaults to dry-run mode
  - Add `-- --apply` to delete the legacy URL fields
  - Requires Firebase Admin credentials, for example:
    - `GOOGLE_APPLICATION_CREDENTIALS=/path/to/service-account.json npm run cleanup:legacy-photo-urls`

- `npm run cleanup:orphaned-data`
  - Run from `functions/`
  - This is a local maintenance script, not a deployed Cloud Function
  - Reads Firestore and Storage to find:
    - `photos` documents whose `group_id` no longer exists
    - Storage files no longer referenced by `photos` documents
    - `users.favourites` entries whose photo ID no longer exists
    - `users.groups` entries whose group ID no longer exists
    - expired or invalid `group_invites`
    - `photo_notification_batches` documents whose `created_at` is at least 7 days old
    - `admin_notifications` documents with `status = sent` or `status = failed` whose newest timestamp is at least 30 days old
  - Defaults to dry-run mode
  - Add `-- --apply` to delete orphaned data and remove stale references
  - Requires Firebase Admin credentials, for example:
    - `GOOGLE_APPLICATION_CREDENTIALS=/path/to/service-account.json npm run cleanup:orphaned-data`
  - Reads the default Storage bucket from `Kuusi/GoogleService-Info.plist`
  - To override it, set `FIREBASE_STORAGE_BUCKET` or pass `-- --bucket your-project.firebasestorage.app`
  - If the project cannot be detected automatically, set `GOOGLE_CLOUD_PROJECT` or pass `-- --project your-project`
