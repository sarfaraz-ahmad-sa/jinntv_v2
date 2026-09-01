import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/services/personalization_service.dart';
import '../../../core/services/user_library_service.dart';
import '../../player/data/playback_source_service.dart';
import '../../player/presentation/cinenexa_player_screen.dart';
import '../../../core/widgets/premium_media_card.dart';
import '../data/tv_repository.dart';
import '../data/tv_repository_factory.dart';
import '../domain/tv_show.dart';

class TvSeriesScreen extends StatefulWidget {
  final bool embedded;
  const TvSeriesScreen({super.key, this.embedded = false});

  @override
  State<TvSeriesScreen> createState() => _TvSeriesScreenState();
}

class _TvSeriesScreenState extends State<TvSeriesScreen>
    with AutomaticKeepAliveClientMixin {
  late final TvRepository _repo;
  final _searchController = TextEditingController();
  final _scroll = ScrollController();
  Timer? _debounce;

  final List<TvShow> _items = [];
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
    _repo = TvRepositoryFactory.create();
    _scroll.addListener(_onScroll);
    _load(reset: true);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _scroll.dispose();
    _repo.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scroll.hasClients || _loading || _loadingMore || _page >= _totalPages) return;
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 500) _loadMore();
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
          : await _repo.fetchShows(list: _list, page: 1);
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
        _error = 'TV shows could not be loaded. Check your TMDB configuration and internet connection.';
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _page >= _totalPages) return;
    setState(() => _loadingMore = true);
    try {
      final next = _page + 1;
      final result = _query.length >= 2
          ? await _repo.search(_query, page: next)
          : await _repo.fetchShows(list: _list, page: next);
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

  void _searchChanged(String value) {
    _debounce?.cancel();
    _query = value.trim();
    setState(() {});
    _debounce = Timer(const Duration(milliseconds: 430), () {
      if (!mounted) return;
      if (_query.isEmpty || _query.length >= 2) {
        if (_query.length >= 2) PersonalizationService.instance.saveSearch(_query);
        _load(reset: true);
      }
    });
  }

  void _selectList(String value) {
    if (_list == value && _query.isEmpty) return;
    _searchController.clear();
    _query = '';
    setState(() => _list = value);
    _load(reset: true);
  }

  void _open(TvShow show) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TvDetailsScreen(seriesId: show.id, repository: _repo),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final body = RefreshIndicator(
      onRefresh: () => _load(reset: true),
      child: CustomScrollView(
        controller: _scroll,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: _searchAndFilters()),
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
              child: Center(child: Text('No TV shows found', style: TextStyle(color: Colors.white54))),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
              sliver: SliverGrid(
                delegate: SliverChildBuilderDelegate(
                  (_, index) {
                    final show = _items[index];
                    return PremiumMediaCard(
                      title: show.name,
                      subtitle: show.year.isEmpty ? 'TV Series' : show.year,
                      imageUrl: show.posterUrl,
                      rating: show.rating,
                      onTap: () => _open(show),
                      width: double.infinity,
                      fillHeight: true,
                    );
                  },
                  childCount: _items.length,
                ),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 210,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 10,
                  childAspectRatio: .56,
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
          const SliverToBoxAdapter(child: _TvAttribution()),
          const SliverToBoxAdapter(child: SizedBox(height: 14)),
        ],
      ),
    );

    if (widget.embedded) return ColoredBox(color: const Color(0xFF08090C), child: body);
    return Scaffold(
      backgroundColor: const Color(0xFF08090C),
      appBar: AppBar(title: const Text('TV Series')),
      body: body,
    );
  }

  Widget _searchAndFilters() {
    const choices = <String, String>{
      'trending': 'Trending',
      'popular': 'Popular',
      'on-air': 'On The Air',
      'airing-today': 'Airing Today',
      'top-rated': 'Top Rated',
      'discover': 'All Series',
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            onChanged: _searchChanged,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Search TV series...',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _query.isNotEmpty
                  ? IconButton(
                      onPressed: () {
                        _searchController.clear();
                        _query = '';
                        setState(() {});
                        _load(reset: true);
                      },
                      icon: const Icon(Icons.close_rounded),
                    )
                  : null,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 42,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: choices.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, index) {
                final entry = choices.entries.elementAt(index);
                final selected = _query.isEmpty && _list == entry.key;
                return ChoiceChip(
                  selected: selected,
                  onSelected: (_) => _selectList(entry.key),
                  showCheckmark: false,
                  selectedColor: const Color(0xFFE50914),
                  backgroundColor: const Color(0xFF151922),
                  side: BorderSide.none,
                  label: Text(entry.value),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorState() => Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_off_rounded, color: Colors.white30, size: 50),
            const SizedBox(height: 14),
            Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
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

class TvDetailsScreen extends StatefulWidget {
  final int seriesId;
  final TvRepository repository;

  const TvDetailsScreen({
    super.key,
    required this.seriesId,
    required this.repository,
  });

  @override
  State<TvDetailsScreen> createState() => _TvDetailsScreenState();
}

class _TvDetailsScreenState extends State<TvDetailsScreen> {
  late Future<TvDetails> _future;
  bool _inList = false;
  int? _recordedId;

  @override
  void initState() {
    super.initState();
    _future = widget.repository.details(widget.seriesId);
    UserLibraryService.instance.containsTv(widget.seriesId).then((value) {
      if (mounted) setState(() => _inList = value);
    });
  }

  Future<void> _openUrl(String value) async {
    final uri = Uri.tryParse(value);
    if (uri != null) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _playSeries(TvShow show) async {
    final messenger = ScaffoldMessenger.of(context);
    final source = await PlaybackSourceService.instance.tv(
      show.id,
      title: show.name,
    );
    if (!mounted) return;
    if (source == null) {
      messenger.showSnackBar(
        SnackBar(content: Text('No CineNexa source configured yet (tv_${show.id}).')),
      );
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CineNexaPlayerScreen(source: source),
      ),
    );
  }

  Future<void> _playEpisode(
    int seasonNumber,
    TvEpisode episode,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final source = await PlaybackSourceService.instance.episode(
      widget.seriesId,
      seasonNumber,
      episode.episodeNumber,
      title: 'S$seasonNumber E${episode.episodeNumber} • ${episode.name}',
    );
    if (!mounted) return;
    if (source == null) {
      messenger.showSnackBar(
        SnackBar(content: Text('No CineNexa source configured yet (tv_${widget.seriesId}_s${seasonNumber}_e${episode.episodeNumber}).')),
      );
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CineNexaPlayerScreen(source: source),
      ),
    );
  }

  void _record(TvDetails details) {
    if (_recordedId == details.show.id) return;
    _recordedId = details.show.id;
    PersonalizationService.instance.recordTvView(
      details.show,
      genreIds: details.genres.map((g) => g.id).toList(),
    );
  }

  Future<void> _showSeason(TvSeasonSummary season) async {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF101218),
      builder: (sheetContext) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: .82,
        minChildSize: .45,
        maxChildSize: .95,
        builder: (_, controller) => FutureBuilder<TvSeasonDetails>(
          future: widget.repository.seasonDetails(widget.seriesId, season.seasonNumber),
          builder: (_, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!snapshot.hasData) {
              return const Center(child: Text('Season details could not be loaded'));
            }
            final details = snapshot.data!;
            return ListView(
              controller: controller,
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(height: 18),
                Text(details.name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
                if (details.overview.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(details.overview, style: const TextStyle(color: Colors.white60, height: 1.45)),
                ],
                const SizedBox(height: 18),
                ...details.episodes.map(
                  (episode) => _EpisodeTile(
                    episode: episode,
                    onPlay: () => _playEpisode(details.seasonNumber, episode),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFF08090C),
        body: FutureBuilder<TvDetails>(
          future: _future,
          builder: (_, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError || !snapshot.hasData) {
              return SafeArea(
                child: Column(
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back_rounded)),
                    ),
                    const Spacer(),
                    const Text('TV series details could not be loaded'),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => setState(() => _future = widget.repository.details(widget.seriesId)),
                      child: const Text('Retry'),
                    ),
                    const Spacer(),
                  ],
                ),
              );
            }

            final d = snapshot.data!;
            final show = d.show;
            _record(d);
            return CustomScrollView(
              slivers: [
                SliverAppBar(
                  pinned: true,
                  expandedHeight: 350,
                  flexibleSpace: FlexibleSpaceBar(
                    background: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (show.backdropUrl.isNotEmpty)
                          CachedNetworkImage(imageUrl: show.backdropUrl, fit: BoxFit.cover)
                        else
                          const ColoredBox(color: Color(0xFF151922)),
                        const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Color(0x22000000), Color(0x4408090C), Color(0xFF08090C)],
                              stops: [0, .58, 1],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 0, 18, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(show.name, style: const TextStyle(fontSize: 29, height: 1.05, fontWeight: FontWeight.w900, letterSpacing: -.5)),
                        if (d.tagline.isNotEmpty) ...[
                          const SizedBox(height: 7),
                          Text(d.tagline, style: const TextStyle(color: Colors.white54, fontStyle: FontStyle.italic)),
                        ],
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if (show.year.isNotEmpty) _TvMeta(show.year),
                            _TvMeta('★ ${show.rating.toStringAsFixed(1)}'),
                            if (d.numberOfSeasons > 0) _TvMeta('${d.numberOfSeasons} seasons'),
                            if (d.numberOfEpisodes > 0) _TvMeta('${d.numberOfEpisodes} episodes'),
                            ...d.genres.take(3).map((g) => _TvMeta(g.name)),
                          ],
                        ),
                        const SizedBox(height: 18),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black),
                            onPressed: () => _playSeries(show),
                            icon: const Icon(Icons.play_arrow_rounded),
                            label: const Text('Watch now'),
                          ),
                        ),
                        const SizedBox(height: 9),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              if (_inList) {
                                await UserLibraryService.instance.removeTv(show.id);
                              } else {
                                await UserLibraryService.instance.addTv(show);
                              }
                              if (mounted) setState(() => _inList = !_inList);
                            },
                            icon: Icon(_inList ? Icons.bookmark_rounded : Icons.bookmark_add_outlined),
                            label: Text(_inList ? 'Remove from My List' : 'Add to My List'),
                          ),
                        ),
                        if (show.overview.isNotEmpty) ...[
                          const SizedBox(height: 24),
                          const PremiumSectionHeader(title: 'Story'),
                          const SizedBox(height: 8),
                          Text(show.overview, style: const TextStyle(color: Colors.white70, height: 1.55)),
                        ],
                        if (d.networks.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Text('Network • ${d.networks.join(' • ')}', style: const TextStyle(color: Color(0x70FFFFFF), fontSize: 12)),
                        ],
                        if (d.seasons.isNotEmpty) ...[
                          const SizedBox(height: 26),
                          const PremiumSectionHeader(title: 'Seasons', subtitle: 'Tap a season to browse episodes'),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 178,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: d.seasons.length,
                              separatorBuilder: (_, _) => const SizedBox(width: 10),
                              itemBuilder: (_, index) {
                                final season = d.seasons[index];
                                return _SeasonCard(season: season, onTap: () => _showSeason(season));
                              },
                            ),
                          ),
                        ],
                        if (d.cast.isNotEmpty) ...[
                          const SizedBox(height: 26),
                          const PremiumSectionHeader(title: 'Cast'),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 128,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: d.cast.length,
                              separatorBuilder: (_, _) => const SizedBox(width: 12),
                              itemBuilder: (_, index) => _TvCastCard(person: d.cast[index]),
                            ),
                          ),
                        ],
                        if (_hasProviders(d)) ...[
                          const SizedBox(height: 26),
                          PremiumSectionHeader(title: 'Where to watch • ${d.providerRegion}'),
                          const SizedBox(height: 10),
                          _TvProviderGroup(title: 'Streaming', providers: d.streamingProviders),
                          _TvProviderGroup(title: 'Free', providers: d.freeProviders),
                          _TvProviderGroup(title: 'With ads', providers: d.adSupportedProviders),
                          _TvProviderGroup(title: 'Rent', providers: d.rentProviders),
                          _TvProviderGroup(title: 'Buy', providers: d.buyProviders),
                          if (d.providerTmdbUrl.isNotEmpty)
                            TextButton.icon(
                              onPressed: () => _openUrl(d.providerTmdbUrl),
                              icon: const Icon(Icons.open_in_new_rounded, size: 16),
                              label: const Text('Open provider options'),
                            ),
                          const Text('Streaming availability data by JustWatch.', style: TextStyle(color: Colors.white38, fontSize: 11)),
                        ],
                        if (d.recommendations.isNotEmpty) ...[
                          const SizedBox(height: 26),
                          const PremiumSectionHeader(title: 'More like this'),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 245,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: d.recommendations.length,
                              separatorBuilder: (_, _) => const SizedBox(width: 10),
                              itemBuilder: (_, index) {
                                final item = d.recommendations[index];
                                return PremiumMediaCard(
                                  title: item.name,
                                  subtitle: item.year.isEmpty ? 'TV Series' : item.year,
                                  imageUrl: item.posterUrl,
                                  rating: item.rating,
                                  onTap: () => Navigator.of(context).pushReplacement(
                                    MaterialPageRoute(builder: (_) => TvDetailsScreen(seriesId: item.id, repository: widget.repository)),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                        const _TvAttribution(),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      );

  bool _hasProviders(TvDetails d) =>
      d.streamingProviders.isNotEmpty ||
      d.freeProviders.isNotEmpty ||
      d.adSupportedProviders.isNotEmpty ||
      d.rentProviders.isNotEmpty ||
      d.buyProviders.isNotEmpty;
}

class _TvMeta extends StatelessWidget {
  final String value;
  const _TvMeta(this.value);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: .08), borderRadius: BorderRadius.circular(9)),
        child: Text(value, style: const TextStyle(color: Colors.white70, fontSize: 12)),
      );
}

