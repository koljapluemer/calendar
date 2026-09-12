import 'package:flutter/material.dart';

import '../date_labels.dart';
import '../models/entry.dart';
import '../repository/entry_repository.dart';
import 'entry_form_screen.dart';

/// First tab: entries grouped under their day, for a scrollable window of days
/// that defaults to today..end of next month and widens via the "Load
/// previous"/"Load next" buttons. Today's heading is always shown (even with
/// no entries); any other day appears only when it has one.
class AgendaScreen extends StatefulWidget {
  const AgendaScreen({super.key, required this.repository});

  final EntryRepository repository;

  @override
  State<AgendaScreen> createState() => _AgendaScreenState();
}

class _AgendaScreenState extends State<AgendaScreen> {
  /// Earliest and latest day currently shown, inclusive. Defaults to
  /// today..end of next month; "Load previous"/"Load next" widen this one
  /// month at a time.
  late DateOnly _rangeStart;
  late DateOnly _rangeEnd;

  @override
  void initState() {
    super.initState();
    widget.repository.addListener(_onChanged);
    final today = DateOnly.today();
    _rangeStart = today;
    _rangeEnd = _endOfMonth(_addMonths(today, 1));
  }

  @override
  void dispose() {
    widget.repository.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() => setState(() {});

  static DateOnly _startOfMonth(DateOnly d) => DateOnly(d.year, d.month, 1);

  static DateOnly _addMonths(DateOnly d, int delta) =>
      DateOnly.fromDateTime(DateTime(d.year, d.month + delta, 1));

  static DateOnly _endOfMonth(DateOnly d) =>
      DateOnly.fromDateTime(DateTime(d.year, d.month + 1, 0));

  /// First press widens the range to the start of its current month; each
  /// press after that goes back one further month.
  void _loadPrevious() {
    final monthStart = _startOfMonth(_rangeStart);
    setState(() {
      _rangeStart = _rangeStart == monthStart
          ? _addMonths(monthStart, -1)
          : monthStart;
    });
  }

  /// Widens the range to include the next not-yet-shown month.
  void _loadNext() {
    setState(() {
      _rangeEnd = _endOfMonth(_addMonths(_rangeEnd, 1));
    });
  }

  Future<void> _edit(CalendarEntry entry) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('Edit entry')),
          body: SafeArea(
            child: EntryFormScreen(repository: widget.repository, entry: entry),
          ),
        ),
      ),
    );
  }

  Future<void> _delete(CalendarEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete entry?'),
        content: Text(entry.content.isEmpty ? '(empty entry)' : entry.content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) await widget.repository.deleteEntry(entry);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final today = DateOnly.today();
    final days = widget.repository
        .entriesByDay()
        .where(
          (day) =>
              day.key.compareTo(_rangeStart) >= 0 &&
              day.key.compareTo(_rangeEnd) <= 0,
        )
        .toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        Center(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: OutlinedButton(
              onPressed: _loadPrevious,
              child: const Text('Load previous'),
            ),
          ),
        ),
        for (final day in days) ...[
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 4),
            child: Text(
              day.key == today
                  ? 'Today — ${formatDayHeading(day.key)}'
                  : formatDayHeading(day.key),
              style: theme.textTheme.titleMedium?.copyWith(
                color: day.key == today ? theme.colorScheme.primary : null,
                fontWeight: day.key == today ? FontWeight.bold : null,
              ),
            ),
          ),
          const Divider(height: 1),
          if (day.value.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'No entries',
                style: TextStyle(color: theme.colorScheme.outline),
              ),
            )
          else
            for (final entry in day.value)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        entry.content.isEmpty
                            ? '(empty entry)'
                            : entry.content,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    tooltip: 'Edit',
                    onPressed: () => _edit(entry),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    tooltip: 'Delete',
                    onPressed: () => _delete(entry),
                  ),
                ],
              ),
          const SizedBox(height: 16),
        ],
        Center(
          child: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: OutlinedButton(
              onPressed: _loadNext,
              child: const Text('Load next'),
            ),
          ),
        ),
      ],
    );
  }
}
