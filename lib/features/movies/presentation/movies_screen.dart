import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/services/personalization_service.dart';
import '../../../core/services/user_library_service.dart';
import '../../player/data/playback_source_service.dart';
import '../../player/presentation/cinenexa_player_screen.dart';
import '../data/movie_repository_factory.dart';
import '../data/movie_repository.dart';
import '../domain/movie.dart';

class MoviesScreen extends StatefulWidget {
  final bool searchOnly;
  final bool embedded;
  const MoviesScreen({super.key, this.searchOnly = false, this.embedded = false});

  @override
  State<MoviesScreen> createState() => _MoviesScreenState();
}

class _MoviesScreenState extends State<MoviesScreen>
    with AutomaticKeepAliveClientMixin {
  static const _bg = Color(0xFF08090C);
  static const _surface = Color(0xFF151922);
  static const _accent = Color(0xFFE50914);

  late final MovieRepository _repo;
  final _searchCtrl = TextEditingController();
  final _scroll = ScrollController();
  Timer? _debounce;

  final List<Movie> _items = [];
  String _list = 'trending';
  String _query = '';
  int _page = 1;
  int _totalPages = 1;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _repo = MovieRepositoryFactory.create();
    _scroll.addListener(_onScroll);
    _load(reset: true);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _scroll.dispose();
    _repo.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients || _loading || _loadingMore || _page >= _totalPages) {
      return;
    }
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 500) {
      _loadMore();
    }
  }

  Future<void> _load({required bool reset}) async {
    if (reset) {
      setState(() {
        _loading = true;
        _error = null;
        _page = 1;
      });
    }

    try {
      final result = _query.length >= 2
          ? await _repo.search(_query, page: 1)
          : await _repo.fetchMovies(list: _list, page: 1);
      if (!mounted) return;
      setState(() {
        _items
          ..clear()
          ..addAll(result.items);
        _page = result.page <= 0 ? 1 : result.page;
        _totalPages = result.totalPages <= 0 ? 1 : result.totalPages;
        _loading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _friendlyError(e);
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _page >= _totalPages) return;
    setState(() => _loadingMore = true);
    try {
      final nextPage = _page + 1;
      final result = _query.length >= 2
          ? await _repo.search(_query, page: nextPage)
          : await _repo.fetchMovies(list: _list, page: nextPage);
      if (!mounted) return;
      setState(() {
        _items.addAll(result.items);
        _page = result.page;
        _totalPages = result.totalPages;
        _loadingMore = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _query = value.trim();
    if (mounted) setState(() {});
    _debounce = Timer(const Duration(milliseconds: 450), () {
      if (!mounted) return;
      if (_query.isEmpty || _query.length >= 2) {
        if (_query.length >= 2) PersonalizationService.instance.saveSearch(_query);
        _load(reset: true);
      }
    });
  }

  void _selectList(String value) {
    if (_list == value && _query.isEmpty) return;
    _searchCtrl.clear();
    _query = '';
    setState(() => _list = value);
    _load(reset: true);
  }

  String _friendlyError(Object error) {
    final text = error.toString();
    if (text.contains('not configured') || text.contains('TMDB_ACCESS_TOKEN')) {
      return 'Movie API setup is required. Configure TMDB_PROXY_URL (recommended) or TMDB_ACCESS_TOKEN with --dart-define.';
    }
    return 'Movies could not be loaded. Check your internet connection and TMDB configuration, then try again.';
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final content = RefreshIndicator(
      onRefresh: () => _load(reset: true),
      child: CustomScrollView(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: _header()),
              if (!widget.searchOnly) SliverToBoxAdapter(child: _filters()),
              if (_loading)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_error != null)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: _errorState(),
                )
              else if (_items.isEmpty)
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Text(
                      'No movies found',
                      style: TextStyle(color: Colors.white70, fontSize: 16),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 18),
                  sliver: SliverGrid(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _MovieCard(
                        movie: _items[index],
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => MovieDetailsScreen(
                              movieId: _items[index].id,
                              repository: _repo,
                            ),
                          ),
                        ),
                      ),
                      childCount: _items.length,
                    ),
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 210,
                      mainAxisSpacing: 14,
                      crossAxisSpacing: 10,
                      childAspectRatio: 0.56,
                    ),
                  ),
                ),
              if (_loadingMore)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: 24),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ),
              const SliverToBoxAdapter(child: _Attribution()),
          const SliverToBoxAdapter(child: SizedBox(height: 12)),
        ],
      ),
    );

    if (widget.embedded) {
      return ColoredBox(color: _bg, child: content);
    }
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(child: content),
    );
  }

  Widget _header() {
    final title = widget.searchOnly ? 'Search' : 'Movies';
    final subtitle = widget.searchOnly
        ? 'Search the global movie catalog'
        : 'Discover movies, trailers & where to watch';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!widget.embedded) ...[
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: const TextStyle(color: Colors.white, fontSize: 28, height: 1, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 6),
                      Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 12.5)),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Refresh',
                  onPressed: () => _load(reset: true),
                  icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
          TextField(
            controller: _searchCtrl,
            autofocus: widget.searchOnly,
            onChanged: _onSearchChanged,
            textInputAction: TextInputAction.search,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Search movies...',
              hintStyle: const TextStyle(color: Colors.white38),
              prefixIcon: const Icon(Icons.search_rounded, color: Colors.white54),
              suffixIcon: _searchCtrl.text.isNotEmpty
                  ? IconButton(
                      onPressed: () {
                        _searchCtrl.clear();
                        _query = '';
                        setState(() {});
                        _load(reset: true);
                      },
                      icon: const Icon(Icons.close_rounded, color: Colors.white54),
                    )
                  : null,
              filled: true,
              fillColor: _surface,
              contentPadding: const EdgeInsets.symmetric(vertical: 13),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
            ),
          ),
        ],
      ),
    );
  }

  Widget _filters() {
    const choices = <String, String>{
      'discover': 'All Movies',
      'trending': 'Trending',
      'popular': 'Popular',
      'now-playing': 'In Theatres',
      'top-rated': 'Top Rated',
      'upcoming': 'Upcoming',
    };

    return SizedBox(
      height: 46,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        scrollDirection: Axis.horizontal,
        itemBuilder: (context, index) {
          final entry = choices.entries.elementAt(index);
          final selected = _query.isEmpty && _list == entry.key;
          return ChoiceChip(
            selected: selected,
            onSelected: (_) => _selectList(entry.key),
            label: Text(entry.value),
            labelStyle: TextStyle(
              color: selected ? Colors.white : Colors.white70,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
            selectedColor: _accent,
            backgroundColor: _surface,
            side: BorderSide.none,
            showCheckmark: false,
          );
        },
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemCount: choices.length,
      ),
    );
  }

  Widget _errorState() {
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.cloud_off_rounded, color: Colors.white38, size: 46),
          const SizedBox(height: 14),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, height: 1.45),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: () => _load(reset: true),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Try again'),
          ),
        ],
      ),
    );
  }
}

