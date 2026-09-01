import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/config/app_config.dart';
import '../../../core/services/personalization_service.dart';
import '../../../core/widgets/premium_media_card.dart';
import '../../movies/data/movie_repository.dart';
import '../../movies/data/movie_repository_factory.dart';
import '../../movies/domain/movie.dart';
import '../../movies/presentation/movies_screen.dart';
import '../../tv/data/tv_repository.dart';
import '../../tv/data/tv_repository_factory.dart';
import '../../tv/domain/tv_show.dart';
import '../../tv/presentation/tv_series_screen.dart';

class CineHomeScreen extends StatefulWidget {
  const CineHomeScreen({super.key});

  @override
  State<CineHomeScreen> createState() => _CineHomeScreenState();
}

class _CineHomeScreenState extends State<CineHomeScreen>
    with AutomaticKeepAliveClientMixin {
  late final MovieRepository _movieRepo;
  late final TvRepository _tvRepo;
  final _heroController = PageController();
  Timer? _heroTimer;
  Timer? _personalizationTimer;

  bool _loading = true;
  String? _error;
  int _heroIndex = 0;
  List<Movie> _trendingMovies = [];
  List<Movie> _popularMovies = [];
  List<Movie> _nowPlaying = [];
  List<Movie> _topRatedMovies = [];
  List<Movie> _forYouMovies = [];
  List<TvShow> _trendingTv = [];
  List<TvShow> _popularTv = [];
  List<TvShow> _forYouTv = [];
  List<MediaHistoryItem> _history = [];
  String? _lastCatalogError;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _movieRepo = MovieRepositoryFactory.create();
    _tvRepo = TvRepositoryFactory.create();
    PersonalizationService.instance.revision.addListener(_reloadPersonalization);
    _load();
  }

  @override
  void dispose() {
    PersonalizationService.instance.revision.removeListener(_reloadPersonalization);
    _heroTimer?.cancel();
    _personalizationTimer?.cancel();
    _heroController.dispose();
    _movieRepo.dispose();
    _tvRepo.dispose();
    super.dispose();
  }

  void _reloadPersonalization() {
    PersonalizationService.instance.recentlyViewed(limit: 12).then((items) {
      if (mounted) setState(() => _history = items);
    });
    _personalizationTimer?.cancel();
    _personalizationTimer = Timer(const Duration(milliseconds: 650), _refreshPersonalizedRows);
  }

  Future<void> _refreshPersonalizedRows() async {
    try {
      final values = await Future.wait<dynamic>([
        PersonalizationService.instance.topMovieGenreIds(),
        PersonalizationService.instance.topTvGenreIds(),
      ]);
      final movieGenres = values[0] as List<int>;
      final tvGenres = values[1] as List<int>;
      final results = await Future.wait<dynamic>([
        if (movieGenres.isNotEmpty) _movieRepo.discoverByGenres(movieGenres),
        if (tvGenres.isNotEmpty) _tvRepo.discoverByGenres(tvGenres),
      ]);
      if (!mounted) return;
      var index = 0;
      setState(() {
        if (movieGenres.isNotEmpty) _forYouMovies = (results[index++] as MoviePage).items;
        if (tvGenres.isNotEmpty) _forYouTv = (results[index++] as TvPage).items;
      });
    } catch (_) {}
  }


  Future<MoviePage> _movieOrEmpty(Future<MoviePage> Function() load) async {
    try {
      return await load();
    } catch (e) {
      _lastCatalogError ??= e.toString();
      return const MoviePage(page: 1, totalPages: 0, totalResults: 0, items: <Movie>[]);
    }
  }

  Future<TvPage> _tvOrEmpty(Future<TvPage> Function() load) async {
    try {
      return await load();
    } catch (e) {
      _lastCatalogError ??= e.toString();
      return const TvPage(page: 1, totalPages: 0, totalResults: 0, items: <TvShow>[]);
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _lastCatalogError = null;
    });
    try {
      final prefs = await Future.wait<dynamic>([
        PersonalizationService.instance.topMovieGenreIds(),
        PersonalizationService.instance.topTvGenreIds(),
        PersonalizationService.instance.recentlyViewed(limit: 12),
      ]);
      final movieGenres = prefs[0] as List<int>;
      final tvGenres = prefs[1] as List<int>;
      final history = prefs[2] as List<MediaHistoryItem>;

      final results = await Future.wait<dynamic>([
        _movieOrEmpty(() => _movieRepo.fetchMovies(list: 'trending')),
        _movieOrEmpty(() => _movieRepo.fetchMovies(list: 'popular')),
        _movieOrEmpty(() => _movieRepo.fetchMovies(list: 'now-playing')),
        _movieOrEmpty(() => _movieRepo.fetchMovies(list: 'top-rated')),
        _tvOrEmpty(() => _tvRepo.fetchShows(list: 'trending')),
        _tvOrEmpty(() => _tvRepo.fetchShows(list: 'popular')),
        if (movieGenres.isNotEmpty)
          _movieOrEmpty(() => _movieRepo.discoverByGenres(movieGenres)),
        if (tvGenres.isNotEmpty)
          _tvOrEmpty(() => _tvRepo.discoverByGenres(tvGenres)),
      ]);

      if (!mounted) return;
      var index = 0;
      final trendingMovies = (results[index++] as MoviePage).items;
      final popularMovies = (results[index++] as MoviePage).items;
      final nowPlaying = (results[index++] as MoviePage).items;
      final topRated = (results[index++] as MoviePage).items;
      final trendingTv = (results[index++] as TvPage).items;
      final popularTv = (results[index++] as TvPage).items;
      final forYouMovies = movieGenres.isNotEmpty ? (results[index++] as MoviePage).items : <Movie>[];
      final forYouTv = tvGenres.isNotEmpty ? (results[index++] as TvPage).items : <TvShow>[];

      final hasAnyCatalog = trendingMovies.isNotEmpty ||
          popularMovies.isNotEmpty ||
          nowPlaying.isNotEmpty ||
          topRated.isNotEmpty ||
          trendingTv.isNotEmpty ||
          popularTv.isNotEmpty ||
          forYouMovies.isNotEmpty ||
          forYouTv.isNotEmpty;

      if (!hasAnyCatalog && _lastCatalogError != null) {
        setState(() {
          _loading = false;
          _error = _lastCatalogError;
          _history = history;
        });
        return;
      }

      setState(() {
        _trendingMovies = trendingMovies;
        _popularMovies = popularMovies;
        _nowPlaying = nowPlaying;
        _topRatedMovies = topRated;
        _trendingTv = trendingTv;
        _popularTv = popularTv;
        _forYouMovies = forYouMovies;
        _forYouTv = forYouTv;
        _history = history;
        _loading = false;
      });
      _startHeroTimer();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  List<_HeroEntry> get _heroEntries {
    final items = <_HeroEntry>[];
    for (final movie in _trendingMovies.take(4)) {
      items.add(_HeroEntry(
        isTv: false,
        title: movie.title,
        overview: movie.overview,
        year: movie.year,
        backdropUrl: movie.backdropUrl,
        rating: movie.rating,
        open: () => _openMovie(movie),
      ));
    }
    for (final show in _trendingTv.take(3)) {
      items.add(_HeroEntry(
        isTv: true,
        title: show.name,
        overview: show.overview,
        year: show.year,
        backdropUrl: show.backdropUrl,
        rating: show.rating,
        open: () => _openTv(show),
      ));
    }
    return items;
  }

  void _startHeroTimer() {
    _heroTimer?.cancel();
    _heroTimer = Timer.periodic(const Duration(seconds: 6), (_) {
      final count = _heroEntries.length;
      if (!mounted || count < 2 || !_heroController.hasClients) return;
      final next = (_heroIndex + 1) % count;
      _heroController.animateToPage(
        next,
        duration: const Duration(milliseconds: 650),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  void _openMovie(Movie movie) => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => MovieDetailsScreen(movieId: movie.id, repository: _movieRepo)),
      );

  void _openTv(TvShow show) => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => TvDetailsScreen(seriesId: show.id, repository: _tvRepo)),
      );

  void _openHistory(MediaHistoryItem item) {
    if (item.isTv) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => TvDetailsScreen(seriesId: item.id, repository: _tvRepo)),
      );
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => MovieDetailsScreen(movieId: item.id, repository: _movieRepo)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: const Color(0xFF08090C),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: _loading
              ? const _HomeSkeleton()
              : _error != null
                  ? _errorView()
                  : ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.only(bottom: 28),
                      children: [
                        _topBar(),
                        if (_heroEntries.isNotEmpty) _heroCarousel(),
                        if (_history.isNotEmpty) _historyRow(),
                        if (_forYouMovies.isNotEmpty) _movieRow('Picked for you', _forYouMovies, subtitle: 'Based on the movies you explore'),
                        if (_forYouTv.isNotEmpty) _tvRow('Series for you', _forYouTv, subtitle: 'Your TV taste, refined over time'),
                        _movieRow('Trending movies', _trendingMovies),
                        _tvRow('Binge-worthy TV', _trendingTv),
                        _movieRow('Popular on CineNexa', _popularMovies),
                        _tvRow('Popular series', _popularTv),
                        _movieRow('In theatres', _nowPlaying),
                        _movieRow('Critics & crowd favorites', _topRatedMovies),
                        const Padding(
                          padding: EdgeInsets.fromLTRB(20, 24, 20, 8),
                          child: Text(
                            'Movie and TV metadata powered by TMDB. CineNexa is not endorsed or certified by TMDB.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.white24, fontSize: 10.5, height: 1.35),
                          ),
                        ),
                      ],
                    ),
        ),
      ),
    );
  }

  Widget _topBar() {
    final user = FirebaseAuth.instance.currentUser;
    final name = (user?.displayName ?? '').trim();
    final greetingName = name.isEmpty ? '' : ', ${name.split(' ').first}';
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 10, 14, 10),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(13),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFFF3344), Color(0xFFB00009)],
              ),
              boxShadow: const [BoxShadow(color: Color(0x44E50914), blurRadius: 18, offset: Offset(0, 7))],
            ),
            child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(AppConfig.appName, style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900, letterSpacing: -.8)),
                Text('Good to see you$greetingName', style: const TextStyle(color: Colors.white38, fontSize: 10.5)),
              ],
            ),
          ),
          IconButton.filledTonal(
            tooltip: 'Refresh recommendations',
            onPressed: _load,
            icon: const Icon(Icons.auto_awesome_rounded, size: 20),
          ),
        ],
      ),
    );
  }

  Widget _heroCarousel() {
    final heroes = _heroEntries;
    return Column(
      children: [
        SizedBox(
          height: MediaQuery.sizeOf(context).width < 600 ? 505 : 560,
          child: PageView.builder(
            controller: _heroController,
            itemCount: heroes.length,
            onPageChanged: (value) => setState(() => _heroIndex = value),
            itemBuilder: (_, index) => _hero(heroes[index]),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            heroes.length,
            (index) => AnimatedContainer(
              duration: const Duration(milliseconds: 260),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              width: index == _heroIndex ? 20 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: index == _heroIndex ? const Color(0xFFE50914) : Colors.white24,
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _hero(_HeroEntry entry) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            fit: StackFit.expand,
            children: [
              const ColoredBox(color: Color(0xFF151922)),
              if (entry.backdropUrl.isNotEmpty)
                CachedNetworkImage(imageUrl: entry.backdropUrl, fit: BoxFit.cover),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0x18000000), Color(0x30000000), Color(0xF208090C)],
                    stops: [0, .48, 1],
                  ),
                ),
              ),
              Positioned(
                left: 20,
                right: 20,
                bottom: 24,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: const Color(0xFFE50914), borderRadius: BorderRadius.circular(20)),
                          child: Text(entry.isTv ? 'TRENDING SERIES' : 'FEATURED MOVIE', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: .8)),
                        ),
                        if (entry.rating > 0) ...[
                          const SizedBox(width: 8),
                          Text('★ ${entry.rating.toStringAsFixed(1)}', style: const TextStyle(color: Color(0xFFFFD166), fontSize: 12, fontWeight: FontWeight.w800)),
                        ],
                      ],
                    ),
                    const SizedBox(height: 9),
                    Text(entry.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 31, height: 1.02, fontWeight: FontWeight.w900, letterSpacing: -.8)),
                    const SizedBox(height: 9),
                    Text(
                      [if (entry.year.isNotEmpty) entry.year, entry.isTv ? 'TV Series' : 'Movie'].join('  •  '),
                      style: const TextStyle(color: Colors.white60, fontSize: 12),
                    ),
                    if (entry.overview.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(entry.overview, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, height: 1.42, fontSize: 12.5)),
                    ],
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black),
                            onPressed: entry.open,
                            icon: const Icon(Icons.play_arrow_rounded),
                            label: const Text('Explore'),
                          ),
                        ),
                        const SizedBox(width: 9),
                        IconButton.filledTonal(
                          tooltip: 'Details',
                          onPressed: entry.open,
                          icon: const Icon(Icons.info_outline_rounded),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );

  Widget _historyRow() => Padding(
        padding: const EdgeInsets.only(top: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const PremiumSectionHeader(title: 'Continue exploring', subtitle: 'Recently viewed on CineNexa'),
            const SizedBox(height: 11),
            SizedBox(
              height: 150,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                scrollDirection: Axis.horizontal,
                itemCount: _history.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (_, index) {
                  final item = _history[index];
                  return SizedBox(
                    width: 220,
                    child: InkWell(
                      onTap: () => _openHistory(item),
                      borderRadius: BorderRadius.circular(16),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            const ColoredBox(color: Color(0xFF151922)),
                            if (item.backdropUrl.isNotEmpty)
                              CachedNetworkImage(imageUrl: item.backdropUrl, fit: BoxFit.cover),
                            const DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.transparent, Color(0xE6000000)]),
                              ),
                            ),
                            Positioned(
                              left: 12,
                              right: 12,
                              bottom: 11,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 13)),
                                  const SizedBox(height: 3),
                                  Text(item.isTv ? 'TV Series • Continue' : 'Movie • Continue', style: const TextStyle(color: Colors.white54, fontSize: 10)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      );

  Widget _movieRow(String title, List<Movie> movies, {String? subtitle}) {
    if (movies.isEmpty) return const SizedBox.shrink();
    return _row(
      title: title,
      subtitle: subtitle,
      count: movies.take(18).length,
      builder: (index) {
        final movie = movies[index];
        return PremiumMediaCard(
          title: movie.title,
          subtitle: movie.year.isEmpty ? 'Movie' : movie.year,
          imageUrl: movie.posterUrl,
          rating: movie.rating,
          onTap: () => _openMovie(movie),
        );
      },
    );
  }

  Widget _tvRow(String title, List<TvShow> shows, {String? subtitle}) {
    if (shows.isEmpty) return const SizedBox.shrink();
    return _row(
      title: title,
      subtitle: subtitle,
      count: shows.take(18).length,
      builder: (index) {
        final show = shows[index];
        return PremiumMediaCard(
          title: show.name,
          subtitle: show.year.isEmpty ? 'TV Series' : show.year,
          imageUrl: show.posterUrl,
          rating: show.rating,
          badge: 'TV',
          onTap: () => _openTv(show),
        );
      },
    );
  }

  Widget _row({required String title, String? subtitle, required int count, required Widget Function(int) builder}) => Padding(
        padding: const EdgeInsets.only(top: 26),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PremiumSectionHeader(title: title, subtitle: subtitle),
            const SizedBox(height: 11),
            SizedBox(
              height: 250,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                scrollDirection: Axis.horizontal,
                itemCount: count,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (_, index) => builder(index),
              ),
            ),
          ],
        ),
      );

  Widget _errorView() => ListView(
        padding: const EdgeInsets.all(28),
        children: [
          const SizedBox(height: 120),
          const Icon(Icons.movie_filter_rounded, color: Colors.white30, size: 60),
          const SizedBox(height: 18),
          Text(
            AppConfig.hasMovieApi
                ? 'CineNexa could not load your feed.\n$_error'
                : 'Movie API setup is required. Configure TMDB_PROXY_URL or TMDB_ACCESS_TOKEN.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, height: 1.5),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(onPressed: _load, icon: const Icon(Icons.refresh_rounded), label: const Text('Try again')),
        ],
      );
}

class _HeroEntry {
  final bool isTv;
  final String title;
  final String overview;
  final String year;
  final String backdropUrl;
  final double rating;
  final VoidCallback open;

  const _HeroEntry({
    required this.isTv,
    required this.title,
    required this.overview,
    required this.year,
    required this.backdropUrl,
    required this.rating,
    required this.open,
  });

}

class _HomeSkeleton extends StatelessWidget {
  const _HomeSkeleton();

  @override
  Widget build(BuildContext context) => ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(14),
        children: [
          const SizedBox(height: 8),
          Row(children: [
            _box(40, 40, radius: 13),
            const SizedBox(width: 10),
            Expanded(child: _box(120, 22, radius: 8)),
          ]),
          const SizedBox(height: 18),
          _box(double.infinity, 465, radius: 24),
          const SizedBox(height: 28),
          _box(180, 22, radius: 8),
          const SizedBox(height: 12),
          SizedBox(
            height: 220,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: 5,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (_, _) => _box(136, 198, radius: 16),
            ),
          ),
        ],
      );

  static Widget _box(double width, double height, {double radius = 12}) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(color: const Color(0xFF151922), borderRadius: BorderRadius.circular(radius)),
      );
}
