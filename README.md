# CineNexa v2.1

CineNexa is a Flutter entertainment-discovery app rebuilt from the former JinnTV codebase. The active application is Firebase-first, uses TMDB for movie/TV metadata, and has no PHP backend or legacy JinnTV API dependency.

## Phase 2 — Premium UI

- Premium dark Material 3 theme and component styling
- Auto-rotating featured hero carousel mixing movies and TV series
- Modern reusable poster cards, ratings, badges and premium sections
- Home feed with Trending, Popular, In Theatres, Top Rated and TV rows
- Explore hub with Movies / TV Series tabs
- Unified Search for movies and TV series
- My Space replacing the basic My List screen
- Loading skeleton for the Home feed
- Cleaner navigation: Home / Search / Explore / My Space / More

## Phase 3 — TV Series

TMDB-powered TV support now includes:

- Trending TV
- Popular TV
- On The Air
- Airing Today
- Top Rated
- Discover / All Series
- TV search with pagination
- Series detail page
- Genres, status, networks and ratings
- Seasons
- Episode browser per season
- Cast
- Official YouTube trailer
- Similar/recommended TV shows
- Country-based watch-provider availability
- Save/remove TV shows in My Space

## Phase 4 — Personalization

CineNexa now learns locally from app usage and uses Firestore as a best-effort sync layer:

- Recently viewed movies and TV series
- Recent searches
- Per-user movie genre taste scores
- Per-user TV genre taste scores
- `Picked for you` movie row
- `Series for you` TV row
- `Continue exploring` Home row
- My Space viewing history
- Saving a title increases its related taste signals
- Viewing a detail page updates recommendations automatically

Personalization remains usable when Firestore is unavailable because the primary cache is user-specific SharedPreferences.

## Architecture

```text
Flutter
├─ Firebase Auth / FCM
├─ Firestore user sync
├─ Local-first library + personalization
└─ Catalog layer
   ├─ Movies
   └─ TV Series
        ↓
   TmdbClient
        ↓
Cloudflare Worker (production)
        ↓
      TMDB
```

## TMDB setup

### Recommended production setup

The included `cloudflare-worker/` keeps the TMDB read token outside the Flutter binary.

```bash
cd cloudflare-worker
npm install
npx wrangler login
npx wrangler secret put TMDB_ACCESS_TOKEN
npx wrangler deploy
```

Run/build Flutter with:

```bash
flutter run --dart-define=TMDB_PROXY_URL=https://cinenexa-catalog.<your-subdomain>.workers.dev
```

### Development-only direct mode

```bash
flutter run --dart-define=TMDB_ACCESS_TOKEN=YOUR_TMDB_READ_ACCESS_TOKEN
```

Do not ship a production TMDB token inside the Flutter binary.

## Firebase

The project deliberately keeps the existing Firebase project identifiers because the included Firebase service files are registered to them. Visible branding is CineNexa. Register new Android/iOS/Web Firebase apps before changing final store package IDs.

Enable:

1. Firebase Authentication providers you use.
2. Cloud Firestore.
3. Firebase Cloud Messaging.

`firestore.rules` already limits user-owned data to the authenticated user.

## Run

```bash
flutter clean
flutter pub get
flutter analyze
flutter run --dart-define=TMDB_ACCESS_TOKEN=YOUR_TOKEN
```

For production, use `TMDB_PROXY_URL` instead.

## Content / provider note

TMDB supplies metadata, artwork, trailers and watch-provider availability. Watch-provider data is powered by JustWatch and does not provide guaranteed direct full-stream URLs. CineNexa should only connect playback sources you own, license, or are legally allowed to distribute.
