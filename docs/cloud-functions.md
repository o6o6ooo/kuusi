# Cloud Functions

Minimal setup for server-side destructive operations such as `deleteGroup`.

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
  - Deletes the user's Firestore document
  - Leaves Firebase Auth account deletion to the client so recent-login checks still apply
- `deletePhoto`
  - Verifies the current user is the uploader
  - Deletes the photo's Storage files
  - Deletes the photo Firestore document
  - Cleans favourites and `usage_mb` with the same helper used by group/account deletion

## Follow-up

Once `deleteGroup` is deployed and working, `deleteAccount` can follow the same pattern so client-side rules can stay tight.
