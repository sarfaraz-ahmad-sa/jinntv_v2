import 'dart:async';

import 'package:flutter/material.dart';

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

class CineSearchScreen extends StatefulWidget {
  const CineSearchScreen({super.key});

  @override
  State<CineSearchScreen> createState() => _CineSearchScreenState();
}

class _CineSearchScreenState extends State<CineSearchScreen>
    with AutomaticKeepAliveClientMixin {
  late final MovieRepository _movieRepo;
  late final TvRepository _tvRepo;
  final _controller = TextEditingController();
  Timer? _debounce;

  List<Movie> _movies = [];
  List<TvShow> _shows = [];
  List<Movie> _trendingMovies = [];
  List<TvShow> _trendingShows = [];
  List<String> _recent = [];
  bool _loading = false;
  bool _discoverLoading = true;
  String _query = '';
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _movieRepo = MovieRepositoryFactory.create();
    _tvRepo = TvRepositoryFactory.create();
    _loadDiscovery();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    _movieRepo.dispose();
    _tvRepo.dispose();
    super.dispose();
  }

  Future<void> _loadDiscovery() async {
    final recent = await PersonalizationService.instance.recentSearches();
    try {
      final results = await Future.wait<dynamic>([
        _movieRepo.fetchMovies(list: 'trending'),
        _tvRepo.fetchShows(list: 'trending'),
      ]);
      if (!mounted) return;
      setState(() {
        _recent = recent;
        _trendingMovies = (results[0] as MoviePage).items;
        _trendingShows = (results[1] as TvPage).items;
        _discoverLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _recent = recent;
        _discoverLoading = false;
      });
    }
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _query = value.trim();
    setState(() {});
    if (_query.length < 2) {
      setState(() {
        _movies = [];
        _shows = [];
        _loading = false;
        _error = null;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 420), () => _search(_query));
  }

  Future<void> _search(String value) async {
    final query = value.trim();
    if (query.length < 2) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    await PersonalizationService.instance.saveSearch(query);
    try {
      final results = await Future.wait<dynamic>([
        _movieRepo.search(query),
        _tvRepo.search(query),
      ]);
      if (!mounted || query != _query) return;
      final recent = await PersonalizationService.instance.recentSearches();
      if (!mounted) return;
      setState(() {
        _movies = (results[0] as MoviePage).items;
        _shows = (results[1] as TvPage).items;
        _recent = recent;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || query != _query) return;
      setState(() {
        _loading = false;
        _error = 'Search is temporarily unavailable. Please try again.';
      });
    }
  }

  void _useRecent(String value) {
    _controller.text = value;
    _controller.selection = TextSelection.collapsed(offset: value.length);
    _query = value;
    setState(() {});
    _search(value);
  }

  Future<void> _removeRecent(String value) async {
    await PersonalizationService.instance.removeRecentSearch(value);
    final recent = await PersonalizationService.instance.recentSearches();
    if (mounted) setState(() => _recent = recent);
  }

  void _openMovie(Movie movie) => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => MovieDetailsScreen(movieId: movie.id, repository: _movieRepo)),
      );

  void _openTv(TvShow show) => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => TvDetailsScreen(seriesId: show.id, repository: _tvRepo)),
      );

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: const Color(0xFF08090C),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _header()),
            if (_query.length < 2) ..._discoverySlivers() else ..._resultSlivers(),
            const SliverToBoxAdapter(child: SizedBox(height: 36)),
          ],
        ),
      ),
    );
  }

  Widget _header() => Padding(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Search', style: TextStyle(fontSize: 29, fontWeight: FontWeight.w900, letterSpacing: -.7)),
            const SizedBox(height: 5),
            const Text('Find movies and TV series in one place', style: TextStyle(color: Color(0x70FFFFFF), fontSize: 11.5)),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              autofocus: false,
              onChanged: _onChanged,
              onSubmitted: _search,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Movie or TV series...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          _controller.clear();
                          _query = '';
                          setState(() {
                            _movies = [];
                            _shows = [];
                            _error = null;
                          });
                        },
                        icon: const Icon(Icons.close_rounded),
                      ),
              ),
            ),
          ],
        ),
      );

  List<Widget> _discoverySlivers() => [
        if (_recent.isNotEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const PremiumSectionHeader(title: 'Recent searches'),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 38,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      scrollDirection: Axis.horizontal,
                      itemCount: _recent.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 8),
                      itemBuilder: (_, index) {
                        final value = _recent[index];
                        return InputChip(
                          label: Text(value),
                          avatar: const Icon(Icons.history_rounded, size: 16),
                          onPressed: () => _useRecent(value),
                          onDeleted: () => _removeRecent(value),
                          backgroundColor: const Color(0xFF151922),
                          side: BorderSide.none,
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (_discoverLoading)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.only(top: 90),
              child: Center(child: CircularProgressIndicator()),
            ),
          )
        else ...[
          SliverToBoxAdapter(child: _movieRow('Trending movies', _trendingMovies.take(12).toList())),
          SliverToBoxAdapter(child: _tvRow('Trending TV', _trendingShows.take(12).toList())),
        ],
      ];

  List<Widget> _resultSlivers() {
    if (_loading) {
      return const [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.only(top: 100),
            child: Center(child: CircularProgressIndicator()),
          ),
        ),
      ];
    }
    if (_error != null) {
      return [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(30),
            child: Column(
              children: [
                const Icon(Icons.search_off_rounded, color: Colors.white30, size: 50),
                const SizedBox(height: 12),
                Text(_error!, style: const TextStyle(color: Colors.white60)),
              ],
            ),
          ),
        ),
      ];
    }
    if (_movies.isEmpty && _shows.isEmpty) {
      return const [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.only(top: 90),
            child: Center(child: Text('No matching titles found', style: TextStyle(color: Colors.white54))),
          ),
        ),
      ];
    }
    return [
      if (_movies.isNotEmpty) SliverToBoxAdapter(child: _movieRow('Movies', _movies)),
      if (_shows.isNotEmpty) SliverToBoxAdapter(child: _tvRow('TV Series', _shows)),
    ];
  }

  Widget _movieRow(String title, List<Movie> items) => _mediaRow(
        title: title,
        count: items.length,
        card: (index) {
          final item = items[index];
          return PremiumMediaCard(
            title: item.title,
            subtitle: item.year.isEmpty ? 'Movie' : item.year,
            imageUrl: item.posterUrl,
            rating: item.rating,
            onTap: () => _openMovie(item),
          );
        },
      );

  Widget _tvRow(String title, List<TvShow> items) => _mediaRow(
        title: title,
        count: items.length,
        card: (index) {
          final item = items[index];
          return PremiumMediaCard(
            title: item.name,
            subtitle: item.year.isEmpty ? 'TV Series' : item.year,
            imageUrl: item.posterUrl,
            rating: item.rating,
            badge: 'TV',
            onTap: () => _openTv(item),
          );
        },
      );

  Widget _mediaRow({required String title, required int count, required Widget Function(int) card}) {
    if (count == 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PremiumSectionHeader(title: title),
          const SizedBox(height: 11),
          SizedBox(
            height: 248,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              scrollDirection: Axis.horizontal,
              itemCount: count > 20 ? 20 : count,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (_, index) => card(index),
            ),
          ),
        ],
      ),
    );
  }
}
