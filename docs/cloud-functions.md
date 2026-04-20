# Cloud Functions

Server-side helpers for destructive actions and notification fan-out.

## First-time setup

1. Install the Firebase CLI and log in.
2. From the repo root, run `cd functions && npm install`.
3. Build once with `npm run build`.
4. Deploy with `npm run deploy`.

## Current functions

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
  - Triggers when `photos/{photoId}` is created
  - Loads the target group and excludes the uploader from delivery
  - Reads active device tokens from `users/{uid}/devices/{deviceId}`
  - Sends a push notification announcing the new photo
  - Deletes stale tokens when FCM reports them invalid
- `onAdminNotificationCreated`
  - Triggers when `admin_notifications/{notificationId}` is created
  - Supports `target = "all"` and `target = "group"`
  - Sends maintenance or announcement pushes with optional deep-link metadata
  - Writes delivery counts plus `status = sent` or `status = failed`

## Admin notification authoring

Create a Firestore document in `admin_notifications` with at least:

- `title`
- `body`
- `target`
  - `"all"` to notify every active device
  - `"group"` to notify only the groups listed in `target_group_ids`

Optional fields:

- `target_group_ids`
- `deep_link`
- `status`
  - Use `"draft"` to save without sending
  - Omit it, or use any non-draft value, to send immediately on create

## Follow-up

The iOS app now owns device token registration. Deploy the notification functions alongside the client changes so `users/{uid}/devices/{deviceId}` is populated before fan-out is expected to work.
