import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import 'audit_screen.dart';
import 'owner_visitors_screen.dart';

/// Owner shell with two tabs: the full register and the phone-view audit log.
class OwnerHome extends StatefulWidget {
  const OwnerHome({super.key});

  @override
  State<OwnerHome> createState() => _OwnerHomeState();
}

class _OwnerHomeState extends State<OwnerHome> {
  int _index = 0;
  final _auth = AuthService();

  @override
  Widget build(BuildContext context) {
    final pages = const [OwnerVisitorsScreen(), AuditScreen()];
    return Scaffold(
      appBar: AppBar(
        title: Text(_index == 0 ? 'All Visitors' : 'Access Audit'),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: () => _auth.signOut(),
          ),
        ],
      ),
      body: pages[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.list_alt_outlined),
            selectedIcon: Icon(Icons.list_alt),
            label: 'Register',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: 'Audit',
          ),
        ],
      ),
    );
  }
}
