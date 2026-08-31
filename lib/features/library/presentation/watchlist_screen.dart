import 'package:flutter/material.dart';

import '../../../core/services/personalization_service.dart';
import '../../../core/services/user_library_service.dart';
import '../../../core/widgets/premium_media_card.dart';
import '../../movies/data/movie_repository.dart';
import '../../movies/data/movie_repository_factory.dart';
import '../../movies/domain/movie.dart';
import '../../movies/presentation/movies_screen.dart';
import '../../tv/data/tv_repository.dart';
import '../../tv/data/tv_repository_factory.dart';
import '../../tv/domain/tv_show.dart';
import '../../tv/presentation/tv_series_screen.dart';

class WatchlistScreen extends StatefulWidget {
  const WatchlistScreen({super.key});

  @override
  State<WatchlistScreen> createState() => _WatchlistScreenState();
}

class _WatchlistScreenState extends State<WatchlistScreen>
    with AutomaticKeepAliveClientMixin {
  late final MovieRepository _movieRepo;
  late final TvRepository _tvRepo;

  List<Movie> _movies = [];
  List<TvShow> _shows = [];
  List<MediaHistoryItem> _history = [];
  bool _loading = true;
  bool _showMovies = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _movieRepo = MovieRepositoryFactory.create();
    _tvRepo = TvRepositoryFactory.create();
    UserLibraryService.instance.revision.addListener(_onChanged);
    PersonalizationService.instance.revision.addListener(_onChanged);
    _load();
  }

  void _onChanged() => _load();

  @override
  void dispose() {
    UserLibraryService.instance.revision.removeListener(_onChanged);
    PersonalizationService.instance.revision.removeListener(_onChanged);
    _movieRepo.dispose();
    _tvRepo.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final values = await Future.wait<dynamic>([
      UserLibraryService.instance.getWatchlist(),
      UserLibraryService.instance.getTvWatchlist(),
      PersonalizationService.instance.recentlyViewed(limit: 20),
    ]);
    if (!mounted) return;
    setState(() {
      _movies = values[0] as List<Movie>;
      _shows = values[1] as List<TvShow>;
      _history = values[2] as List<MediaHistoryItem>;
      _loading = false;
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

  Future<void> _clearHistory() async {
    await PersonalizationService.instance.clearHistory();
    if (mounted) setState(() => _history = []);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: const Color(0xFF08090C),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _load,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(child: _header()),
                    SliverToBoxAdapter(child: _insightCard()),
                    if (_history.isNotEmpty) SliverToBoxAdapter(child: _historyRow()),
                    SliverToBoxAdapter(child: _switcher()),
                    if (_showMovies) _movieGrid() else _tvGrid(),
                    const SliverToBoxAdapter(child: SizedBox(height: 36)),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _header() => Padding(
        padding: const EdgeInsets.fromLTRB(18, 14, 14, 10),
        child: Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('My Space', style: TextStyle(fontSize: 29, fontWeight: FontWeight.w900, letterSpacing: -.7)),
                  SizedBox(height: 4),
                  Text('Your saved titles and viewing taste', style: TextStyle(color: Color(0x70FFFFFF), fontSize: 11.5)),
                ],
              ),
            ),
            if (_history.isNotEmpty)
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'clear-history') _clearHistory();
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'clear-history', child: Text('Clear viewing history')),
                ],
              ),
          ],
        ),
      );

  Widget _insightCard() {
    final saved = _movies.length + _shows.length;
    final explored = _history.length;
    return Container(
      margin: const EdgeInsets.fromLTRB(18, 10, 18, 10),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF21141A), Color(0xFF11151E)],
        ),
        border: Border.all(color: const Color(0x33FF4050)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(color: const Color(0x22E50914), borderRadius: BorderRadius.circular(16)),
            child: const Icon(Icons.auto_awesome_rounded, color: Color(0xFFFFC857)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Your CineNexa taste', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                const SizedBox(height: 4),
                Text(
                  '$saved saved • $explored recently explored',
                  style: const TextStyle(color: Colors.white54, fontSize: 11.5),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Recommendations adapt as you explore and save more titles.',
                  style: TextStyle(color: Colors.white38, fontSize: 10.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _historyRow() => Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const PremiumSectionHeader(title: 'Recently viewed'),
            const SizedBox(height: 11),
            SizedBox(
              height: 146,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                scrollDirection: Axis.horizontal,
                itemCount: _history.length,
                separatorBuilder: (_, _) => const SizedBox(width: 9),
                itemBuilder: (_, index) {
                  final item = _history[index];
                  return SizedBox(
                    width: 95,
                    child: InkWell(
                      onTap: () => _openHistory(item),
                      borderRadius: BorderRadius.circular(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: Container(
                              width: 95,
                              height: 105,
                              color: const Color(0xFF151922),
                              child: item.posterUrl.isEmpty
                                  ? const Icon(Icons.movie_outlined, color: Colors.white24)
                                  : Image.network(item.posterUrl, fit: BoxFit.cover, errorBuilder: (_, _, _) => const Icon(Icons.movie_outlined, color: Colors.white24)),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(item.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      );

  Widget _switcher() => Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
        child: Row(
          children: [
            Expanded(
              child: _SegmentButton(
                selected: _showMovies,
                label: 'Movies (${_movies.length})',
                icon: Icons.movie_outlined,
                onTap: () => setState(() => _showMovies = true),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _SegmentButton(
                selected: !_showMovies,
                label: 'TV (${_shows.length})',
                icon: Icons.live_tv_rounded,
                onTap: () => setState(() => _showMovies = false),
              ),
            ),
          ],
        ),
      );

  Widget _movieGrid() {
    if (_movies.isEmpty) return _emptyGrid('No saved movies yet', 'Open any movie and tap Add to My List.');
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 210,
          mainAxisSpacing: 15,
          crossAxisSpacing: 10,
          childAspectRatio: .58,
        ),
        delegate: SliverChildBuilderDelegate(
          (_, index) {
            final movie = _movies[index];
            return Stack(
              children: [
                Positioned.fill(
                  child: PremiumMediaCard(
                    title: movie.title,
                    subtitle: movie.year.isEmpty ? 'Movie' : movie.year,
                    imageUrl: movie.posterUrl,
                    rating: movie.rating,
                    onTap: () => _openMovie(movie),
                    width: double.infinity,
                    fillHeight: true,
                  ),
                ),
                Positioned(
                  right: 5,
                  top: 5,
                  child: IconButton.filledTonal(
                    tooltip: 'Remove',
                    onPressed: () => UserLibraryService.instance.remove(movie.id),
                    icon: const Icon(Icons.close_rounded, size: 18),
                  ),
                ),
              ],
            );
          },
          childCount: _movies.length,
        ),
      ),
    );
  }

  Widget _tvGrid() {
    if (_shows.isEmpty) return _emptyGrid('No saved TV series yet', 'Open a series and tap Add to My List.');
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 210,
          mainAxisSpacing: 15,
          crossAxisSpacing: 10,
          childAspectRatio: .58,
        ),
        delegate: SliverChildBuilderDelegate(
          (_, index) {
            final show = _shows[index];
            return Stack(
              children: [
                Positioned.fill(
                  child: PremiumMediaCard(
                    title: show.name,
                    subtitle: show.year.isEmpty ? 'TV Series' : show.year,
                    imageUrl: show.posterUrl,
                    rating: show.rating,
                    badge: 'TV',
                    onTap: () => _openTv(show),
                    width: double.infinity,
                    fillHeight: true,
                  ),
                ),
                Positioned(
                  right: 5,
                  top: 5,
                  child: IconButton.filledTonal(
                    tooltip: 'Remove',
                    onPressed: () => UserLibraryService.instance.removeTv(show.id),
                    icon: const Icon(Icons.close_rounded, size: 18),
                  ),
                ),
              ],
            );
          },
          childCount: _shows.length,
        ),
      ),
    );
  }

  Widget _emptyGrid(String title, String subtitle) => SliverList(
        delegate: SliverChildListDelegate([
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 48, 28, 70),
            child: Column(
              children: [
                const Icon(Icons.bookmark_add_outlined, color: Colors.white24, size: 54),
                const SizedBox(height: 13),
                Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                const SizedBox(height: 5),
                Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(color: Color(0x70FFFFFF))),
              ],
            ),
          ),
        ]),
      );
}

class _SegmentButton extends StatelessWidget {
  final bool selected;
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _SegmentButton({
    required this.selected,
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Material(
        color: selected ? const Color(0xFFE50914) : const Color(0xFF151922),
        borderRadius: BorderRadius.circular(13),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(13),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 18),
                const SizedBox(width: 7),
                Flexible(child: Text(label, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12))),
              ],
            ),
          ),
        ),
      );
}
