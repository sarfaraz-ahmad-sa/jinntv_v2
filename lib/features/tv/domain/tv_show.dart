class TvShow {
  final int id;
  final String name;
  final String originalName;
  final String overview;
  final String firstAirDate;
  final String year;
  final String posterUrl;
  final String backdropUrl;
  final double rating;
  final int voteCount;
  final double popularity;
  final List<int> genreIds;
  final List<String> originCountries;

  const TvShow({
    required this.id,
    required this.name,
    required this.originalName,
    required this.overview,
    required this.firstAirDate,
    required this.year,
    required this.posterUrl,
    required this.backdropUrl,
    required this.rating,
    required this.voteCount,
    required this.popularity,
    required this.genreIds,
    required this.originCountries,
  });

  static String imageUrl(dynamic path, {String size = 'w500'}) {
    final value = (path ?? '').toString().trim();
    if (value.isEmpty) return '';
    if (value.startsWith('http://') || value.startsWith('https://')) return value;
    return 'https://image.tmdb.org/t/p/$size$value';
  }

  factory TvShow.fromTmdb(Map<String, dynamic> json) {
    int toInt(dynamic value) => int.tryParse('$value') ?? 0;
    double toDouble(dynamic value) => double.tryParse('$value') ?? 0;
    String toText(dynamic value) => (value ?? '').toString();

    final firstAirDate = toText(json['first_air_date']);
    final rawGenreIds = json['genre_ids'] as List? ?? const [];
    final rawCountries = json['origin_country'] as List? ?? const [];

    return TvShow(
      id: toInt(json['id']),
      name: toText(json['name']).trim().isNotEmpty ? toText(json['name']) : toText(json['title']),
      originalName: toText(json['original_name']).trim().isNotEmpty
          ? toText(json['original_name'])
          : toText(json['original_title']),
      overview: toText(json['overview']),
      firstAirDate: firstAirDate,
      year: firstAirDate.length >= 4 ? firstAirDate.substring(0, 4) : '',
      posterUrl: imageUrl(json['poster_path']),
      backdropUrl: imageUrl(json['backdrop_path'], size: 'w1280'),
      rating: toDouble(json['vote_average']),
      voteCount: toInt(json['vote_count']),
      popularity: toDouble(json['popularity']),
      genreIds: rawGenreIds.map(toInt).where((id) => id > 0).toList(),
      originCountries: rawCountries.map((e) => '$e').where((e) => e.isNotEmpty).toList(),
    );
  }

  factory TvShow.fromStored(Map<String, dynamic> json) {
    int toInt(dynamic value) => int.tryParse('$value') ?? 0;
    double toDouble(dynamic value) => double.tryParse('$value') ?? 0;
    String toText(dynamic value) => (value ?? '').toString();
    final genres = json['genre_ids'] as List? ?? const [];
    final countries = json['origin_countries'] as List? ?? const [];
    return TvShow(
      id: toInt(json['id']),
      name: toText(json['name']),
      originalName: toText(json['original_name']),
      overview: toText(json['overview']),
      firstAirDate: toText(json['first_air_date']),
      year: toText(json['year']),
      posterUrl: toText(json['poster_url']),
      backdropUrl: toText(json['backdrop_url']),
      rating: toDouble(json['rating']),
      voteCount: toInt(json['vote_count']),
      popularity: toDouble(json['popularity']),
      genreIds: genres.map(toInt).where((id) => id > 0).toList(),
      originCountries: countries.map((e) => '$e').toList(),
    );
  }

  Map<String, dynamic> toStoredJson() => {
        'id': id,
        'name': name,
        'original_name': originalName,
        'overview': overview,
        'first_air_date': firstAirDate,
        'year': year,
        'poster_url': posterUrl,
        'backdrop_url': backdropUrl,
        'rating': rating,
        'vote_count': voteCount,
        'popularity': popularity,
        'genre_ids': genreIds,
        'origin_countries': originCountries,
      };
}

class TvPage {
  final int page;
  final int totalPages;
  final int totalResults;
  final List<TvShow> items;

  const TvPage({
    required this.page,
    required this.totalPages,
    required this.totalResults,
    required this.items,
  });

  factory TvPage.fromTmdb(Map<String, dynamic> json) {
    int toInt(dynamic value) => int.tryParse('$value') ?? 0;
    final raw = json['results'] as List? ?? const [];
    return TvPage(
      page: toInt(json['page']),
      totalPages: toInt(json['total_pages']),
      totalResults: toInt(json['total_results']),
      items: raw
          .whereType<Map>()
          .map((e) => TvShow.fromTmdb(e.cast<String, dynamic>()))
          .where((show) => show.id > 0)
          .toList(),
    );
  }
}

