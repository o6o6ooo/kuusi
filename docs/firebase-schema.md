# Firebase Schema

Current Firebase usage in the SwiftUI app.

## Firestore

### `users/{uid}`
- `name: string`
- `icon: string`
- `bgColour: string`
- `usage_mb: number`
- `groups: string[]`
- `favourites: string[]`
- `created_at: timestamp`
- `premium_expires_at: timestamp` (verified server-side Premium cache)
- `premium_product_id: string`
- `premium_original_transaction_id: string`
- `premium_transaction_id: string`
- `premium_environment: string`
- `premium_will_auto_renew: boolean`
- `premium_last_verified_at: timestamp`

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
- `date: timestamp` (editable photo date used for feed ordering)
- `hashtags: string[]`
- `caption: string` (optional, max 140 characters)
- `aspect_ratio: number`
- `size_mb: number`
- `upload_batch_id: string`
- `upload_batch_count: number`
- `created_at: timestamp` (server upload timestamp used for preview access)

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

### `email_logs/{logId}`
- `user_id: string`
- `email: string`
- `type: "premium_purchased" | "premium_cancelled" | "premium_expiring" | "premium_expired" | "legal_updated"`
- `dedupe_key: string`
- `status: "pending" | "accepted" | "failed" | "skipped"`
- `provider: "resend"`
- `provider_message_id: string`
- `failure_reason: string`
- `created_at: timestamp`
- `accepted_at: timestamp`
- `updated_at: timestamp`

### `legal_announcements/{announcementId}`
- `title: string`
- `body: string`
- `effective_at: timestamp`
- `terms_url: string`
- `privacy_url: string`
- `status: "draft" | "sent" | "failed"`
- `failure_reason: string`
- `sent_count: number`
- `sent_at: timestamp`
- `updated_at: timestamp`

## Storage

### Uploaded photo assets
- `photos/{userID}/{photoID}_preview.jpg`
- `photos/{userID}/{photoID}_thumb.jpg`

### Temporary upload assets
- `photos/{userID}/upload_{uploadBatchId}_{photoID}_preview.jpg`
- `photos/{userID}/upload_{uploadBatchId}_{photoID}_thumb.jpg`
- The iOS app writes these first, then `commitPhotoUploadBatch` copies them to final photo paths and deletes the temporary files after the Firestore commit.

## Required Firestore indexes

### `photos`
- Composite index for feed pagination by group:
  - `group_id` ascending
  - `date` descending

This is required for queries that filter photos by `group_id` and order the feed by newest editable photo `date`.

## Notification flow

- iOS devices store their current FCM token under `users/{uid}/devices/{deviceId}`
- iOS devices subscribe to the FCM topic `announcements` after notification permission is granted
- the iOS app uploads temporary Storage files, then calls `commitPhotoUploadBatch` to create `photos/{photoId}` documents and increment `users/{uid}.usage_mb`
- Premium users sync their current StoreKit transaction through `syncSubscription` before upload so server-side quota checks use verified `users/{uid}.premium_expires_at`
- Premium subscription sync also stores the verified auto-renew status and sends Resend emails for purchase, cancellation, and expiry events
- `sendPremiumExpiryEmails` runs daily and sends expiring/expired Premium emails with `email_logs` deduplication
- `legal_announcements/{announcementId}` creation triggers a legal update email batch
- each committed upload operation stamps every created `photos/{photoId}` document with the same `upload_batch_id`
- clients cannot create or delete `photos` documents directly; upload and delete cleanup runs through Cloud Functions
- `photos/{photoId}` creation triggers a Cloud Function that reserves `photo_notification_batches/{uploadBatchId}` and sends at most one push notification for that upload batch
- `admin_notifications/{notificationId}` creation triggers a Cloud Function that sends maintenance or announcement pushes to the `announcements` topic
- Invalid or expired device tokens are deleted server-side during notification delivery cleanup
