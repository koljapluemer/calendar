import 'dart:convert';
import 'dart:io';

/// A calendar date with no time component. Two [DateOnly] values are equal when
/// they fall on the same calendar day.
class DateOnly implements Comparable<DateOnly> {
  const DateOnly(this.year, this.month, this.day);

  factory DateOnly.fromDateTime(DateTime dt) =>
      DateOnly(dt.year, dt.month, dt.day);

  static DateOnly today() => DateOnly.fromDateTime(DateTime.now());

  /// Parses the `YYYY-MM-DD` at the start of [value] (the on-disk form, also a
  /// valid ISO 8601 date prefix). Returns null when it isn't a valid date.
  static DateOnly? tryParse(String value) {
    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(value.trim());
    if (match == null) return null;
    final y = int.parse(match.group(1)!);
    final m = int.parse(match.group(2)!);
    final d = int.parse(match.group(3)!);
    if (m < 1 || m > 12 || d < 1 || d > 31) return null;
    return DateOnly(y, m, d);
  }

  final int year;
  final int month;
  final int day;

  DateTime toDateTime() => DateTime(year, month, day);

  /// `YYYY-MM-DD` — the on-disk form.
  String toIso() =>
      '${year.toString().padLeft(4, '0')}-'
      '${month.toString().padLeft(2, '0')}-'
      '${day.toString().padLeft(2, '0')}';

  @override
  int compareTo(DateOnly other) => toDateTime().compareTo(other.toDateTime());

  @override
  bool operator ==(Object other) =>
      other is DateOnly &&
      other.year == year &&
      other.month == month &&
      other.day == day;

  @override
  int get hashCode => Object.hash(year, month, day);

  @override
  String toString() => toIso();
}

/// A single calendar entry, persisted as one `<name>.json` file directly inside
/// the data folder. The JSON object stores `date` (`YYYY-MM-DD`), `content`
/// (plain text, shown verbatim — no markdown, no time), and `done`.
class CalendarEntry {
  CalendarEntry({
    required this.file,
    required this.date,
    required this.content,
    this.done = false,
  });

  /// Builds an entry from the decoded JSON object of [file]. A missing or
  /// unparseable `date` falls back to today and a missing `content` to empty —
  /// an entry is never "invalid", it just has less in it.
  factory CalendarEntry.fromJson(File file, Map<String, dynamic> json) {
    final rawDate = json['date'];
    final date =
        (rawDate is String ? DateOnly.tryParse(rawDate) : null) ??
        DateOnly.today();
    return CalendarEntry(
      file: file,
      date: date,
      content: json['content'] is String ? json['content'] as String : '',
      done: json['done'] is bool ? json['done'] as bool : false,
    );
  }

  final File file;
  DateOnly date;
  String content;
  bool done;

  Map<String, dynamic> toJson() => {
    'date': date.toIso(),
    'content': content,
    'done': done,
  };

  static const JsonEncoder _encoder = JsonEncoder.withIndent('  ');

  /// Serialises the entry and writes it via a temp file + rename so a crash
  /// mid-write can't leave a half-written file behind.
  Future<void> save() async {
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(_encoder.convert(toJson()));
    await tmp.rename(file.path);
  }

  Future<void> delete() async {
    if (await file.exists()) await file.delete();
    final tmp = File('${file.path}.tmp');
    if (await tmp.exists()) await tmp.delete();
  }
}
