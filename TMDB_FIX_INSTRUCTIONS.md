# CineNexa v2.2.2 — TMDB resilience fix

This patch keeps the current macOS signing and player setup unchanged.

## What it fixes

- Retries transient TMDB responses: 429, 500, 502, 503 and 504.
- Retries request timeouts.
- One failed TMDB home rail no longer blanks the entire Home feed.
- Home shows available movie/TV rails while a temporary TMDB endpoint is failing.
- The error screen is shown only when every catalog request fails.

## Copy into the existing project

From `~/jinntv_v2` after extracting the ZIP:

```bash
cp /path/to/CineNexa_v2.2.2_TMDBResilience_Patch/lib/core/network/tmdb_client.dart lib/core/network/tmdb_client.dart
cp /path/to/CineNexa_v2.2.2_TMDBResilience_Patch/lib/features/home/presentation/cine_home_screen.dart lib/features/home/presentation/cine_home_screen.dart

flutter clean
flutter pub get
flutter analyze
flutter test
```

Then run with a NEW TMDB read access token:

```bash
flutter run -d macos --dart-define=TMDB_ACCESS_TOKEN=YOUR_NEW_TOKEN
```

Do not paste access tokens into chat or source control.
