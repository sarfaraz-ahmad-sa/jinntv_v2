import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/movies/domain/movie.dart';
import '../../features/tv/domain/tv_show.dart';

class MediaHistoryItem {
  final String mediaType;
  final int id;
  final String title;
  final String year;
  final String posterUrl;
  final String backdropUrl;
  final double rating;
  final DateTime viewedAt;

  const MediaHistoryItem({
    required this.mediaType,
    required this.id,
    required this.title,
    required this.year,
    required this.posterUrl,
    required this.backdropUrl,
    required this.rating,
    required this.viewedAt,
  });

  bool get isMovie => mediaType == 'movie';
  bool get isTv => mediaType == 'tv';

  factory MediaHistoryItem.fromJson(Map<String, dynamic> json) => MediaHistoryItem(
        mediaType: (json['media_type'] ?? 'movie').toString(),
        id: int.tryParse('${json['id']}') ?? 0,
        title: (json['title'] ?? '').toString(),
        year: (json['year'] ?? '').toString(),
        posterUrl: (json['poster_url'] ?? '').toString(),
        backdropUrl: (json['backdrop_url'] ?? '').toString(),
        rating: double.tryParse('${json['rating']}') ?? 0,
        viewedAt: DateTime.tryParse((json['viewed_at'] ?? '').toString()) ?? DateTime.fromMillisecondsSinceEpoch(0),
      );

  Map<String, dynamic> toJson() => {
        'media_type': mediaType,
        'id': id,
        'title': title,
        'year': year,
        'poster_url': posterUrl,
        'backdrop_url': backdropUrl,
        'rating': rating,
        'viewed_at': viewedAt.toIso8601String(),
      };
}

class PersonalizationService {
  PersonalizationService._();
  static final instance = PersonalizationService._();

  static const _historyPrefix = 'cinenexa_history_v2';
  static const _searchPrefix = 'cinenexa_recent_searches_v2';
  static const _genrePrefix = 'cinenexa_genre_scores_v2';

  final ValueNotifier<int> revision = ValueNotifier<int>(0);

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;
  String _key(String prefix) => '${prefix}_${_uid ?? 'guest'}';

  Future<void> recordMovieView(Movie movie, {List<int> genreIds = const []}) async {
    await _recordView(
      MediaHistoryItem(
        mediaType: 'movie',
        id: movie.id,
        title: movie.title,
        year: movie.year,
        posterUrl: movie.posterUrl,
        backdropUrl: movie.backdropUrl,
        rating: movie.rating,
        viewedAt: DateTime.now(),
      ),
      genreIds: genreIds.isEmpty ? movie.genreIds : genreIds,
    );
  }

  Future<void> recordTvView(TvShow show, {List<int> genreIds = const []}) async {
    await _recordView(
      MediaHistoryItem(
        mediaType: 'tv',
        id: show.id,
        title: show.name,
        year: show.year,
        posterUrl: show.posterUrl,
        backdropUrl: show.backdropUrl,
        rating: show.rating,
        viewedAt: DateTime.now(),
      ),
      genreIds: genreIds.isEmpty ? show.genreIds : genreIds,
    );
  }

  Future<void> _recordView(MediaHistoryItem item, {required List<int> genreIds}) async {
    final sp = await SharedPreferences.getInstance();
    final items = await recentlyViewed();
    items.removeWhere((e) => e.mediaType == item.mediaType && e.id == item.id);
    items.insert(0, item);
    await sp.setString(
      _key(_historyPrefix),
      jsonEncode(items.take(60).map((e) => e.toJson()).toList()),
    );
    await _bumpGenres(item.mediaType, genreIds, weight: 2);
    revision.value++;

    final uid = _uid;
    if (uid == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('history')
          .doc('${item.mediaType}_${item.id}')
          .set({
        ...item.toJson(),
        'viewed_at': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  Future<List<MediaHistoryItem>> recentlyViewed({int limit = 30}) async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_key(_historyPrefix));
    if (raw == null || raw.isEmpty) return <MediaHistoryItem>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <MediaHistoryItem>[];
      return decoded
          .whereType<Map>()
          .map((e) => MediaHistoryItem.fromJson(e.cast<String, dynamic>()))
          .where((e) => e.id > 0 && e.title.isNotEmpty)
          .take(limit)
          .toList();
    } catch (_) {
      return <MediaHistoryItem>[];
    }
  }

  Future<void> clearHistory() async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_key(_historyPrefix));
    revision.value++;

