# CineNexa Catalog TMDB Worker

This replaces the removed PHP backend/API layer. It keeps the TMDB read token outside the Flutter app.

## Deploy

```bash
cd cloudflare-worker
npm install
npx wrangler login
npx wrangler secret put TMDB_ACCESS_TOKEN
npx wrangler deploy
```

Then run Flutter with the deployed Worker URL:

```bash
flutter run --dart-define=TMDB_PROXY_URL=https://cinenexa-catalog.<your-subdomain>.workers.dev
```

For local development only, CineNexa also supports:

```bash
flutter run --dart-define=TMDB_ACCESS_TOKEN=YOUR_TMDB_READ_ACCESS_TOKEN
```

Do not ship a production TMDB secret inside the Flutter binary.