class TvGenre {
  final int id;
  final String name;
  const TvGenre({required this.id, required this.name});

  factory TvGenre.fromJson(Map<String, dynamic> json) => TvGenre(
        id: int.tryParse('${json['id']}') ?? 0,
        name: (json['name'] ?? '').toString(),
      );
}

class TvProvider {
  final int id;
  final String name;
  final String logoUrl;

  const TvProvider({required this.id, required this.name, required this.logoUrl});

  factory TvProvider.fromTmdb(Map<String, dynamic> json) => TvProvider(
        id: int.tryParse('${json['provider_id']}') ?? 0,
        name: (json['provider_name'] ?? '').toString(),
        logoUrl: TvShow.imageUrl(json['logo_path'], size: 'w92'),
      );
}

class TvCast {
  final int id;
  final String name;
  final String character;
  final String profileUrl;

  const TvCast({
    required this.id,
    required this.name,
    required this.character,
    required this.profileUrl,
  });

  factory TvCast.fromTmdb(Map<String, dynamic> json) => TvCast(
        id: int.tryParse('${json['id']}') ?? 0,
        name: (json['name'] ?? '').toString(),
        character: (json['character'] ?? '').toString(),
        profileUrl: TvShow.imageUrl(json['profile_path'], size: 'w185'),
      );
}

class TvSeasonSummary {
  final int id;
  final int seasonNumber;
  final int episodeCount;
  final String name;
  final String overview;
  final String airDate;
  final String posterUrl;

  const TvSeasonSummary({
    required this.id,
    required this.seasonNumber,
    required this.episodeCount,
    required this.name,
    required this.overview,
    required this.airDate,
    required this.posterUrl,
  });

  factory TvSeasonSummary.fromTmdb(Map<String, dynamic> json) => TvSeasonSummary(
        id: int.tryParse('${json['id']}') ?? 0,
        seasonNumber: int.tryParse('${json['season_number']}') ?? 0,
        episodeCount: int.tryParse('${json['episode_count']}') ?? 0,
        name: (json['name'] ?? '').toString(),
        overview: (json['overview'] ?? '').toString(),
        airDate: (json['air_date'] ?? '').toString(),
        posterUrl: TvShow.imageUrl(json['poster_path']),
      );
}

class TvEpisode {
  final int id;
  final int episodeNumber;
  final String name;
  final String overview;
  final String airDate;
  final int runtimeMinutes;
  final double rating;
  final String stillUrl;

  const TvEpisode({
    required this.id,
    required this.episodeNumber,
    required this.name,
    required this.overview,
    required this.airDate,
    required this.runtimeMinutes,
    required this.rating,
    required this.stillUrl,
  });

  factory TvEpisode.fromTmdb(Map<String, dynamic> json) => TvEpisode(
        id: int.tryParse('${json['id']}') ?? 0,
        episodeNumber: int.tryParse('${json['episode_number']}') ?? 0,
        name: (json['name'] ?? '').toString(),
        overview: (json['overview'] ?? '').toString(),
        airDate: (json['air_date'] ?? '').toString(),
        runtimeMinutes: int.tryParse('${json['runtime']}') ?? 0,
        rating: double.tryParse('${json['vote_average']}') ?? 0,
        stillUrl: TvShow.imageUrl(json['still_path'], size: 'w500'),
      );
}

class TvSeasonDetails {
  final int seasonNumber;
  final String name;
  final String overview;
  final String posterUrl;
  final List<TvEpisode> episodes;

  const TvSeasonDetails({
    required this.seasonNumber,
    required this.name,
    required this.overview,
    required this.posterUrl,
    required this.episodes,
  });

  factory TvSeasonDetails.fromTmdb(Map<String, dynamic> json) {
    final rawEpisodes = json['episodes'] as List? ?? const [];
    return TvSeasonDetails(
      seasonNumber: int.tryParse('${json['season_number']}') ?? 0,
      name: (json['name'] ?? '').toString(),
      overview: (json['overview'] ?? '').toString(),
      posterUrl: TvShow.imageUrl(json['poster_path']),
      episodes: rawEpisodes
          .whereType<Map>()
          .map((e) => TvEpisode.fromTmdb(e.cast<String, dynamic>()))
          .toList(),
    );
  }
}

