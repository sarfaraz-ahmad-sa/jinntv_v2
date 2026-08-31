# CineNexa Auth / Backend Status

## Current backend
- Authentication: Firebase Authentication
- User data / My Space / personalization sync: Cloud Firestore
- Push notifications: Firebase Cloud Messaging
- Movie + TV catalog: TMDB (direct token in development or Cloudflare Worker proxy)
- PHP backend: none

## Important configuration mismatch found
The existing project currently uses different Firebase projects by platform:
- Android + iOS: `nexplay-ef73c`
- macOS + Web + Windows: `jinntv-4386a`

That means a user created on Android/iOS is not automatically a user on macOS/Web. For production, choose one Firebase project and run `flutterfire configure` for every platform against that same project.

## macOS Google Sign-In patch in 2.1.2
- Added `GIDClientID` to macOS Info.plist
- Added Google reversed client URL scheme to macOS Info.plist
- Added Google Sign-In keychain access group to both macOS entitlements files
- Improved login errors to show Firebase / PlatformException codes
- Prints the active Firebase project ID in debug mode

Google and Email/Password providers must also be enabled in Firebase Console > Authentication > Sign-in method for the active Firebase project.
