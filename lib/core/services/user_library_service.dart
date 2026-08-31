import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/movies/domain/movie.dart';
import '../../features/tv/domain/tv_show.dart';
import 'personalization_service.dart';

class UserLibraryService {
  UserLibraryService._();
  static final instance = UserLibraryService._();

  static const _moviePrefix = 'cinenexa_watchlist_movies_v2';
  static const _legacyMoviePrefix = 'cinenexa_watchlist_v1';
  static const _tvPrefix = 'cinenexa_watchlist_tv_v2';
  final ValueNotifier<int> revision = ValueNotifier<int>(0);

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;
  String _key(String prefix) => '${prefix}_${_uid ?? 'guest'}';

  Future<List<Movie>> getWatchlist() async {
    final local = await _readMoviesLocal();
    final uid = _uid;
    if (uid == null) return local;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('watchlist')
          .orderBy('saved_at', descending: true)
          .limit(100)
          .get();
      final remote = snap.docs
          .map((d) => Movie.fromStored(d.data()))
          .where((m) => m.id > 0)
          .toList();
      await _writeMoviesLocal(remote);
      return remote;
    } catch (_) {
      return local;
    }
  }

  Future<List<TvShow>> getTvWatchlist() async {
    final local = await _readTvLocal();
    final uid = _uid;
    if (uid == null) return local;
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('watchlist_tv')
          .orderBy('saved_at', descending: true)
          .limit(100)
          .get();
      final remote = snap.docs
          .map((d) => TvShow.fromStored(d.data()))
          .where((show) => show.id > 0)
          .toList();
      await _writeTvLocal(remote);
      return remote;
    } catch (_) {
      return local;
    }
  }

  Future<bool> contains(int movieId) async {
    final list = await _readMoviesLocal();
    if (list.any((m) => m.id == movieId)) return true;
    final uid = _uid;
    if (uid == null) return false;
    try {
      return (await FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .collection('watchlist')
              .doc('$movieId')
              .get())
          .exists;
    } catch (_) {
      return false;
    }
  }

  Future<bool> containsTv(int seriesId) async {
    final list = await _readTvLocal();
    if (list.any((show) => show.id == seriesId)) return true;
    final uid = _uid;
    if (uid == null) return false;
    try {
      return (await FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .collection('watchlist_tv')
              .doc('$seriesId')
              .get())
          .exists;
    } catch (_) {
      return false;
    }
  }

  Future<void> add(Movie movie) async {
    final list = await _readMoviesLocal();
    list.removeWhere((m) => m.id == movie.id);
    list.insert(0, movie);
    await _writeMoviesLocal(list);
    await PersonalizationService.instance.registerMoviePreference(movie);
    revision.value++;

    final uid = _uid;
    if (uid == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('watchlist')
          .doc('${movie.id}')
          .set({...movie.toStoredJson(), 'saved_at': FieldValue.serverTimestamp()});
    } catch (_) {}
  }

  Future<void> addTv(TvShow show) async {
    final list = await _readTvLocal();
    list.removeWhere((e) => e.id == show.id);
    list.insert(0, show);
    await _writeTvLocal(list);
    await PersonalizationService.instance.registerTvPreference(show);
    revision.value++;

    final uid = _uid;
    if (uid == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('watchlist_tv')
          .doc('${show.id}')
          .set({...show.toStoredJson(), 'saved_at': FieldValue.serverTimestamp()});
    } catch (_) {}
  }

  Future<void> remove(int movieId) async {
    final list = await _readMoviesLocal();
    list.removeWhere((m) => m.id == movieId);
    await _writeMoviesLocal(list);
    revision.value++;
    final uid = _uid;
    if (uid == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('watchlist')
          .doc('$movieId')
          .delete();
    } catch (_) {}
  }

  Future<void> removeTv(int seriesId) async {
    final list = await _readTvLocal();
    list.removeWhere((show) => show.id == seriesId);
    await _writeTvLocal(list);
    revision.value++;
    final uid = _uid;
    if (uid == null) return;
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('watchlist_tv')
          .doc('$seriesId')
          .delete();
    } catch (_) {}
  }

  Future<void> saveFcmToken(String token, {required String platform}) async {
    final uid = _uid;
    if (uid == null || token.trim().isEmpty) return;
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'fcm_tokens': {platform: token},
        'last_seen_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  Future<void> saveProfileIfNeeded() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'email': user.email ?? '',
        'display_name': user.displayName ?? '',
        'photo_url': user.photoURL ?? '',
        'last_seen_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  Future<List<Movie>> _readMoviesLocal() async {
    final sp = await SharedPreferences.getInstance();
    var raw = sp.getString(_key(_moviePrefix));
    raw ??= sp.getString(_key(_legacyMoviePrefix));
    if (raw == null || raw.isEmpty) return <Movie>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <Movie>[];
      return decoded
          .whereType<Map>()
          .map((e) => Movie.fromStored(e.cast<String, dynamic>()))
          .where((m) => m.id > 0)
          .toList();
    } catch (_) {
      return <Movie>[];
    }
  }

  Future<List<TvShow>> _readTvLocal() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_key(_tvPrefix));
    if (raw == null || raw.isEmpty) return <TvShow>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <TvShow>[];
      return decoded
          .whereType<Map>()
          .map((e) => TvShow.fromStored(e.cast<String, dynamic>()))
          .where((show) => show.id > 0)
          .toList();
    } catch (_) {
      return <TvShow>[];
    }
  }

  Future<void> _writeMoviesLocal(List<Movie> movies) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(
      _key(_moviePrefix),
      jsonEncode(movies.take(100).map((m) => m.toStoredJson()).toList()),
    );
  }

  Future<void> _writeTvLocal(List<TvShow> shows) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(
      _key(_tvPrefix),
      jsonEncode(shows.take(100).map((show) => show.toStoredJson()).toList()),
    );
  }
}
