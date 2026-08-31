import 'package:cloud_firestore/cloud_firestore.dart';

import '../domain/playback_source.dart';

class PlaybackSourceService {
  PlaybackSourceService._();
  static final instance = PlaybackSourceService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<PlaybackSource?> movie(int movieId, {required String title}) {
    return _load('movie_$movieId', fallbackTitle: title);
  }

  Future<PlaybackSource?> tv(int seriesId, {required String title}) {
    return _load('tv_$seriesId', fallbackTitle: title);
  }

  Future<PlaybackSource?> episode(
    int seriesId,
    int seasonNumber,
    int episodeNumber, {
    required String title,
  }) {
    return _load(
      'tv_${seriesId}_s${seasonNumber}_e$episodeNumber',
      fallbackTitle: title,
    );
  }

  Future<PlaybackSource?> _load(
    String documentId, {
    required String fallbackTitle,
  }) async {
    try {
      final snapshot = await _firestore
          .collection('media_sources')
          .doc(documentId)
          .get()
          .timeout(const Duration(seconds: 10));

      final data = snapshot.data();
      if (!snapshot.exists || data == null || data['active'] == false) {
        return null;
      }

      final source = PlaybackSource.fromMap(
        documentId,
        data,
        fallbackTitle: fallbackTitle,
      );
      if (source.url.isEmpty) return null;
      final uri = Uri.tryParse(source.url);
      if (uri == null || !(uri.isScheme('https') || uri.isScheme('http'))) {
        return null;
      }
      return source;
    } catch (_) {
      return null;
    }
  }
}
