import '../../../core/network/tmdb_client.dart';
import '../domain/tv_show.dart';

class TvRepository {
  final TmdbClient api;
  final String region;
  final String language;

  TvRepository(
    this.api, {
    this.region = 'PK',
    this.language = 'en-US',
  });

  Future<TvPage> fetchShows({String list = 'trending', int page = 1}) async {
    late final String path;
    switch (list) {
      case 'popular':
        path = '/3/tv/popular';
        break;
      case 'on-air':
        path = '/3/tv/on_the_air';
        break;
      case 'airing-today':
        path = '/3/tv/airing_today';
        break;
      case 'top-rated':
        path = '/3/tv/top_rated';
        break;
      case 'discover':
        path = '/3/discover/tv';
        break;
      case 'trending':
      default:
        path = '/3/trending/tv/week';
    }

    final query = <String, String>{
      'page': '$page',
      'language': language,
    };
    if (list == 'discover') {
      query.addAll({
        'sort_by': 'popularity.desc',
        'include_adult': 'false',
        'watch_region': region,
      });
    }

    final json = await api.getJson(path, query: query);
    return TvPage.fromTmdb(json);
  }

  Future<TvPage> search(String query, {int page = 1}) async {
    final json = await api.getJson(
      '/3/search/tv',
      query: {
        'query': query.trim(),
        'page': '$page',
        'language': language,
        'include_adult': 'false',
      },
    );
    return TvPage.fromTmdb(json);
  }

  Future<TvPage> discoverByGenres(List<int> genreIds, {int page = 1}) async {
    if (genreIds.isEmpty) return fetchShows(list: 'popular', page: page);
    final json = await api.getJson(
      '/3/discover/tv',
      query: {
        'page': '$page',
        'language': language,
        'sort_by': 'popularity.desc',
        'include_adult': 'false',
        'watch_region': region,
        'with_genres': genreIds.take(3).join('|'),
        'vote_count.gte': '30',
      },
    );
    return TvPage.fromTmdb(json);
  }

  Future<TvDetails> details(int seriesId) async {
    final json = await api.getJson(
      '/3/tv/$seriesId',
      query: {
        'language': language,
        'append_to_response': 'videos,credits,watch/providers,recommendations',
      },
    );
    return TvDetails.fromTmdb(json, region: region);
  }

  Future<TvSeasonDetails> seasonDetails(int seriesId, int seasonNumber) async {
    final json = await api.getJson(
      '/3/tv/$seriesId/season/$seasonNumber',
      query: {'language': language},
    );
    return TvSeasonDetails.fromTmdb(json);
  }

  void dispose() => api.dispose();
}
