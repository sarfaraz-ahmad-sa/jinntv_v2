# CineNexa 2.1.3 Auth Runtime Fix

- Firebase Authentication is the login backend.
- Google Sign-In no longer waits on Firestore profile sync before opening the app.
- Firestore profile sync runs in the background with a 5-second cap.
- Email login has a 20-second timeout.
- Google account picker has a 30-second timeout; token exchange and Firebase credential exchange each have a 20-second timeout.
- Debug logs show the active Firebase project and every Google auth stage.

## macOS current bundled Firebase configuration
The bundled macOS config is still `jinntv-4386a` / bundle `com.cartzlinkv2.jinntv`. Do not change the macOS Xcode bundle identifier without downloading/regenerating the matching Firebase macOS configuration.

For one unified backend, register the macOS app in the desired Firebase project and rerun FlutterFire CLI.
