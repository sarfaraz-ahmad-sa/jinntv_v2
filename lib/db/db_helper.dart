// lib/db/db_helper.dart
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../Screens/home_models.dart';

class DBHelper {
  // Prevent double DB open
  static Future<Database>? _dbFuture;

  static Future<Database> get db {
    _dbFuture ??= _initDB();
    return _dbFuture!;
  }

  // ================= INIT DB =================
  static Future<Database> _initDB() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'JinnTV_db.db');

    print('📂 DB PATH: $path');

    return openDatabase(
      path,
      version: 5,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE session(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            email TEXT,
            userid TEXT,
            login_time TEXT
          )
        ''');

        await _createKvCache(db);
        await _createPlaylist(db);
        await _createWatchHistory(db);

        await db.execute('''
          CREATE TABLE logs(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            message TEXT,
            created_at TEXT
          )
        ''');

        await db.execute('''
          CREATE TABLE Categorylogs(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            message TEXT,
            created_at TEXT
          )
        ''');

        await db.execute('''
          CREATE TABLE users_signup(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_name TEXT,
            user_email TEXT UNIQUE,
            password TEXT,
            phone TEXT,
            join_date TEXT,
            created_at TEXT
          )
        ''');

        await db.execute('''
          CREATE TABLE users_logins (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            userid TEXT UNIQUE,
            user_login TEXT,
            user_pass TEXT,
            user_nicename TEXT,
            phoneno TEXT,
            user_email TEXT,
            user_url TEXT,
            user_registered TEXT,
            user_activation_key TEXT,
            user_status TEXT,
            display_name TEXT,
            user_role TEXT,
            status TEXT
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 3) {
          await _createKvCache(db);
        }
        if (oldVersion < 4) {
          await _createPlaylist(db);
        }
        if (oldVersion < 5) {
          await _createWatchHistory(db);
        }
      },
    );
  }

  static Future<void> _createKvCache(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS kv_cache(
        cache_key TEXT PRIMARY KEY,
        json TEXT,
        saved_at INTEGER,
        ttl_seconds INTEGER
      )
    ''');
  }

  static Future<void> _createPlaylist(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS playlist(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT NOT NULL,
        video_id TEXT NOT NULL,
        title TEXT,
        thumb TEXT,
        youtube_id TEXT,
        mp4_url TEXT,
        created_at INTEGER,
        UNIQUE(user_id, video_id)
      )
    ''');
  }

  // ─────────────────────────────────────────────────────────────────────────
  // WATCH HISTORY
  // ─────────────────────────────────────────────────────────────────────────

  static Future<void> _createWatchHistory(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS watch_history(
        id            INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id       TEXT NOT NULL,
        video_id      TEXT NOT NULL,
        title         TEXT,
        thumb_url     TEXT,
        youtube_id    TEXT,
        mp4_url       TEXT,
        position_ms   INTEGER DEFAULT 0,
        duration_ms   INTEGER DEFAULT 0,
        watched_at    INTEGER,
        is_completed  INTEGER DEFAULT 0,
        UNIQUE(user_id, video_id)
      )
    ''');
  }

  /// Save or update watch progress for a video.
  static Future<void> saveWatchProgress({
    required String userId,
    required String videoId,
    required String title,
    required String thumbUrl,
    String? youtubeId,
    String? mp4Url,
    required int positionMs,
    required int durationMs,
    bool isCompleted = false,
  }) async {
    final d = await db;
    await d.insert(
      'watch_history',
      {
        'user_id':      userId,
        'video_id':     videoId,
        'title':        title,
        'thumb_url':    thumbUrl,
        'youtube_id':   youtubeId ?? '',
        'mp4_url':      mp4Url ?? '',
        'position_ms':  positionMs,
        'duration_ms':  durationMs,
        'watched_at':   DateTime.now().millisecondsSinceEpoch,
        'is_completed': isCompleted ? 1 : 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Get recent incomplete watches (not completed, watched in last 30 days).
  static Future<List<Map<String, dynamic>>> getContinueWatching(
      String userId) async {
    final d = await db;
    final cutoff = DateTime.now()
        .subtract(const Duration(days: 30))
        .millisecondsSinceEpoch;
    return d.query(
      'watch_history',
      where: 'user_id = ? AND is_completed = 0 AND watched_at > ? AND position_ms > 5000',
      whereArgs: [userId, cutoff],
      orderBy: 'watched_at DESC',
      limit: 20,
    );
  }

  /// Get saved position for a specific video (returns 0 if not found).
  static Future<int> getSavedPosition(String userId, String videoId) async {
    final d = await db;
    final rows = await d.query(
      'watch_history',
      columns: ['position_ms', 'is_completed'],
      where: 'user_id = ? AND video_id = ?',
      whereArgs: [userId, videoId],
      limit: 1,
    );
    if (rows.isEmpty) return 0;
    if ((rows.first['is_completed'] as int? ?? 0) == 1) return 0;
    return rows.first['position_ms'] as int? ?? 0;
  }

  /// Remove a video from continue watching.
  static Future<void> removeFromWatchHistory(
      String userId, String videoId) async {
    final d = await db;
    await d.delete(
      'watch_history',
      where: 'user_id = ? AND video_id = ?',
      whereArgs: [userId, videoId],
    );
  }

  /// Clear all watch history for a user.
  static Future<void> clearWatchHistory(String userId) async {
    final d = await db;
    await d.delete('watch_history', where: 'user_id = ?', whereArgs: [userId]);
  }

  // ─────────────────────────────────────────────────────────────────────────

  /// current user id (userid preferred; fallback email; else 'guest')
  static Future<String> currentUserId() async {
    final s = await getSession();
    if (s == null) return 'guest';

    final uid = (s['userid'] ?? '').toString().trim();
    if (uid.isNotEmpty) return uid;

    final email = (s['email'] ?? '').toString().trim();
    if (email.isNotEmpty) return email;

    return 'guest';
  }

  static Future<bool> addToPlaylist({
    required String userId,
    required String videoId,
    required String title,
    required String thumb,
    String? youtubeId,
    String? mp4Url,
  }) async {
    final database = await db;
    final now = DateTime.now().millisecondsSinceEpoch;

    final res = await database.insert(
      'playlist',
      {
        'user_id': userId,
        'video_id': videoId,
        'title': title,
        'thumb': thumb,
        'youtube_id': youtubeId ?? '',
        'mp4_url': mp4Url ?? '',
        'created_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );

    return res > 0;
  }

  static Future<void> removeFromPlaylist({
    required String userId,
    required String videoId,
  }) async {
    final database = await db;
    await database.delete(
      'playlist',
      where: 'user_id = ? AND video_id = ?',
      whereArgs: [userId, videoId],
    );
  }

  static Future<bool> isInPlaylist({
    required String userId,
    required String videoId,
  }) async {
    final database = await db;
    final rows = await database.query(
      'playlist',
      columns: ['id'],
      where: 'user_id = ? AND video_id = ?',
      whereArgs: [userId, videoId],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  static Future<List<Map<String, dynamic>>> getPlaylist(String userId) async {
    final database = await db;
    return database.query(
      'playlist',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'created_at DESC',
    );
  }

  // ================= HOME BUNDLE CACHE (KV) =================
  static Future<void> setCachedBundle(
    String key,
    HomeBundle bundle, {
    required int ttlSeconds,
  }) async {
    final database = await db;
    final nowMs = DateTime.now().millisecondsSinceEpoch;

    await database.insert(
      'kv_cache',
      {
        'cache_key': key,
        'json': jsonEncode(bundle.toJson()),
        'saved_at': nowMs,
        'ttl_seconds': ttlSeconds,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<HomeBundle?> getCachedBundle(String key) async {
    final database = await db;

    final rows = await database.query(
      'kv_cache',
      where: 'cache_key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) return null;

    final row = rows.first;
    final jsonStr = (row['json'] ?? '').toString();
    if (jsonStr.trim().isEmpty) return null;

    final decoded = jsonDecode(jsonStr);
    if (decoded is! Map<String, dynamic>) return null;

    return HomeBundle.fromJson(decoded);
  }

  // ================= CATALOG CACHE (KV) =================
  static Future<void> setCachedCatalog(
    String key,
    CatalogResponse resp, {
    required int ttlSeconds,
  }) async {
    final database = await db;
    final nowMs = DateTime.now().millisecondsSinceEpoch;

    await database.insert(
      'kv_cache',
      {
        'cache_key': key,
        'json': jsonEncode(resp.toJson()),
        'saved_at': nowMs,
        'ttl_seconds': ttlSeconds,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<CatalogResponse?> getCachedCatalog(String key) async {
    final database = await db;

    final rows = await database.query(
      'kv_cache',
      where: 'cache_key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) return null;

    final jsonStr = (rows.first['json'] ?? '').toString();
    if (jsonStr.trim().isEmpty) return null;

    final decoded = jsonDecode(jsonStr);
    if (decoded is! Map<String, dynamic>) return null;

    return CatalogResponse.fromJson(decoded);
  }

  static Future<void> deleteCacheKey(String key) async {
    final database = await db;
    await database.delete(
      'kv_cache',
      where: 'cache_key = ?',
      whereArgs: [key],
    );
  }

  // ================= CLEAR APP CACHE =================
  static Future<void> clearAppCache() async {
    final database = await db;

    // Home / Category / Catalog JSON cache clear
    await database.delete('kv_cache');

    // Optional app logs clear
    await database.delete('logs');
    await database.delete('Categorylogs');
  }

  // ================= AUTO CACHE CLEANUP =================
  static Future<void> clearOldCacheAfter24Hours() async {
    final database = await db;

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final twentyFourHoursMs = 24 * 60 * 60 * 1000;
    final expireBefore = nowMs - twentyFourHoursMs;

    await database.delete(
      'kv_cache',
      where: 'saved_at < ?',
      whereArgs: [expireBefore],
    );
  }

  // ================= PASSWORD =================
  static String _hashPassword(String password) {
    return sha256.convert(utf8.encode(password)).toString();
  }

  // ================= User =================
  static Future<void> addUsers({
    required String userid,
    required String username,
    required String password,
    required String email,
    String phoneno = '',
    required String user_registered,
    required String displayName,
    required String userRole,
    required String status,
  }) async {
    final database = await db;

    await database.insert(
      'users_logins',
      {
        'userid': userid,
        'user_nicename': username,
        'user_pass': _hashPassword(password),
        'user_email': email,
        'phoneno': phoneno,
        'display_name': displayName,
        'user_registered': user_registered,
        'user_role': userRole,
        'status': status,
        'user_status': '0',
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // ================= SESSION =================
  static Future<void> saveSession({
    required String userid,
    required String email,
  }) async {
    final database = await db;

    await database.delete('session');

    await database.insert('session', {
      'userid': userid,
      'email': email,
      'login_time': DateTime.now().toIso8601String(),
    });
  }

  static Future<bool> isLoggedIn() async {
    final database = await db;
    final res = await database.query('session', limit: 1);
    return res.isNotEmpty;
  }

  static Future<void> logout() async {
    final database = await db;
    await database.delete('session');
  }

  static Future<String?> getActiveUserId() async {
    final database = await db;
    final res = await database.query('session', limit: 1);
    if (res.isEmpty) return null;

    final v = (res.first['userid'] ?? '').toString().trim();
    return v.isEmpty ? null : v;
  }

  // ================= users_signup =================
  static Future<void> addusers_signup({
    required String name,
    required String email,
    required String password,
    required String phone,
  }) async {
    final database = await db;
    await database.insert(
      'users_signup',
      {
        'user_name': name,
        'user_email': email,
        'password': _hashPassword(password),
        'phone': phone,
        'join_date': DateTime.now().toIso8601String(),
        'created_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  static Future<bool> validateUser(String email, String password) async {
    final database = await db;
    final res = await database.query(
      'users_signup',
      where: 'user_email = ? AND password = ?',
      whereArgs: [email, _hashPassword(password)],
      limit: 1,
    );
    return res.isNotEmpty;
  }

  static Future<Map<String, dynamic>?> fetchUser(String userId) async {
    final database = await db;

    try {
      final response = await http
          .post(
            Uri.parse('https://jinntv.com/php_scripts/data.php'),
            body: {
              'profile_get': '1',
              'user_id': userId,
            },
          )
          .timeout(const Duration(seconds: 12));

      await addLog(
        'Profile get API status: ${response.statusCode}, body: ${response.body}',
      );

      if (response.statusCode == 200) {
        final dynamic decoded = jsonDecode(response.body);

        if (decoded is Map &&
            decoded['success'] == true &&
            decoded['data'] is Map) {
          final data = Map<String, dynamic>.from(decoded['data']);

          final String apiUserId = (data['user_id'] ?? userId).toString().trim();
          final String name = (data['name'] ?? '').toString().trim();
          final String email = (data['email'] ?? '').toString().trim();
          final String phone = (data['phoneno'] ?? '').toString().trim();
          final String role = (data['role'] ?? 'customer').toString().trim();
          final String status = (data['status'] ?? 'active').toString().trim();
          final String registered =
              (data['user_registered'] ?? '').toString().trim();
          final String profileImage =
              (data['profile_image'] ?? '').toString().trim();

          final existingRows = await database.query(
            'users_logins',
            where: 'userid = ?',
            whereArgs: [apiUserId],
            limit: 1,
          );

          final Map<String, dynamic> existing =
              existingRows.isNotEmpty ? existingRows.first : <String, dynamic>{};

          await database.insert(
            'users_logins',
            {
              'userid': apiUserId,
              'user_login': email,
              'user_pass': (existing['user_pass'] ?? '').toString(),
              'user_nicename': email,
              'phoneno': phone,
              'user_email': email,
              'user_url': profileImage,
              'user_registered': registered,
              'user_activation_key':
                  (existing['user_activation_key'] ?? '').toString(),
              'user_status': (existing['user_status'] ?? '0').toString(),
              'display_name': name,
              'user_role': role,
              'status': status,
            },
            conflictAlgorithm: ConflictAlgorithm.replace,
          );

          await database.update(
            'session',
            {'email': email},
            where: 'userid = ?',
            whereArgs: [apiUserId],
          );

          return {
            "userid": apiUserId,
            "name": name,
            "email": email,
            "phoneno": phone,
            "role": role,
            "status": status,
            "user_registered": registered,
            "profile_image": profileImage,
          };
        }
      }
    } catch (e) {
      await addLog('Profile get API error: $e');
    }

    final rows = await database.query(
      'users_logins',
      where: 'userid = ?',
      whereArgs: [userId],
      limit: 1,
    );

    if (rows.isEmpty) return null;

    final r = rows.first;

    return {
      "userid": (r['userid'] ?? '').toString(),
      "name": (r['display_name'] ?? r['user_nicename'] ?? '').toString(),
      "email": (r['user_email'] ?? '').toString(),
      "phoneno": (r['phoneno'] ?? '').toString(),
      "role": (r['user_role'] ?? '').toString(),
      "status": (r['status'] ?? '').toString(),
      "user_registered": (r['user_registered'] ?? '').toString(),
      "profile_image": (r['user_url'] ?? '').toString(),
    };
  }

  static Future<void> updateUserProfile({
    required String userId,
    required String name,
    required String phone,
    required String email,
    File? imageFile,
  }) async {
    final database = await db;

    final uri = Uri.parse('https://jinntv.com/php_scripts/data.php');
    final request = http.MultipartRequest('POST', uri)
      ..fields['profile_update'] = '1'
      ..fields['user_id'] = userId
      ..fields['fullname'] = name
      ..fields['email'] = email
      ..fields['phoneno'] = phone;

    if (imageFile != null) {
      final ext = imageFile.path.split('.').last.toLowerCase();
      String mimeType = 'jpeg';
      if (ext == 'png') mimeType = 'png';
      if (ext == 'webp') mimeType = 'webp';

      request.files.add(
        await http.MultipartFile.fromPath(
          'profile_image',
          imageFile.path,
          contentType: MediaType('image', mimeType),
        ),
      );
    }

    final streamedResponse = await request.send().timeout(
          const Duration(seconds: 20),
        );

    final response = await http.Response.fromStream(streamedResponse);

    await addLog(
      'Profile update API status: ${response.statusCode}, body: ${response.body}',
    );

    if (response.statusCode != 200) {
      throw Exception('Server error: ${response.statusCode}');
    }

    dynamic decoded;
    try {
      decoded = jsonDecode(response.body);
    } catch (e) {
      throw Exception('Invalid server response: ${response.body}');
    }

    if (decoded is! Map || decoded['success'] != true) {
      throw Exception(decoded['message']?.toString() ?? 'Profile update failed');
    }

    final Map<String, dynamic> apiData =
        decoded['data'] is Map ? Map<String, dynamic>.from(decoded['data']) : {};

    final String finalName = (apiData['name'] ?? name).toString().trim();
    final String finalEmail = (apiData['email'] ?? email).toString().trim();
    final String finalPhone = (apiData['phoneno'] ?? phone).toString().trim();
    final String finalProfileImage =
        (apiData['profile_image'] ?? '').toString().trim();

    final loginRows = await database.query(
      'users_logins',
      where: 'userid = ?',
      whereArgs: [userId],
      limit: 1,
    );

    final Map<String, dynamic> existing =
        loginRows.isNotEmpty ? loginRows.first : <String, dynamic>{};

    String oldEmail = finalEmail;
    if (loginRows.isNotEmpty) {
      oldEmail = (loginRows.first['user_email'] ?? finalEmail).toString();
    }

    await database.insert(
      'users_logins',
      {
        'userid': userId,
        'user_login': finalEmail,
        'user_pass': (existing['user_pass'] ?? '').toString(),
        'user_nicename': finalEmail,
        'phoneno': finalPhone,
        'user_email': finalEmail,
        'user_url': finalProfileImage,
        'user_registered': (existing['user_registered'] ?? '').toString(),
        'user_activation_key':
            (existing['user_activation_key'] ?? '').toString(),
        'user_status': (existing['user_status'] ?? '0').toString(),
        'display_name': finalName,
        'user_role': (existing['user_role'] ?? 'customer').toString(),
        'status': (existing['status'] ?? 'active').toString(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    await database.update(
      'session',
      {'email': finalEmail},
      where: 'userid = ?',
      whereArgs: [userId],
    );

    final updated = await database.update(
      'users_signup',
      {
        'user_name': finalName,
        'user_email': finalEmail,
        'phone': finalPhone,
      },
      where: 'user_email = ?',
      whereArgs: [oldEmail],
    );

    if (updated == 0 && finalEmail.isNotEmpty) {
      await database.insert(
        'users_signup',
        {
          'user_name': finalName,
          'user_email': finalEmail,
          'password': '',
          'phone': finalPhone,
          'join_date': DateTime.now().toIso8601String(),
          'created_at': DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await addLog('Profile updated successfully on API and local DB');
  }

  static String? _youtubeApiKey;

  static Future<String?> getYoutubeApiKey() async {
    if (_youtubeApiKey != null) return _youtubeApiKey;

    final userId = await getActiveUserId();
    if (userId == null) return null;

    try {
      final res = await http.post(
        Uri.parse('https://jinntv.com/api_forApp/get_app_config.php'),
        body: {'user_id': userId},
      ).timeout(const Duration(seconds: 8));

      final decoded = jsonDecode(res.body);
      if (decoded is Map && decoded['ok'] == true) {
        _youtubeApiKey = decoded['data']['youtube_api_key']?.toString();
        return _youtubeApiKey;
      }
    } catch (_) {}

    return null;
  }

  // ================= LOGS =================
  static Future<void> addLog(String message) async {
    final database = await db;
    await database.insert('logs', {
      'message': message,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  static Future<void> categorylogs(String message) async {
    final database = await db;
    await database.insert('Categorylogs', {
      'message': message,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  static Future<List<Map<String, dynamic>>> fetchLogs({int limit = 200}) async {
    final database = await db;
    return database.query(
      'logs',
      orderBy: 'id DESC',
      limit: limit,
    );
  }

  static Future<Map<String, dynamic>?> getSession() async {
    final database = await db;
    final res = await database.query('session', limit: 1);
    if (res.isEmpty) return null;
    return res.first;
  }

  static Future<int?> getUserIdInt() async {
    final s = await getActiveUserId();
    if (s == null) return null;
    final v = s.trim();
    if (v.isEmpty) return null;
    return int.tryParse(v);
  }

  // ================= API LOGS (MERGE) =================
  static Future<void> addApiLog({
    required String endpoint,
    required int statusCode,
    Map<String, dynamic>? req,
    dynamic res,
  }) async {
    final payload = {
      "type": "api",
      "endpoint": endpoint,
      "statusCode": statusCode,
      "req": req,
      "res": res,
      "ts": DateTime.now().toIso8601String(),
    };

    await addLog(jsonEncode(payload));
  }
}