import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/entry.dart';

const _prefsFolderKey = 'data_folder';

/// Reads and JSON-decodes every `*.json` file in [folderPath]. Runs in a
/// background isolate via [compute] so scanning a large folder never blocks the
/// UI thread. Files that don't parse to a JSON object are skipped, never fatal.
///
/// Each result has `path` (the file's path) and `entry` (the decoded JSON
/// object) — plain maps/strings so the result crosses the isolate boundary
/// cleanly.
List<Map<String, dynamic>> parseFolderIsolate(String folderPath) {
  final dir = Directory(folderPath);
  final results = <Map<String, dynamic>>[];
  if (!dir.existsSync()) return results;

  for (final entity in dir.listSync()) {
    if (entity is! File || !entity.path.toLowerCase().endsWith('.json')) {
      continue;
    }
    try {
      final decoded = jsonDecode(entity.readAsStringSync());
      if (decoded is! Map) continue; // not an entry object — skip, don't fail
      results.add({
        'path': entity.path,
        'entry': Map<String, dynamic>.from(decoded),
      });
    } catch (_) {
      // Skip unreadable / unparseable files.
    }
  }
  return results;
}

class EntryRepository extends ChangeNotifier {
  String? folderPath;
  bool isLoading = false;
  String? loadError;

  List<CalendarEntry> _entries = [];
  final Random _random = Random();

  int get count => _entries.length;

  List<CalendarEntry> get entries => List.unmodifiable(_entries);

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    folderPath = prefs.getString(_prefsFolderKey);
    if (folderPath != null) await loadFromDisk();
  }

  Future<void> setFolder(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsFolderKey, path);
    folderPath = path;
    await loadFromDisk();
  }

  Future<void> loadFromDisk() async {
    if (folderPath == null) return;
    isLoading = true;
    loadError = null;
    notifyListeners();

    try {
      final parsed = await compute(parseFolderIsolate, folderPath!);
      _entries = [
        for (final entry in parsed)
          CalendarEntry.fromJson(
            File(entry['path'] as String),
            Map<String, dynamic>.from(entry['entry'] as Map),
          ),
      ];
    } catch (e) {
      loadError = e.toString();
      _entries = [];
    }

    isLoading = false;
    notifyListeners();
  }

  /// Every day that has at least one entry, plus today (always), each paired
  /// with its entries in content order. Days are sorted chronologically.
  List<MapEntry<DateOnly, List<CalendarEntry>>> entriesByDay() {
    final byDay = <DateOnly, List<CalendarEntry>>{};
    for (final e in _entries) {
      byDay.putIfAbsent(e.date, () => []).add(e);
    }
    byDay.putIfAbsent(DateOnly.today(), () => []);
    final days = byDay.keys.toList()..sort();
    return [
      for (final day in days)
        MapEntry(
          day,
          byDay[day]!..sort((a, b) => a.content.compareTo(b.content)),
        ),
    ];
  }

  Future<CalendarEntry> addEntry(DateOnly date, String content) async {
    final folder = folderPath;
    if (folder == null) {
      throw StateError('addEntry called with no data folder set');
    }
    final filename = '${date.toIso()}-${_randomHex(6)}.json';
    final entry = CalendarEntry(
      file: File(p.join(folder, filename)),
      date: date,
      content: content,
    );
    await entry.save();
    _entries.add(entry);
    notifyListeners();
    return entry;
  }

  Future<void> updateEntry(
    CalendarEntry entry, {
    required DateOnly date,
    required String content,
  }) async {
    entry.date = date;
    entry.content = content;
    await entry.save();
    notifyListeners();
  }

  Future<void> setEntryDone(CalendarEntry entry, bool done) async {
    entry.done = done;
    await entry.save();
    notifyListeners();
  }

  Future<void> deleteEntry(CalendarEntry entry) async {
    await entry.delete();
    _entries.remove(entry);
    notifyListeners();
  }

  String _randomHex(int length) {
    const chars = '0123456789abcdef';
    return List.generate(
      length,
      (_) => chars[_random.nextInt(chars.length)],
    ).join();
  }
}
