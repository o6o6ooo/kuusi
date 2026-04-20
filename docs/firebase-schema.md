# Firebase Schema

Current Firebase usage in the SwiftUI app.

## Firestore

### `users/{uid}`
- `name: string`
- `email: string`
- `icon: string`
- `bgColour: string`
- `usage_mb: number`
- `groups: string[]`
- `favourites: string[]`
- `created_at: timestamp`

### `users/{uid}/devices/{deviceId}`
- `fcm_token: string`
- `platform: "ios"`
- `device_name: string`
- `app_version: string`
- `notifications_enabled: boolean`
- `last_seen_at: timestamp`
- `updated_at: timestamp`

### `groups/{groupId}`
- `id: string`
- `name: string`
- `owner_uid: string`
- `members: string[]`
- `created_at: timestamp`

### `photos/{photoId}`
- `photo_url: string`
- `thumbnail_url: string`
- `group_id: string`
- `posted_by: string`
- `year: number`
- `hashtags: string[]`
- `aspect_ratio: number`
- `size_mb: number`
- `created_at: timestamp`

### `admin_notifications/{notificationId}`
- `title: string`
- `body: string`
- `target: "all" | "group"`
- `target_group_ids: string[]`
- `deep_link: string`
- `status: "draft" | "sent" | "failed"`
- `sent_at: timestamp`
- `updated_at: timestamp`
- `delivery.sent_count: number`
- `delivery.failed_count: number`
- `delivery.token_count: number`

## Storage

### Uploaded photo assets
- `photos/{userID}/{photoID}_preview.jpg`
- `photos/{userID}/{photoID}_thumb.jpg`

## Required Firestore indexes

### `photos`
- Composite index for feed pagination by group:
  - `group_id` ascending
  - `created_at` descending

This is required for queries that filter photos by `group_id` and order the feed by newest `created_at`.

## Notification flow

- iOS devices store their current FCM token under `users/{uid}/devices/{deviceId}`
- `photos/{photoId}` creation triggers a Cloud Function that fans out push notifications to the other group members
- `admin_notifications/{notificationId}` creation triggers a Cloud Function that sends maintenance or announcement pushes
- Invalid or expired device tokens are deleted server-side during notification delivery cleanup
