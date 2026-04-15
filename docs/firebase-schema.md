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
