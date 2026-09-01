class AppConfig {
  static const appName = 'CineNexa';
  static const appTagline = 'Movies. Stories. Your next watch.';

  /// Recommended production setup: point this to the included Cloudflare Worker.
  /// Example: --dart-define=TMDB_PROXY_URL=https://cinenexa-movies.example.workers.dev
  static const tmdbProxyUrl = String.fromEnvironment('TMDB_PROXY_URL');

  /// Development fallback. Do not ship a production secret inside the app.
  /// Example: --dart-define=TMDB_ACCESS_TOKEN=eyJhbGciOiJIUzI1NiJ9...
  static const tmdbAccessToken = String.fromEnvironment('TMDB_ACCESS_TOKEN');

  static bool get usesTmdbProxy => tmdbProxyUrl.trim().isNotEmpty;
  static bool get hasMovieApi => usesTmdbProxy || tmdbAccessToken.trim().isNotEmpty;
}
