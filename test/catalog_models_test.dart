import 'package:cinenexa/features/movies/domain/movie.dart';
import 'package:cinenexa/features/tv/domain/tv_show.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Movie maps TMDB fields and genre ids', () {
    final movie = Movie.fromTmdb({
      'id': 7,
      'title': 'Example Movie',
      'release_date': '2026-08-29',
      'vote_average': 8.2,
      'genre_ids': [28, 53],
      'poster_path': '/poster.jpg',
    });

    expect(movie.id, 7);
    expect(movie.year, '2026');
    expect(movie.genreIds, [28, 53]);
    expect(movie.posterUrl, contains('image.tmdb.org'));
  });

  test('TV show maps TMDB fields and genre ids', () {
    final show = TvShow.fromTmdb({
      'id': 11,
      'name': 'Example Series',
      'first_air_date': '2025-02-10',
      'vote_average': 7.8,
      'genre_ids': [18, 10765],
      'origin_country': ['US'],
    });

    expect(show.id, 11);
    expect(show.year, '2025');
    expect(show.genreIds, [18, 10765]);
    expect(show.originCountries, ['US']);
  });
}
