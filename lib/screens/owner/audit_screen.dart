import 'package:flutter/material.dart';

import '../../models/visitor.dart';
import '../../services/visitor_service.dart';
import '../../utils/format.dart';

/// Owner-only log of every time a full phone number was revealed.
class AuditScreen extends StatefulWidget {
  const AuditScreen({super.key});

  @override
  State<AuditScreen> createState() => _AuditScreenState();
}

class _AuditScreenState extends State<AuditScreen> {
  final _service = VisitorService();
  late Future<List<AuditEntry>> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() {
      _future = _service.listAudit();
    });
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async => _reload(),
      child: FutureBuilder<List<AuditEntry>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return ListView(children: [
              const SizedBox(height: 120),
              const Icon(Icons.error_outline, size: 56),
              const SizedBox(height: 12),
              Center(child: Text('${snapshot.error}')),
              const SizedBox(height: 16),
              Center(
                child: FilledButton(
                    onPressed: _reload, child: const Text('Retry')),
              ),
            ]);
          }
          final list = snapshot.data ?? [];
          if (list.isEmpty) {
            return ListView(children: [
              const SizedBox(height: 140),
              Icon(Icons.verified_user_outlined,
                  size: 64, color: Theme.of(context).colorScheme.outline),
              const SizedBox(height: 12),
              const Center(child: Text('No phone numbers viewed yet')),
            ]);
          }
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: list.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final e = list[i];
              return ListTile(
                leading: const CircleAvatar(child: Icon(Icons.visibility)),
                title: Text(e.visitorName ?? 'Visitor'),
                subtitle: Text('Number viewed • ${formatTime(e.viewedAt)}'),
              );
            },
          );
        },
      ),
    );
  }
}
