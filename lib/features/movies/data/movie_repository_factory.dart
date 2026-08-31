import 'dart:ui';

import '../../../core/network/tmdb_client.dart';
import 'movie_repository.dart';

class MovieRepositoryFactory {
  static MovieRepository create({Locale? locale}) {
    final current = locale ?? PlatformDispatcher.instance.locale;
    final region = (current.countryCode ?? 'PK').toUpperCase();
    return MovieRepository(
      TmdbClient(),
      region: region,
      language: current.languageCode.isEmpty ? 'en-US' : '${current.languageCode}-$region',
    );
  }
}
