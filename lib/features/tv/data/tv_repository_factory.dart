import 'dart:ui';

import '../../../core/network/tmdb_client.dart';
import 'tv_repository.dart';

class TvRepositoryFactory {
  static TvRepository create({Locale? locale}) {
    final current = locale ?? PlatformDispatcher.instance.locale;
    final region = (current.countryCode ?? 'PK').toUpperCase();
    final languageCode = current.languageCode.isEmpty ? 'en' : current.languageCode;
    return TvRepository(
      TmdbClient(),
      region: region,
      language: '$languageCode-$region',
    );
  }
}
