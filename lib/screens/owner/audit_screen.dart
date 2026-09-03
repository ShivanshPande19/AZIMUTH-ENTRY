import 'package:flutter/material.dart';

import '../../models/visitor.dart';
import '../../services/visitor_service.dart';
import '../../theme.dart';
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
    final scheme = Theme.of(context).colorScheme;
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
              Center(
                  child: Icon(Icons.error_outline_rounded,
                      size: 56, color: scheme.error)),
              const SizedBox(height: 12),
              Center(child: Text('${snapshot.error}')),
              const SizedBox(height: 20),
              Center(
                child: FilledButton.tonal(
                    onPressed: _reload, child: const Text('Retry')),
              ),
            ]);
          }
          final list = snapshot.data ?? [];
          if (list.isEmpty) {
            return ListView(children: [
              const SizedBox(height: 120),
              Center(
                child: Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: Icon(Icons.verified_user_rounded,
                      size: 46, color: scheme.primary.withValues(alpha: 0.7)),
                ),
              ),
              const SizedBox(height: 20),
              Center(
                child: Text('No phone numbers viewed yet',
                    style: Theme.of(context).textTheme.titleMedium),
              ),
              const SizedBox(height: 6),
              Center(
                child: Text(
                  'Every reveal will be logged here',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ),
            ]);
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            itemCount: list.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final e = list[i];
              final name = e.visitorName ?? 'Visitor';
              final aColor = avatarColor(name, scheme);
              return Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 12),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: aColor.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.visibility_rounded,
                            size: 20, color: aColor),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(name,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium),
                            const SizedBox(height: 2),
                            Text(
                              'Number revealed',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: scheme.onSurfaceVariant),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        formatTime(e.viewedAt),
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
