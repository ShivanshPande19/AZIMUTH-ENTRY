import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import 'owner_visitors_screen.dart';

/// Owner shell: the full visitor register with a summary and date filtering.
class OwnerHome extends StatelessWidget {
  const OwnerHome({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = AuthService();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Visitors'),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout_rounded),
            onPressed: () => auth.signOut(),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: const OwnerVisitorsScreen(),
    );
  }
}