class TvDetails {
  final TvShow show;
  final String tagline;
  final String status;
  final String type;
  final String homepage;
  final int numberOfSeasons;
  final int numberOfEpisodes;
  final List<int> episodeRunTimes;
  final List<TvGenre> genres;
  final List<String> networks;
  final String trailerYoutubeKey;
  final List<TvCast> cast;
  final List<TvSeasonSummary> seasons;
  final String providerRegion;
  final String providerTmdbUrl;
  final List<TvProvider> streamingProviders;
  final List<TvProvider> freeProviders;
  final List<TvProvider> adSupportedProviders;
  final List<TvProvider> rentProviders;
  final List<TvProvider> buyProviders;
  final List<TvShow> recommendations;

  const TvDetails({
    required this.show,
    required this.tagline,
    required this.status,
    required this.type,
    required this.homepage,
    required this.numberOfSeasons,
    required this.numberOfEpisodes,
    required this.episodeRunTimes,
    required this.genres,
    required this.networks,
    required this.trailerYoutubeKey,
    required this.cast,
    required this.seasons,
    required this.providerRegion,
    required this.providerTmdbUrl,
    required this.streamingProviders,
    required this.freeProviders,
    required this.adSupportedProviders,
    required this.rentProviders,
    required this.buyProviders,
    required this.recommendations,
  });

  factory TvDetails.fromTmdb(Map<String, dynamic> json, {required String region}) {
    List<T> parseList<T>(dynamic raw, T Function(Map<String, dynamic>) factory) =>
        (raw as List? ?? const [])
            .whereType<Map>()
            .map((e) => factory(e.cast<String, dynamic>()))
            .toList();

    final videos = ((json['videos'] as Map?)?['results'] as List? ?? const [])
        .whereType<Map>()
        .map((e) => e.cast<String, dynamic>())
        .toList();
    final youtubeVideos = videos.where((v) => (v['site'] ?? '') == 'YouTube').toList();
    Map<String, dynamic>? trailer;
    for (final video in youtubeVideos) {
      if ((video['type'] ?? '') == 'Trailer' && video['official'] == true) {
        trailer = video;
        break;
      }
    }
    if (trailer == null) {
      for (final video in youtubeVideos) {
        if ((video['type'] ?? '') == 'Trailer') {
          trailer = video;
          break;
        }
      }
    }
    if (trailer == null && youtubeVideos.isNotEmpty) trailer = youtubeVideos.first;

    final credits = (json['credits'] as Map?)?.cast<String, dynamic>() ?? const {};
    final providerRoot = (json['watch/providers'] as Map?)?.cast<String, dynamic>() ?? const {};
    final providerResults = (providerRoot['results'] as Map?)?.cast<String, dynamic>() ?? const {};
    final provider = (providerResults[region] as Map?)?.cast<String, dynamic>() ?? const {};
    final recommendations = (json['recommendations'] as Map?)?.cast<String, dynamic>() ?? const {};
    final networkRaw = json['networks'] as List? ?? const [];
    final runTimes = json['episode_run_time'] as List? ?? const [];

    final show = TvShow.fromTmdb({
      ...json,
      'genre_ids': (json['genres'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => e['id'])
          .toList(),
    });

    return TvDetails(
      show: show,
      tagline: (json['tagline'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      type: (json['type'] ?? '').toString(),
      homepage: (json['homepage'] ?? '').toString(),
      numberOfSeasons: int.tryParse('${json['number_of_seasons']}') ?? 0,
      numberOfEpisodes: int.tryParse('${json['number_of_episodes']}') ?? 0,
      episodeRunTimes: runTimes.map((e) => int.tryParse('$e') ?? 0).where((e) => e > 0).toList(),
      genres: parseList(json['genres'], TvGenre.fromJson),
      networks: networkRaw
          .whereType<Map>()
          .map((e) => (e['name'] ?? '').toString())
          .where((e) => e.isNotEmpty)
          .toList(),
      trailerYoutubeKey: (trailer?['key'] ?? '').toString(),
      cast: parseList(credits['cast'], TvCast.fromTmdb).take(18).toList(),
      seasons: parseList(json['seasons'], TvSeasonSummary.fromTmdb)
          .where((s) => s.seasonNumber > 0)
          .toList(),
      providerRegion: region,
      providerTmdbUrl: (provider['link'] ?? '').toString(),
      streamingProviders: parseList(provider['flatrate'], TvProvider.fromTmdb),
      freeProviders: parseList(provider['free'], TvProvider.fromTmdb),
      adSupportedProviders: parseList(provider['ads'], TvProvider.fromTmdb),
      rentProviders: parseList(provider['rent'], TvProvider.fromTmdb),
      buyProviders: parseList(provider['buy'], TvProvider.fromTmdb),
      recommendations: parseList(recommendations['results'], TvShow.fromTmdb).take(20).toList(),
    );
  }
}
