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
- `preview_storage_path: string`
- `thumbnail_storage_path: string`
- `group_id: string`
- `posted_by: string`
- `year: number`
- `hashtags: string[]`
- `aspect_ratio: number`
- `size_mb: number`
- `upload_batch_id: string`
- `upload_batch_count: number`
- `created_at: timestamp`

### `photo_notification_batches/{uploadBatchId}`
- `created_at: timestamp`
- `first_photo_id: string`
- `group_id: string`
- `posted_by: string`
- `photo_count: number`

### `admin_notifications/{notificationId}`
- `title: string`
- `body: string`
- `target: "all"`
- `deep_link: string`
- `status: "draft" | "sent" | "failed"`
- `failure_reason: string`
- `sent_at: timestamp`
- `updated_at: timestamp`
- `delivery.mode: "topic"`
- `delivery.topic: "announcements"`
- `delivery.message_id: string`

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
- iOS devices subscribe to the FCM topic `announcements` after notification permission is granted
- each upload operation stamps every created `photos/{photoId}` document with the same `upload_batch_id`
- `photos/{photoId}` creation triggers a Cloud Function that reserves `photo_notification_batches/{uploadBatchId}` and sends at most one push notification for that upload batch
- `admin_notifications/{notificationId}` creation triggers a Cloud Function that sends maintenance or announcement pushes to the `announcements` topic
- Invalid or expired device tokens are deleted server-side during notification delivery cleanup
