import 'package:flutter/material.dart';

import '../repository/entry_repository.dart';
import 'agenda_screen.dart';
import 'entry_form_screen.dart';
import 'settings_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.repository});

  final EntryRepository repository;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      AgendaScreen(repository: widget.repository),
      EntryFormScreen(repository: widget.repository),
      SettingsScreen(repository: widget.repository),
    ];
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: (i) => setState(() => _index = i),
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.calendar_today),
                  label: 'Calendar',
                ),
                NavigationDestination(icon: Icon(Icons.add), label: 'Add'),
                NavigationDestination(
                  icon: Icon(Icons.settings),
                  label: 'Settings',
                ),
              ],
            ),
            Expanded(
              child: IndexedStack(index: _index, children: pages),
            ),
          ],
        ),
      ),
    );
  }
}
