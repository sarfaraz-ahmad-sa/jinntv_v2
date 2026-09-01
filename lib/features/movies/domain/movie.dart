class Movie {
  final int id;
  final String title;
  final String originalTitle;
  final String overview;
  final String releaseDate;
  final String year;
  final String posterUrl;
  final String backdropUrl;
  final double rating;
  final int voteCount;
  final double popularity;
  final List<int> genreIds;

  const Movie({
    required this.id,
    required this.title,
    required this.originalTitle,
    required this.overview,
    required this.releaseDate,
    required this.year,
    required this.posterUrl,
    required this.backdropUrl,
    required this.rating,
    required this.voteCount,
    required this.popularity,
    required this.genreIds,
  });

  static String _imageUrl(dynamic path, {String size = 'w500'}) {
    final value = (path ?? '').toString().trim();
    if (value.isEmpty) return '';
    if (value.startsWith('http://') || value.startsWith('https://')) return value;
    return 'https://image.tmdb.org/t/p/$size$value';
  }

  factory Movie.fromTmdb(Map<String, dynamic> json) {
    int toInt(dynamic value) => int.tryParse('$value') ?? 0;
    double toDouble(dynamic value) => double.tryParse('$value') ?? 0;
    String toText(dynamic value) => (value ?? '').toString();

    final releaseDate = toText(json['release_date']);
    final rawGenreIds = json['genre_ids'] as List? ?? const [];
    final title = toText(json['title']).trim().isNotEmpty
        ? toText(json['title'])
        : toText(json['name']);
    final originalTitle = toText(json['original_title']).trim().isNotEmpty
        ? toText(json['original_title'])
        : toText(json['original_name']);

    return Movie(
      id: toInt(json['id']),
      title: title,
      originalTitle: originalTitle,
      overview: toText(json['overview']),
      releaseDate: releaseDate,
      year: releaseDate.length >= 4 ? releaseDate.substring(0, 4) : '',
      posterUrl: _imageUrl(json['poster_path']),
      backdropUrl: _imageUrl(json['backdrop_path'], size: 'w1280'),
      rating: toDouble(json['vote_average']),
      voteCount: toInt(json['vote_count']),
      popularity: toDouble(json['popularity']),
      genreIds: rawGenreIds.map(toInt).where((id) => id > 0).toList(),
    );
  }

  factory Movie.fromStored(Map<String, dynamic> json) {
    int toInt(dynamic value) => int.tryParse('$value') ?? 0;
    double toDouble(dynamic value) => double.tryParse('$value') ?? 0;
    String toText(dynamic value) => (value ?? '').toString();
    final genres = json['genre_ids'] as List? ?? const [];
    return Movie(
      id: toInt(json['id']),
      title: toText(json['title']),
      originalTitle: toText(json['original_title']),
      overview: toText(json['overview']),
      releaseDate: toText(json['release_date']),
      year: toText(json['year']),
      posterUrl: toText(json['poster_url']),
      backdropUrl: toText(json['backdrop_url']),
      rating: toDouble(json['rating']),
      voteCount: toInt(json['vote_count']),
      popularity: toDouble(json['popularity']),
      genreIds: genres.map(toInt).where((id) => id > 0).toList(),
    );
  }

  Map<String, dynamic> toStoredJson() => {
        'id': id,
        'title': title,
        'original_title': originalTitle,
        'overview': overview,
        'release_date': releaseDate,
        'year': year,
        'poster_url': posterUrl,
        'backdrop_url': backdropUrl,
        'rating': rating,
        'vote_count': voteCount,
        'popularity': popularity,
        'genre_ids': genreIds,
      };
}

class MoviePage {
  final int page;
  final int totalPages;
  final int totalResults;
  final List<Movie> items;

  const MoviePage({
    required this.page,
    required this.totalPages,
    required this.totalResults,
    required this.items,
  });

  factory MoviePage.fromTmdb(Map<String, dynamic> json) {
    int toInt(dynamic value) => int.tryParse('$value') ?? 0;
    final raw = json['results'] as List? ?? const [];
    return MoviePage(
      page: toInt(json['page']),
      totalPages: toInt(json['total_pages']),
      totalResults: toInt(json['total_results']),
      items: raw
          .whereType<Map>()
          .map((e) => Movie.fromTmdb(e.cast<String, dynamic>()))
          .where((m) => m.id > 0)
          .toList(),
    );
  }
}

class MovieGenre {
  final int id;
  final String name;
  const MovieGenre({required this.id, required this.name});

