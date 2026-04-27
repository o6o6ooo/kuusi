# Cloud Functions

Server-side helpers for destructive actions and notification fan-out.

## First-time setup

1. Install the Firebase CLI and log in.
2. From the repo root, run `cd functions && npm install`.
3. Build once with `npm run build`.
4. Deploy with `npm run deploy`.

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
  - Deletes groups owned by the current user using the same server-side cleanup path
  - Removes the current user from groups they joined
  - Deletes the current user's remaining posted photos and related favourites/usage cleanup
  - Deletes the user's `devices` subcollection and Firestore document
  - Leaves Firebase Auth account deletion to the client so recent-login checks still apply
- `deletePhoto`
  - Verifies the current user is the uploader
  - Deletes the photo's Storage files
  - Deletes the photo Firestore document
  - Cleans favourites and `usage_mb` with the same helper used by group/account deletion
- `removeGroupMember`
  - Verifies the caller owns the group
  - Removes the target user from `groups/{groupId}.members`
  - Removes the `groupId` from the target user's `users/{uid}.groups`
- `onPhotoCreated`
  - Triggers when `photos/{photoId}` is created in `europe-west2`
  - Loads the target group and excludes the uploader from delivery
  - Reads active device tokens from `users/{uid}/devices/{deviceId}`
  - Sends a push notification announcing the new photo
  - Deletes stale tokens when FCM reports them invalid
- `onAdminNotificationCreated`
  - Triggers when `admin_notifications/{notificationId}` is created in `europe-west2`
  - Supports `target = "all"` only
  - Sends maintenance or announcement pushes to the FCM topic `announcements`
  - Writes topic delivery metadata plus `status = sent` or `status = failed`

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