class _SeasonCard extends StatelessWidget {
  final TvSeasonSummary season;
  final VoidCallback onTap;
  const _SeasonCard({required this.season, required this.onTap});

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 118,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    color: const Color(0xFF151922),
                    width: double.infinity,
                    child: season.posterUrl.isNotEmpty
                        ? CachedNetworkImage(imageUrl: season.posterUrl, fit: BoxFit.cover)
                        : const Icon(Icons.tv_rounded, color: Colors.white24),
                  ),
                ),
              ),
              const SizedBox(height: 7),
              Text(season.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
              Text('${season.episodeCount} episodes', style: const TextStyle(color: Colors.white38, fontSize: 10)),
            ],
          ),
        ),
      );
}

class _EpisodeTile extends StatelessWidget {
  final TvEpisode episode;
  final VoidCallback onPlay;
  const _EpisodeTile({required this.episode, required this.onPlay});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: onPlay,
              borderRadius: BorderRadius.circular(10),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: 116,
                      height: 66,
                      color: const Color(0xFF1A1D25),
                      child: episode.stillUrl.isEmpty
                          ? const SizedBox.shrink()
                          : CachedNetworkImage(imageUrl: episode.stillUrl, fit: BoxFit.cover),
                    ),
                  ),
                  Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(color: Color(0xCC000000), shape: BoxShape.circle),
                    child: const Icon(Icons.play_arrow_rounded, color: Colors.white),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('E${episode.episodeNumber} • ${episode.name}', maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (episode.runtimeMinutes > 0) Text('${episode.runtimeMinutes}m', style: const TextStyle(color: Color(0x70FFFFFF), fontSize: 10.5)),
                      if (episode.rating > 0) Text('  ★ ${episode.rating.toStringAsFixed(1)}', style: const TextStyle(color: Color(0x70FFFFFF), fontSize: 10.5)),
                    ],
                  ),
                  if (episode.overview.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(episode.overview, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Color(0x70FFFFFF), fontSize: 10.5, height: 1.25)),
                  ],
                ],
              ),
            ),
            IconButton(
              tooltip: 'Play in CineNexa',
              onPressed: onPlay,
              icon: const Icon(Icons.play_circle_fill_rounded),
            ),
          ],
        ),
      );
}