  factory MovieGenre.fromJson(Map<String, dynamic> json) => MovieGenre(
        id: int.tryParse('${json['id']}') ?? 0,
        name: (json['name'] ?? '').toString(),
      );
}

class MovieProvider {
  final int id;
  final String name;
  final String logoUrl;

  const MovieProvider({required this.id, required this.name, required this.logoUrl});

  factory MovieProvider.fromTmdb(Map<String, dynamic> json) => MovieProvider(
        id: int.tryParse('${json['provider_id']}') ?? 0,
        name: (json['provider_name'] ?? '').toString(),
        logoUrl: Movie._imageUrl(json['logo_path'], size: 'w92'),
      );
}

class MovieCast {
  final int id;
  final String name;
  final String character;
  final String profileUrl;

  const MovieCast({
    required this.id,
    required this.name,
    required this.character,
    required this.profileUrl,
  });

  factory MovieCast.fromTmdb(Map<String, dynamic> json) => MovieCast(
        id: int.tryParse('${json['id']}') ?? 0,
        name: (json['name'] ?? '').toString(),
        character: (json['character'] ?? '').toString(),
        profileUrl: Movie._imageUrl(json['profile_path'], size: 'w185'),
      );
}

class MovieDetails {
  final Movie movie;
  final String tagline;
  final int runtimeMinutes;
  final String status;
  final String homepage;
  final String imdbId;
  final List<MovieGenre> genres;
  final String trailerYoutubeKey;
  final List<MovieCast> cast;
  final String providerRegion;
  final String providerTmdbUrl;
  final List<MovieProvider> streamingProviders;
  final List<MovieProvider> freeProviders;
  final List<MovieProvider> adSupportedProviders;
  final List<MovieProvider> rentProviders;
  final List<MovieProvider> buyProviders;
  final List<Movie> recommendations;

  const MovieDetails({
    required this.movie,
    required this.tagline,
    required this.runtimeMinutes,
    required this.status,
    required this.homepage,
    required this.imdbId,
    required this.genres,
    required this.trailerYoutubeKey,
    required this.cast,
    required this.providerRegion,
    required this.providerTmdbUrl,
    required this.streamingProviders,
    required this.freeProviders,
    required this.adSupportedProviders,
    required this.rentProviders,
    required this.buyProviders,
    required this.recommendations,
  });

  factory MovieDetails.fromTmdb(Map<String, dynamic> json, {required String region}) {
    List<T> parseList<T>(dynamic raw, T Function(Map<String, dynamic>) factory) {
      return (raw as List? ?? const [])
          .whereType<Map>()
          .map((e) => factory(e.cast<String, dynamic>()))
          .toList();
    }

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
    if (trailer == null && youtubeVideos.isNotEmpty) {
      trailer = youtubeVideos.first;
    }

    final credits = (json['credits'] as Map?)?.cast<String, dynamic>() ?? const {};
    final providerRoot = (json['watch/providers'] as Map?)?.cast<String, dynamic>() ?? const {};
    final providerResults = (providerRoot['results'] as Map?)?.cast<String, dynamic>() ?? const {};
    final provider = (providerResults[region] as Map?)?.cast<String, dynamic>() ?? const {};
    final recommendations = (json['recommendations'] as Map?)?.cast<String, dynamic>() ?? const {};

    return MovieDetails(
      movie: Movie.fromTmdb({
        ...json,
        'genre_ids': (json['genres'] as List? ?? const [])
            .whereType<Map>()
            .map((e) => e['id'])
            .toList(),
      }),
      tagline: (json['tagline'] ?? '').toString(),
      runtimeMinutes: int.tryParse('${json['runtime']}') ?? 0,
      status: (json['status'] ?? '').toString(),
      homepage: (json['homepage'] ?? '').toString(),
      imdbId: (json['imdb_id'] ?? '').toString(),
      genres: parseList(json['genres'], MovieGenre.fromJson),
      trailerYoutubeKey: (trailer?['key'] ?? '').toString(),
      cast: parseList(credits['cast'], MovieCast.fromTmdb).take(16).toList(),
      providerRegion: region,
      providerTmdbUrl: (provider['link'] ?? '').toString(),
      streamingProviders: parseList(provider['flatrate'], MovieProvider.fromTmdb),
      freeProviders: parseList(provider['free'], MovieProvider.fromTmdb),
      adSupportedProviders: parseList(provider['ads'], MovieProvider.fromTmdb),
      rentProviders: parseList(provider['rent'], MovieProvider.fromTmdb),
      buyProviders: parseList(provider['buy'], MovieProvider.fromTmdb),
      recommendations: parseList(recommendations['results'], Movie.fromTmdb).take(20).toList(),
    );
  }
}