    final uid = _uid;
    if (uid == null) return;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('history')
          .limit(100)
          .get();
      if (snap.docs.isEmpty) return;
      final batch = FirebaseFirestore.instance.batch();
      for (final doc in snap.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
    } catch (_) {}
  }

  Future<void> saveSearch(String query) async {
    final value = query.trim();
    if (value.length < 2) return;
    final sp = await SharedPreferences.getInstance();
    final current = await recentSearches();
    current.removeWhere((e) => e.toLowerCase() == value.toLowerCase());
    current.insert(0, value);
    await sp.setString(_key(_searchPrefix), jsonEncode(current.take(12).toList()));

  }

  Future<List<String>> recentSearches() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_key(_searchPrefix));
    if (raw == null || raw.isEmpty) return <String>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <String>[];
      return decoded.map((e) => '$e').where((e) => e.trim().isNotEmpty).take(12).toList();
    } catch (_) {
      return <String>[];
    }
  }

  Future<void> removeRecentSearch(String query) async {
    final sp = await SharedPreferences.getInstance();
    final current = await recentSearches();
    current.removeWhere((e) => e.toLowerCase() == query.toLowerCase());
    await sp.setString(_key(_searchPrefix), jsonEncode(current));
  }

  Future<void> registerMoviePreference(Movie movie, {List<int> genreIds = const []}) async {
    await _bumpGenres('movie', genreIds.isEmpty ? movie.genreIds : genreIds, weight: 3);
  }

  Future<void> registerTvPreference(TvShow show, {List<int> genreIds = const []}) async {
    await _bumpGenres('tv', genreIds.isEmpty ? show.genreIds : genreIds, weight: 3);
  }

  Future<List<int>> topMovieGenreIds({int limit = 3}) => _topGenreIds('movie', limit: limit);
  Future<List<int>> topTvGenreIds({int limit = 3}) => _topGenreIds('tv', limit: limit);

  Future<void> _bumpGenres(String mediaType, List<int> ids, {required int weight}) async {
    final clean = ids.where((id) => id > 0).toSet().toList();
    if (clean.isEmpty) return;
    final sp = await SharedPreferences.getInstance();
    final scores = _decodeGenreScores(sp.getString(_key(_genrePrefix)));
    final bucket = scores.putIfAbsent(mediaType, () => <String, int>{});
    for (final id in clean) {
      final key = '$id';
      bucket[key] = (bucket[key] ?? 0) + weight;
    }
    await sp.setString(_key(_genrePrefix), jsonEncode(scores));

    final uid = _uid;
    if (uid == null) return;
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'personalization': {
          'genre_scores': scores,
          'updated_at': FieldValue.serverTimestamp(),
        },
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  Future<List<int>> _topGenreIds(String mediaType, {required int limit}) async {
    final sp = await SharedPreferences.getInstance();
    final scores = _decodeGenreScores(sp.getString(_key(_genrePrefix)));
    final bucket = scores[mediaType] ?? const <String, int>{};
    final entries = bucket.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return entries
        .take(limit)
        .map((e) => int.tryParse(e.key) ?? 0)
        .where((id) => id > 0)
        .toList();
  }

  Map<String, Map<String, int>> _decodeGenreScores(String? raw) {
    if (raw == null || raw.isEmpty) return <String, Map<String, int>>{};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return <String, Map<String, int>>{};
      final output = <String, Map<String, int>>{};
      for (final entry in decoded.entries) {
        if (entry.value is! Map) continue;
        output['${entry.key}'] = (entry.value as Map).map(
          (key, value) => MapEntry('$key', int.tryParse('$value') ?? 0),
        );
      }
      return output;
    } catch (_) {
      return <String, Map<String, int>>{};
    }
  }
}
