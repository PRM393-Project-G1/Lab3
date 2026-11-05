import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../widgets/app_bottom_nav.dart';

/// Hosts the bottom navigation. Child screens keep the tab they were opened from.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.location, required this.child});

  final String location;
  final Widget child;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  static const _tabs = ['/analyze', '/history', '/profile'];

  int _selected = 0;

  @override
  Widget build(BuildContext context) {
    final index = _tabs.indexWhere(widget.location.startsWith);
    if (index >= 0) _selected = index;
    return Scaffold(
      body: widget.child,
      bottomNavigationBar: AppBottomNav(
        selectedIndex: _selected,
        onSelected: (tab) => context.go(_tabs[tab]),
      ),
    );
  }
}
