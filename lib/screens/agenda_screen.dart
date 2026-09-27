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
                        entry.content.isEmpty ? '(empty entry)' : entry.content,
                        style: entry.done
                            ? TextStyle(
                                color: theme.colorScheme.outline,
                                decoration: TextDecoration.lineThrough,
                              )
                            : null,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined),
                    tooltip: 'Edit',
                    onPressed: () => _edit(entry),
                  ),
                  IconButton(
                    icon: Icon(
                      entry.done
                          ? Icons.check_circle
                          : Icons.check_circle_outline,
                    ),
                    tooltip: entry.done ? 'Mark not done' : 'Done',
                    onPressed: () =>
                        widget.repository.setEntryDone(entry, !entry.done),
                  ),
                  _HoldToDeleteButton(
                    onDelete: () => widget.repository.deleteEntry(entry),
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

class _HoldToDeleteButton extends StatefulWidget {
  const _HoldToDeleteButton({required this.onDelete});

  final Future<void> Function() onDelete;

  @override
  State<_HoldToDeleteButton> createState() => _HoldToDeleteButtonState();
}

class _HoldToDeleteButtonState extends State<_HoldToDeleteButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  )..addStatusListener(_onStatusChanged);
  bool _deleting = false;
  int? _pointer;
  Offset? _pressOrigin;

  void _onStatusChanged(AnimationStatus status) {
    if (status != AnimationStatus.completed || _deleting) return;
    _deleting = true;
    widget.onDelete();
  }

  void _start(PointerDownEvent event) {
    if (_deleting || _pointer != null) return;
    _pointer = event.pointer;
    _pressOrigin = event.position;
    _controller.forward(from: 0);
  }

  void _move(PointerMoveEvent event) {
    if (event.pointer != _pointer || _pressOrigin == null) return;
    if ((event.position - _pressOrigin!).distance > 18) _cancel(event.pointer);
  }

  void _cancel(int pointer) {
    if (pointer != _pointer) return;
    _pointer = null;
    _pressOrigin = null;
    if (!_deleting) _controller.reverse();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Tooltip(
      message: 'Hold to delete',
      child: Semantics(
        button: true,
        label: 'Hold to delete',
        child: Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: _start,
          onPointerMove: _move,
          onPointerUp: (event) => _cancel(event.pointer),
          onPointerCancel: (event) => _cancel(event.pointer),
          child: SizedBox.square(
            dimension: 48,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) => Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox.square(
                    dimension: 34,
                    child: CircularProgressIndicator(
                      value: _controller.value,
                      strokeWidth: 2,
                      color: colors.error,
                      backgroundColor: Colors.transparent,
                    ),
                  ),
                  Transform.scale(
                    scale: 1 + (_controller.value * .08),
                    child: Icon(
                      Icons.delete_outline,
                      color: Color.lerp(
                        colors.onSurfaceVariant,
                        colors.error,
                        _controller.value,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