class _MovieCard extends StatelessWidget {
  final Movie movie;
  final VoidCallback onTap;

  const _MovieCard({required this.movie, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(color: const Color(0xFF171B23)),
                  if (movie.posterUrl.isNotEmpty)
                    CachedNetworkImage(
                      imageUrl: movie.posterUrl,
                      fit: BoxFit.cover,
                      placeholder: (_, _) => const Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      errorWidget: (_, _, _) => const Icon(
                        Icons.movie_outlined,
                        color: Colors.white30,
                        size: 42,
                      ),
                    )
                  else
                    const Icon(Icons.movie_outlined, color: Colors.white30, size: 42),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: .72),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.star_rounded, color: Colors.amber, size: 13),
                          const SizedBox(width: 3),
                          Text(
                            movie.rating.toStringAsFixed(1),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            movie.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 13,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            movie.year.isEmpty ? 'Movie' : movie.year,
            style: const TextStyle(color: Color(0x70FFFFFF), fontSize: 11.5),
          ),
        ],
      ),
    );
  }
}

class MovieDetailsScreen extends StatefulWidget {
  final int movieId;
  final MovieRepository repository;

  const MovieDetailsScreen({
    super.key,
    required this.movieId,
    required this.repository,
  });

  @override
  State<MovieDetailsScreen> createState() => _MovieDetailsScreenState();
}

