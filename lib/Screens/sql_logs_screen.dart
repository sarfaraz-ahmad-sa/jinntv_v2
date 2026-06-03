import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_json_view/flutter_json_view.dart';

import '../db/db_helper.dart';

class SqlLogsScreen extends StatefulWidget {
  const SqlLogsScreen({Key? key}) : super(key: key);

  @override
  State<SqlLogsScreen> createState() => _SqlLogsScreenState();
}

class _SqlLogsScreenState extends State<SqlLogsScreen> {
  Database? db;

  List<String> tables = [];
  String? selectedTable;

  List<Map<String, dynamic>> records = [];
  List<Map<String, dynamic>> filtered = [];

  bool loading = true;
  String searchText = '';

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) initDb();
  }

  Future<void> initDb() async {
    db = await DBHelper.db;
    await _loadTables();
  }

  Future<void> _loadTables() async {
    setState(() => loading = true);

    try {
      final res = await db!.rawQuery('''
        SELECT name
        FROM sqlite_master
        WHERE type='table'
        ORDER BY name
      ''');

      final all = res
          .map((e) => (e['name'] ?? '').toString())
          .where((t) => t.isNotEmpty)
          .where((t) => !t.startsWith('sqlite_'))
          .where((t) => t != 'android_metadata')
          .toList();

      final initial = all.contains('logs')
          ? 'logs'
          : all.isNotEmpty
              ? all.first
              : null;

      setState(() {
        tables = all;
        selectedTable = initial;
      });

      if (initial != null) {
        await loadTable(initial);
      } else {
        setState(() {
          records = [];
          filtered = [];
          loading = false;
        });
      }
    } catch (e) {
      debugPrint('❌ Error loading tables: $e');
      setState(() {
        tables = [];
        selectedTable = null;
        records = [];
        filtered = [];
        loading = false;
      });
    }
  }

  Future<void> loadTable(String table) async {
    setState(() => loading = true);

    try {
      // ORDER BY DESC: prefer id if exists, else rowid
      final cols = await db!.rawQuery('PRAGMA table_info("$table")');
      final hasId = cols.any((c) => c['name'] == 'id');
      final orderBy = hasId ? 'id DESC' : 'rowid DESC';

      final result = await db!.rawQuery('SELECT * FROM "$table" ORDER BY $orderBy');
      records = result;
      filtered = _applySearch(records, searchText);
    } catch (e) {
      debugPrint('❌ Error loading $table: $e');
      records = [];
      filtered = [];
    }

    setState(() => loading = false);
  }

  List<Map<String, dynamic>> _applySearch(List<Map<String, dynamic>> input, String text) {
    final q = text.trim().toLowerCase();
    if (q.isEmpty) return input;

    return input.where((row) {
      return row.values.any((v) => v.toString().toLowerCase().contains(q));
    }).toList();
  }

  void search(String text) {
    setState(() {
      searchText = text;
      filtered = _applySearch(records, searchText);
    });
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String prettyJson(dynamic obj) => const JsonEncoder.withIndent('  ').convert(obj);

  Future<void> copyText(String text, String msg) async {
    await Clipboard.setData(ClipboardData(text: text));
    _toast(msg);
  }

  String toCsv(List<Map<String, dynamic>> rows) {
    if (rows.isEmpty) return '';

    final keys = <String>{};
    for (final r in rows) {
      keys.addAll(r.keys.map((e) => e.toString()));
    }
    final headers = keys.toList()..sort();

    String esc(dynamic v) {
      final s = (v ?? '').toString();
      final needsQuotes = s.contains(',') || s.contains('\n') || s.contains('"');
      final cleaned = s.replaceAll('"', '""');
      return needsQuotes ? '"$cleaned"' : cleaned;
    }

    final buffer = StringBuffer();
    buffer.writeln(headers.join(','));

    for (final row in rows) {
      buffer.writeln(headers.map((h) => esc(row[h])).join(','));
    }
    return buffer.toString().trimRight();
  }

  String rowToCsv(Map<String, dynamic> row) => toCsv([row]);

  Future<void> exportJson() async {
    if (selectedTable == null) return;

    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$selectedTable.json');
    await file.writeAsString(prettyJson(filtered));
    _toast('JSON saved: ${file.path}');
  }

  Future<void> exportCsv() async {
    if (selectedTable == null || filtered.isEmpty) return;

    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$selectedTable.csv');
    await file.writeAsString(toCsv(filtered));
    _toast('CSV saved: ${file.path}');
  }

  void openFullScreenJson(String title, Map<String, dynamic> row) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => JsonFullScreenView(title: title, data: row),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return const Scaffold(
        body: Center(child: Text('SQLite not supported on Web')),
      );
    }

    final theme = Theme.of(context);

    // ✅ macOS null-safety fix for flutter_json_view styles
    final baseStyle = (theme.textTheme.bodySmall ?? const TextStyle())
        .copyWith(fontFamily: 'monospace');
    final keyStyle = (theme.textTheme.bodySmall ?? const TextStyle())
        .copyWith(fontFamily: 'monospace', fontWeight: FontWeight.w600);

    return Scaffold(
      appBar: AppBar(
        title: const Text('SQL Logs'),
        actions: [
          IconButton(
            tooltip: 'Refresh tables',
            icon: const Icon(Icons.refresh),
            onPressed: _loadTables,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: DropdownButtonFormField<String>(
              value: selectedTable,
              items: tables
                  .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                  .toList(),
              onChanged: (v) async {
                if (v == null) return;
                setState(() => selectedTable = v);
                await loadTable(v);
              },
              decoration: const InputDecoration(labelText: 'Select Table'),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: TextField(
              onChanged: search,
              decoration: const InputDecoration(
                hintText: 'Search...',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(child: Text('Records: ${filtered.length}')),
                IconButton(
                  tooltip: 'Copy JSON (filtered)',
                  icon: const Icon(Icons.copy),
                  onPressed: filtered.isEmpty
                      ? null
                      : () => copyText(prettyJson(filtered), 'JSON copied'),
                ),
                IconButton(
                  tooltip: 'Copy CSV (filtered)',
                  icon: const Icon(Icons.table_view),
                  onPressed: filtered.isEmpty
                      ? null
                      : () => copyText(toCsv(filtered), 'CSV copied'),
                ),
                TextButton(onPressed: exportJson, child: const Text('Export JSON')),
                TextButton(onPressed: exportCsv, child: const Text('Export CSV')),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                    ? const Center(child: Text('No records'))
                    : ListView.builder(
                        itemCount: filtered.length,
                        itemBuilder: (_, i) {
                          final row = filtered[i];
                          return Card(
                            margin: const EdgeInsets.all(10),
                            child: Padding(
                              padding: const EdgeInsets.all(10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          'Row ${i + 1}',
                                          style: theme.textTheme.titleSmall,
                                        ),
                                      ),
                                      IconButton(
                                        tooltip: 'Copy row JSON',
                                        icon: const Icon(Icons.copy),
                                        onPressed: () => copyText(
                                          prettyJson(row),
                                          'Row JSON copied',
                                        ),
                                      ),
                                      IconButton(
                                        tooltip: 'Full screen',
                                        icon: const Icon(Icons.open_in_full),
                                        onPressed: () => openFullScreenJson(
                                          '${selectedTable ?? 'Row'} - ${i + 1}',
                                          row,
                                        ),
                                      ),
                                    ],
                                  ),
                                  JsonView.map(
                                    Map<String, dynamic>.from(row),
                                    theme: JsonViewTheme(
                                      backgroundColor: theme.cardColor,
                                      viewType: JsonViewType.collapsible,
                                      defaultTextStyle: baseStyle,
                                      keyStyle: keyStyle,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 6,
                                    children: row.keys.map((k) {
                                      return ActionChip(
                                        label: Text('Copy $k'),
                                        onPressed: () => copyText(
                                          '${row[k] ?? ''}',
                                          '$k copied',
                                        ),
                                      );
                                    }).toList(),
                                  ),
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
  }
}

class JsonFullScreenView extends StatefulWidget {
  final String title;
  final Map<String, dynamic> data;

  const JsonFullScreenView({
    Key? key,
    required this.title,
    required this.data,
  }) : super(key: key);

  @override
  State<JsonFullScreenView> createState() => _JsonFullScreenViewState();
}

class _JsonFullScreenViewState extends State<JsonFullScreenView> {
  String q = '';

  String prettyJson(dynamic obj) => const JsonEncoder.withIndent('  ').convert(obj);

  Future<void> copyText(String text, String msg) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String toCsv(List<Map<String, dynamic>> rows) {
    if (rows.isEmpty) return '';

    final keys = <String>{};
    for (final r in rows) {
      keys.addAll(r.keys.map((e) => e.toString()));
    }
    final headers = keys.toList()..sort();

    String esc(dynamic v) {
      final s = (v ?? '').toString();
      final needsQuotes = s.contains(',') || s.contains('\n') || s.contains('"');
      final cleaned = s.replaceAll('"', '""');
      return needsQuotes ? '"$cleaned"' : cleaned;
    }

    final buffer = StringBuffer();
    buffer.writeln(headers.join(','));
    for (final row in rows) {
      buffer.writeln(headers.map((h) => esc(row[h])).join(','));
    }
    return buffer.toString().trimRight();
  }

  String filterLines(String text, String query) {
    final qq = query.trim().toLowerCase();
    if (qq.isEmpty) return text;

    final lines = text.split('\n');
    final kept = lines.where((l) => l.toLowerCase().contains(qq)).toList();

    // If nothing matched, keep full text so user is not stuck with blank
    return kept.isEmpty ? text : kept.join('\n');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final full = prettyJson(widget.data);
    final shown = filterLines(full, q);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            tooltip: 'Copy JSON',
            icon: const Icon(Icons.copy),
            onPressed: () => copyText(full, 'JSON copied'),
          ),
          IconButton(
            tooltip: 'Copy CSV (single row)',
            icon: const Icon(Icons.table_view),
            onPressed: () => copyText(toCsv([widget.data]), 'CSV copied'),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              onChanged: (v) => setState(() => q = v),
              decoration: const InputDecoration(
                hintText: 'Search inside JSON...',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: theme.cardColor,
              child: SingleChildScrollView(
                child: SelectableText(
                  shown,
                  style: (theme.textTheme.bodySmall ?? const TextStyle())
                      .copyWith(fontFamily: 'monospace'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
