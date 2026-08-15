import 'package:flutter/material.dart';

import 'circle/my_circle_screen.dart';
import 'connections/connections_screen.dart';
import 'discover/discover_screen.dart';
import 'messages/messages_screen.dart';
import 'profile/self_profile_screen.dart';
import 'safety/safety_center_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;
  late final List<Widget?> _pages;

  static const _titles = [
    'Discover',
    'Connections',
    'Circle',
    'Messages',
    'Profile',
  ];

  @override
  void initState() {
    super.initState();
    _pages = List<Widget?>.filled(_titles.length, null, growable: false);
    _pages[0] = const DiscoverScreen();
  }

  Widget _buildPage(int index) {
    return switch (index) {
      0 => const DiscoverScreen(),
      1 => const ConnectionsScreen(),
      2 => const MyCircleScreen(),
      3 => const MessagesScreen(),
      4 => const SelfProfileScreen(),
      _ => const SizedBox.shrink(),
    };
  }

  bool _refreshOnEntry(int index) =>
      index == 1 || index == 2 || index == 3 || index == 4;

  void _selectTab(int value) {
    if (value == _index) {
      if (_refreshOnEntry(value)) {
        setState(() => _pages[value] = _buildPage(value));
      }
      return;
    }

    setState(() {
      _index = value;

      // Connections and Messages reflect security-sensitive relationship state.
      // Rebuild them whenever the user enters the tab so an ended/blocked
      // connection cannot remain visible from an IndexedStack cache after the
      // trusted backend has already revoked access.
      if (_refreshOnEntry(value)) {
        _pages[value] = _buildPage(value);
      } else {
        _pages[value] ??= _buildPage(value);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _index == 2
          ? null
          : AppBar(
              title: Text(_titles[_index]),
              actions: [
                IconButton(
                  tooltip: 'Safety center',
                  icon: const Icon(Icons.shield_outlined),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const SafetyCenterScreen(),
                    ),
                  ),
                ),
              ],
            ),
      body: IndexedStack(
        index: _index,
        children: List<Widget>.generate(
          _pages.length,
          (index) => _pages[index] ?? const SizedBox.shrink(),
          growable: false,
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _selectTab,
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.explore_outlined),
              selectedIcon: Icon(Icons.explore),
              label: 'Discover'),
          NavigationDestination(
              icon: Icon(Icons.people_alt_outlined),
              selectedIcon: Icon(Icons.people_alt),
              label: 'Connections'),
          NavigationDestination(
              icon: Icon(Icons.hub_outlined),
              selectedIcon: Icon(Icons.hub),
              label: 'Circle'),
          NavigationDestination(
              icon: Icon(Icons.chat_bubble_outline),
              selectedIcon: Icon(Icons.chat_bubble),
              label: 'Messages'),
          NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Profile'),
        ],
      ),
    );
  }
}
