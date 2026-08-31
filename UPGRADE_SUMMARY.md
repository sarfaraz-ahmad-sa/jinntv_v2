# CineNexa v2.1 — Phase 2/3/4 Upgrade

## Phase 2: Premium UI

- New central CineTheme
- Premium Home hero carousel
- Movies + TV mixed discovery feed
- Home skeleton state
- New reusable premium media cards and section headers
- Explore hub with Movies / TV tabs
- Unified movie + TV Search
- New My Space experience
- Navigation updated to Home / Search / Explore / My Space / More

## Phase 3: TV Series

- New `features/tv` domain/data/presentation module
- Trending, Popular, On The Air, Airing Today, Top Rated, Discover
- TV pagination and search
- TV details, genres, networks, cast and trailers
- Seasons and lazy episode browsing
- TV recommendations
- TV watch providers + JustWatch attribution
- TV watchlist local cache + Firestore sync

## Phase 4: Personalization

- New PersonalizationService
- Per-user local viewing history
- Per-user recent searches
- Movie and TV genre preference scores
- Firestore best-effort history/preferences sync
- Picked-for-you movie discovery
- Personalized TV discovery
- Continue Exploring on Home
- Recent activity in My Space

## Cleanup

- Removed unused legacy JinnTV website JS, CSS, fonts, logos and banner assets
- Kept only the CineNexa launcher icon under `assets/`
- Cloudflare Worker renamed from movie-specific to catalog naming
- App version bumped to `2.1.0+21`

## Preserved identifiers

Existing Firebase project/package identifiers are intentionally preserved until matching new Firebase applications are registered. Changing those identifiers without replacing Firebase config files would break Auth/FCM/Firestore.

## v2.1.1 Analyzer hotfix
- Fixed compile-blocking `CupertinoPageTransitionsBuilder` theme errors.
- Replaced invalid `Colors.white44` references with 44% white.
- Migrated deprecated `withOpacity` calls to `withValues(alpha:)`.
- Cleaned analyzer style warnings from callback wildcards, interpolation, and redundant import.
- Version bumped to `2.1.1+22`.