class _TvCastCard extends StatelessWidget {
  final TvCast person;
  const _TvCastCard({required this.person});

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 82,
        child: Column(
          children: [
            CircleAvatar(
              radius: 34,
              backgroundColor: const Color(0xFF1A1F28),
              backgroundImage: person.profileUrl.isNotEmpty ? CachedNetworkImageProvider(person.profileUrl) : null,
              child: person.profileUrl.isEmpty ? const Icon(Icons.person_rounded, color: Colors.white30) : null,
            ),
            const SizedBox(height: 7),
            Text(person.name, maxLines: 2, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white70, fontSize: 10.5)),
          ],
        ),
      );
}

class _TvProviderGroup extends StatelessWidget {
  final String title;
  final List<TvProvider> providers;
  const _TvProviderGroup({required this.title, required this.providers});

  @override
  Widget build(BuildContext context) {
    if (providers.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 74, child: Padding(padding: const EdgeInsets.only(top: 8), child: Text(title, style: const TextStyle(color: Colors.white54, fontSize: 12)))),
          Expanded(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: providers
                  .map((provider) => Tooltip(
                        message: provider.name,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(9),
                          child: provider.logoUrl.isEmpty
                              ? Container(width: 42, height: 42, color: const Color(0xFF1A1F28), alignment: Alignment.center, child: Text(provider.name.isEmpty ? '?' : provider.name.substring(0, 1)))
                              : CachedNetworkImage(imageUrl: provider.logoUrl, width: 42, height: 42, fit: BoxFit.cover),
                        ),
                      ))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _TvAttribution extends StatelessWidget {
  const _TvAttribution();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.fromLTRB(18, 12, 18, 18),
        child: Text(
          'TV and movie metadata powered by TMDB. CineNexa is not endorsed or certified by TMDB.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white30, fontSize: 10.5, height: 1.35),
        ),
      );
}
