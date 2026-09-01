import '../../../core/network/tmdb_client.dart';
import '../domain/movie.dart';

class MovieRepository {
  final TmdbClient api;
  final String region;
  final String language;

  MovieRepository(
    this.api, {
    this.region = 'PK',
    this.language = 'en-US',
  });

  Future<MoviePage> fetchMovies({
    String list = 'trending',
    int page = 1,
  }) async {
    late final String path;
    switch (list) {
      case 'popular':
        path = '/3/movie/popular';
        break;
      case 'now-playing':
        path = '/3/movie/now_playing';
        break;
      case 'top-rated':
        path = '/3/movie/top_rated';
        break;
      case 'upcoming':
        path = '/3/movie/upcoming';
        break;
      case 'discover':
        path = '/3/discover/movie';
        break;
      case 'trending':
      default:
        path = '/3/trending/movie/week';
    }

    final query = <String, String>{
      'page': '$page',
      'language': language,
      'region': region,
    };
    if (list == 'discover') {
      query['sort_by'] = 'popularity.desc';
      query['include_adult'] = 'false';
      query['include_video'] = 'false';
    }

    final json = await api.getJson(path, query: query);
    return MoviePage.fromTmdb(json);
  }

  Future<MoviePage> search(String query, {int page = 1}) async {
    final json = await api.getJson(
      '/3/search/movie',
      query: {
        'query': query.trim(),
        'page': '$page',
        'region': region,
        'language': language,
        'include_adult': 'false',
      },
    );
    return MoviePage.fromTmdb(json);
  }

  Future<MoviePage> discoverByGenres(List<int> genreIds, {int page = 1}) async {
    if (genreIds.isEmpty) return fetchMovies(list: 'popular', page: page);
    final json = await api.getJson(
      '/3/discover/movie',
      query: {
        'page': '$page',
        'language': language,
        'region': region,
        'sort_by': 'popularity.desc',
        'include_adult': 'false',
        'include_video': 'false',
        'with_genres': genreIds.take(3).join('|'),
        'vote_count.gte': '40',
      },
    );
    return MoviePage.fromTmdb(json);
  }

  Future<MovieDetails> details(int movieId) async {
    final json = await api.getJson(
      '/3/movie/$movieId',
      query: {
        'region': region,
        'language': language,
        'append_to_response': 'videos,credits,watch/providers,recommendations',
      },
    );
    return MovieDetails.fromTmdb(json, region: region);
  }

  void dispose() => api.dispose();
}
