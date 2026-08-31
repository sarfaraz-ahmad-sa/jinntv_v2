# CineNexa v2.2.1 Lib Repair

This repair patch restores the modern CineNexa `lib/` tree after the legacy JinnTV `main.dart` was accidentally restored.

It includes:
- modern CineNexa `main.dart`
- Firebase options and current auth flow
- Google sign-in runtime diagnostics/timeouts
- premium Movies/TV/Search/My Space code
- CineNexa in-app player
- `video_player` dependency
- current tests and Firestore rules

It intentionally DOES NOT include `macos/`, `ios/`, or `android/` platform folders, so your working Xcode Team/signing configuration is preserved.

## Apply
From `~/jinntv_v2`:

```bash
rm -rf lib
cp -R /path/to/CineNexa_v2.2.1_LibRepair_Patch/lib ./lib
cp /path/to/CineNexa_v2.2.1_LibRepair_Patch/pubspec.yaml ./pubspec.yaml
rm -rf test
cp -R /path/to/CineNexa_v2.2.1_LibRepair_Patch/test ./test
cp /path/to/CineNexa_v2.2.1_LibRepair_Patch/firestore.rules ./firestore.rules
flutter clean
flutter pub get
flutter analyze
flutter test
```

Then run with your NEW TMDB token:

```bash
flutter run -d macos --dart-define=TMDB_ACCESS_TOKEN=YOUR_NEW_TMDB_TOKEN
```
