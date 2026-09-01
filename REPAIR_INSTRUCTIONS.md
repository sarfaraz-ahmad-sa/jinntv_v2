# CineNexa v2.2.3 Full Lib Repair

This is a complete source repair bundle for the CineNexa Dart layer.
It intentionally does NOT include macOS/Xcode folders, so your working signing/team setup remains untouched.

From project root (`~/jinntv_v2`):

```bash
mv lib lib_broken_backup_$(date +%Y%m%d_%H%M%S)
rm -rf test
cp -R /path/to/CineNexa_v2.2.3_FullLibRepair/lib ./lib
cp -R /path/to/CineNexa_v2.2.3_FullLibRepair/test ./test
cp /path/to/CineNexa_v2.2.3_FullLibRepair/pubspec.yaml ./pubspec.yaml
cp /path/to/CineNexa_v2.2.3_FullLibRepair/firestore.rules ./firestore.rules

flutter clean
flutter pub get
flutter analyze
flutter test
```

Then run with a fresh TMDB Read Access Token:

```bash
flutter run -d macos --dart-define=TMDB_ACCESS_TOKEN=YOUR_NEW_TMDB_TOKEN
```

Included:
- complete CineNexa lib tree
- premium UI / movies / TV / search / My Space
- Firebase auth runtime fixes
- own in-app MP4/HLS player
- Firestore media_sources lookup
- TMDB retry/resilience handling
- tests and Firestore rules

Do not overwrite `macos/`, because its signing configuration is already set on your machine.
