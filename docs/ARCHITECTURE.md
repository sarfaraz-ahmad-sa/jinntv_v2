# CineNexa v2.1 Architecture

```text
lib/
├─ core/
│  ├─ config/           runtime configuration
│  ├─ network/          TMDB HTTP client
│  ├─ services/         library + personalization
│  ├─ theme/            CineNexa premium theme
│  └─ widgets/          reusable premium media UI
├─ features/
│  ├─ auth/             Firebase authentication
│  ├─ home/             personalized premium feed
│  ├─ search/           movie + TV search, recent searches
│  ├─ explore/          Movies / TV hub
│  ├─ movies/           movie data/domain/presentation
│  ├─ tv/               TV, seasons and episodes
│  ├─ library/          My Space
│  └─ more/             account/settings/about
└─ Screens/
   ├─ app_shell.dart
   ├─ onboarding_screen.dart
   └─ widgets/app_bottom_nav.dart
```

## Catalog request path

```text
Flutter repository
   -> TmdbClient
   -> Cloudflare Worker
   -> TMDB API v3
```

Development can directly call TMDB with `TMDB_ACCESS_TOKEN`, but production should use `TMDB_PROXY_URL`.

## User data

```text
Firebase Auth
  └─ users/{uid}
      ├─ watchlist/{movieId}
      ├─ watchlist_tv/{seriesId}
      └─ history/{mediaType_mediaId}

Local cache (per Firebase UID)
  ├─ saved movies
  ├─ saved TV series
  ├─ recently viewed
  ├─ recent searches
  └─ movie/TV genre taste scores
```

The local layer is deliberately primary for resilience. Firestore failures do not make My Space or personalization unusable.

## Personalization model

CineNexa uses a small transparent preference model rather than a black-box recommender:

1. Opening a movie/TV detail records a recent-view event.
2. Genres on viewed titles increase that media type's genre scores.
3. Saving a title gives its genres a stronger preference weight.
4. Highest-scoring movie genres feed TMDB Discover Movie.
5. Highest-scoring TV genres feed TMDB Discover TV.
6. Home refreshes `Picked for you` / `Series for you` as signals change.

This model is inexpensive, explainable and can later be replaced by a backend recommender without changing presentation screens.

## Security decisions

- No PHP backend.
- No active legacy JinnTV network endpoints.
- Production TMDB token belongs in a Cloudflare Worker secret.
- Firebase rules scope user data to `request.auth.uid`.
- Existing Firebase IDs remain until replacement Firebase apps are registered.
- Full copyrighted streaming sources are outside TMDB and must be licensed/authorized separately.
