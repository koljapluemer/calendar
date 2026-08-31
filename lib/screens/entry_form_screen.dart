import 'package:flutter/material.dart';

import '../date_labels.dart';
import '../models/entry.dart';
import '../repository/entry_repository.dart';

/// Add/edit form for a single entry. When [entry] is null this is the "Add"
/// tab: saving writes a new file and clears the field so another entry can be
/// added right away. When [entry] is set, saving overwrites it and pops back.
class EntryFormScreen extends StatefulWidget {
  const EntryFormScreen({super.key, required this.repository, this.entry});

  final EntryRepository repository;
  final CalendarEntry? entry;

  @override
  State<EntryFormScreen> createState() => _EntryFormScreenState();
}

class _EntryFormScreenState extends State<EntryFormScreen> {
  late final _controller =
      TextEditingController(text: widget.entry?.content ?? '');
  late DateOnly _date = widget.entry?.date ?? DateOnly.today();
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date.toDateTime(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _date = DateOnly.fromDateTime(picked));
    }
  }

  Future<void> _save() async {
    final content = _controller.text.trim();
    if (content.isEmpty) return;

    setState(() => _saving = true);
    final entry = widget.entry;
    if (entry != null) {
      await widget.repository
          .updateEntry(entry, date: _date, content: content);
      if (mounted) Navigator.pop(context);
      return;
    }

    await widget.repository.addEntry(_date, content);
    if (!mounted) return;
    setState(() {
      _saving = false;
      _controller.clear();
      _date = DateOnly.today();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Entry added')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.entry != null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OutlinedButton.icon(
            onPressed: _saving ? null : _pickDate,
            icon: const Icon(Icons.calendar_today),
            label: Text(formatShortDate(_date)),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: TextField(
              controller: _controller,
              autofocus: isEdit,
              maxLines: null,
              expands: true,
              textAlignVertical: TextAlignVertical.top,
              style: Theme.of(context).textTheme.bodyLarge,
              decoration: const InputDecoration(
                hintText: 'What is happening…',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: IconButton.filled(
              onPressed: _saving ? null : _save,
              tooltip: isEdit ? 'Save' : 'Add',
              icon: Icon(isEdit ? Icons.check : Icons.add),
              style: IconButton.styleFrom(padding: const EdgeInsets.all(16)),
            ),
          ),
        ],
      ),
    );
  }
}