class _MovieDetailsScreenState extends State<MovieDetailsScreen> {
  late Future<MovieDetails> _future;
  bool _inList = false;
  int? _recordedId;

  @override
  void initState() {
    super.initState();
    _future = widget.repository.details(widget.movieId);
    UserLibraryService.instance.contains(widget.movieId).then((value) {
      if (mounted) setState(() => _inList = value);
    });
  }

  Future<void> _open(String value) async {
    final uri = Uri.tryParse(value);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _playMovie(Movie movie) async {
    final messenger = ScaffoldMessenger.of(context);
    final source = await PlaybackSourceService.instance.movie(
      movie.id,
      title: movie.title,
    );
    if (!mounted) return;
    if (source == null) {
      messenger.showSnackBar(
        SnackBar(content: Text('No CineNexa source configured yet (movie_${movie.id}).')),
      );
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CineNexaPlayerScreen(source: source),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF08090C),
      body: FutureBuilder<MovieDetails>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return SafeArea(
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                    ),
                  ),
                  const Spacer(),
                  const Text('Movie details could not be loaded', style: TextStyle(color: Colors.white70)),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => setState(() {
                      _future = widget.repository.details(widget.movieId);
                    }),
                    child: const Text('Retry'),
                  ),
                  const Spacer(),
                ],
              ),
            );
          }

          final d = snapshot.data!;
          final m = d.movie;
          if (_recordedId != m.id) {
            _recordedId = m.id;
            PersonalizationService.instance.recordMovieView(
              m,
              genreIds: d.genres.map((g) => g.id).toList(),
            );
          }
          return CustomScrollView(
            slivers: [
              SliverAppBar(
                pinned: true,
                expandedHeight: 310,
                backgroundColor: const Color(0xFF08090C),
                foregroundColor: Colors.white,
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (m.backdropUrl.isNotEmpty)
                        CachedNetworkImage(imageUrl: m.backdropUrl, fit: BoxFit.cover)
                      else
                        Container(color: const Color(0xFF151922)),
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, Color(0xFF08090C)],
                            stops: [0.42, 1],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        m.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          height: 1.08,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      if (d.tagline.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(d.tagline, style: const TextStyle(color: Colors.white54, fontStyle: FontStyle.italic)),
                      ],
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (m.year.isNotEmpty) _Meta(text: m.year),
                          if (d.runtimeMinutes > 0) _Meta(text: '${d.runtimeMinutes} min'),
                          _Meta(text: '★ ${m.rating.toStringAsFixed(1)}'),
                          ...d.genres.take(3).map((g) => _Meta(text: g.name)),
                        ],
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                          ),
                          onPressed: () => _playMovie(m),
                          icon: const Icon(Icons.play_arrow_rounded),
                          label: const Text('Watch now'),
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            if (_inList) {
                              await UserLibraryService.instance.remove(m.id);
                            } else {
                              await UserLibraryService.instance.add(m);
                            }
                            if (mounted) setState(() => _inList = !_inList);
                          },
                          icon: Icon(_inList ? Icons.bookmark_rounded : Icons.bookmark_add_outlined),
                          label: Text(_inList ? 'Remove from My List' : 'Add to My List'),
                        ),
                      ),
                      if (m.overview.isNotEmpty) ...[
                        const SizedBox(height: 22),
                        const _SectionTitle('Story'),
                        const SizedBox(height: 8),
                        Text(
                          m.overview,
                          style: const TextStyle(color: Colors.white70, height: 1.55, fontSize: 14),
                        ),
                      ],
                      if (d.cast.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        const _SectionTitle('Cast'),
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 128,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: d.cast.length,
                            separatorBuilder: (_, _) => const SizedBox(width: 12),
                            itemBuilder: (_, index) => _CastCard(person: d.cast[index]),
                          ),
                        ),
                      ],
                      if (_hasProviders(d)) ...[
                        const SizedBox(height: 24),
                        _SectionTitle('Where to watch • ${d.providerRegion}'),
                        const SizedBox(height: 10),
                        _ProviderGroup(title: 'Streaming', providers: d.streamingProviders),
                        _ProviderGroup(title: 'Free', providers: d.freeProviders),
                        _ProviderGroup(title: 'With ads', providers: d.adSupportedProviders),
                        _ProviderGroup(title: 'Rent', providers: d.rentProviders),
                        _ProviderGroup(title: 'Buy', providers: d.buyProviders),
                        if (d.providerTmdbUrl.isNotEmpty)
                          TextButton.icon(
                            onPressed: () => _open(d.providerTmdbUrl),
                            icon: const Icon(Icons.open_in_new_rounded, size: 16),
                            label: const Text('Open provider options'),
                          ),
                        const Text(
                          'Streaming availability data by JustWatch.',
                          style: TextStyle(color: Colors.white38, fontSize: 11),
                        ),
                      ],
                      if (d.recommendations.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        const _SectionTitle('You may also like'),
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 235,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: d.recommendations.length,
                            separatorBuilder: (_, _) => const SizedBox(width: 10),
                            itemBuilder: (_, index) {
                              final movie = d.recommendations[index];
                              return SizedBox(
                                width: 132,
                                child: _MovieCard(
                                  movie: movie,
                                  onTap: () => Navigator.of(context).pushReplacement(
                                    MaterialPageRoute(
                                      builder: (_) => MovieDetailsScreen(
                                        movieId: movie.id,
                                        repository: widget.repository,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      const _Attribution(),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  bool _hasProviders(MovieDetails d) {
    return d.streamingProviders.isNotEmpty ||
        d.freeProviders.isNotEmpty ||
        d.adSupportedProviders.isNotEmpty ||
        d.rentProviders.isNotEmpty ||
        d.buyProviders.isNotEmpty;
  }
}

class _Meta extends StatelessWidget {
  final String text;
  const _Meta({required this.text});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(text, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      );
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
      );
}

class _CastCard extends StatelessWidget {
  final MovieCast person;
  const _CastCard({required this.person});

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 82,
        child: Column(
          children: [
            CircleAvatar(
              radius: 34,
              backgroundColor: const Color(0xFF1A1F28),
              backgroundImage: person.profileUrl.isNotEmpty ? CachedNetworkImageProvider(person.profileUrl) : null,
              child: person.profileUrl.isEmpty
                  ? const Icon(Icons.person_rounded, color: Colors.white30)
                  : null,
            ),
            const SizedBox(height: 7),
            Text(
              person.name,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white70, fontSize: 10.5, height: 1.15),
            ),
          ],
        ),
      );
}

class _ProviderGroup extends StatelessWidget {
  final String title;
  final List<MovieProvider> providers;
  const _ProviderGroup({required this.title, required this.providers});

  @override
  Widget build(BuildContext context) {
    if (providers.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 74,
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(title, style: const TextStyle(color: Colors.white54, fontSize: 12)),
            ),
          ),
          Expanded(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: providers
                  .map(
                    (p) => Tooltip(
                      message: p.name,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(9),
                        child: p.logoUrl.isEmpty
                            ? Container(
                                width: 42,
                                height: 42,
                                alignment: Alignment.center,
                                color: const Color(0xFF1A1F28),
                                child: Text(p.name.isEmpty ? '?' : p.name.substring(0, 1)),
                              )
                            : CachedNetworkImage(
                                imageUrl: p.logoUrl,
                                width: 42,
                                height: 42,
                                fit: BoxFit.cover,
                              ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _Attribution extends StatelessWidget {
  const _Attribution();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.fromLTRB(18, 12, 18, 18),
        child: Text(
          'This product uses the TMDB API but is not endorsed or certified by TMDB.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white30, fontSize: 10.5, height: 1.35),
        ),
      );
}
