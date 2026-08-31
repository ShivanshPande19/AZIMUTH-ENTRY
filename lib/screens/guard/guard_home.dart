import 'package:flutter/material.dart';

import '../../models/visitor.dart';
import '../../services/auth_service.dart';
import '../../services/visitor_service.dart';
import '../../utils/format.dart';
import 'add_visitor_screen.dart';

class GuardHome extends StatefulWidget {
  const GuardHome({super.key});

  @override
  State<GuardHome> createState() => _GuardHomeState();
}

class _GuardHomeState extends State<GuardHome> {
  final _service = VisitorService();
  final _auth = AuthService();

  bool _onlyInside = true;
  late Future<List<Visitor>> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() {
      _future = _service.listVisitors(onlyInside: _onlyInside);
    });
  }

  Future<void> _addVisitor() async {
    final added = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const AddVisitorScreen()),
    );
    if (added == true) _reload();
  }

  Future<void> _markExit(Visitor v) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Mark exit?'),
        content: Text('Record exit time for ${v.name}?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Mark exit')),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await _service.markExit(v.id);
      _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gate Register'),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            onPressed: () => _auth.signOut(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addVisitor,
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('New entry'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text('Inside now')),
                ButtonSegment(value: false, label: Text('All')),
              ],
              selected: {_onlyInside},
              onSelectionChanged: (s) {
                _onlyInside = s.first;
                _reload();
              },
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => _reload(),
              child: FutureBuilder<List<Visitor>>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return _ErrorView(
                      message: '${snapshot.error}',
                      onRetry: _reload,
                    );
                  }
                  final list = snapshot.data ?? [];
                  if (list.isEmpty) {
                    return _EmptyView(onlyInside: _onlyInside);
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
                    itemCount: list.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, i) =>
                        _VisitorTile(visitor: list[i], onExit: _markExit),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VisitorTile extends StatelessWidget {
  const _VisitorTile({required this.visitor, required this.onExit});

  final Visitor visitor;
  final void Function(Visitor) onExit;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    visitor.name,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                _StatusChip(inside: visitor.isInside),
              ],
            ),
            if (visitor.company != null) ...[
              const SizedBox(height: 2),
              Text(visitor.company!,
                  style: Theme.of(context).textTheme.bodyMedium),
            ],
            if (visitor.purpose != null) ...[
              const SizedBox(height: 2),
              Text(visitor.purpose!,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: scheme.outline)),
            ],
            const Divider(height: 20),
            Row(
              children: [
                Icon(Icons.phone_locked_outlined, size: 16, color: scheme.outline),
                const SizedBox(width: 6),
                Text(
                  visitor.phoneMasked.isEmpty ? 'No number' : visitor.phoneMasked,
                  style: TextStyle(
                    fontFeatures: const [],
                    letterSpacing: 1,
                    color: scheme.outline,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.login, size: 16, color: scheme.primary),
                const SizedBox(width: 6),
                Text('In: ${formatTime(visitor.entryTime)}'),
                const Spacer(),
                if (visitor.isInside)
                  Text(formatDuration(visitor.entryTime, null),
                      style: TextStyle(color: scheme.outline)),
              ],
            ),
            if (!visitor.isInside) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.logout, size: 16, color: scheme.error),
                  const SizedBox(width: 6),
                  Text('Out: ${formatTime(visitor.exitTime)}'),
                  const Spacer(),
                  Text(formatDuration(visitor.entryTime, visitor.exitTime),
                      style: TextStyle(color: scheme.outline)),
                ],
              ),
            ],
            if (visitor.isInside) ...[
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  onPressed: () => onExit(visitor),
                  icon: const Icon(Icons.logout, size: 18),
                  label: const Text('Mark exit'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.inside});
  final bool inside;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = inside ? Colors.green : scheme.outline;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        inside ? 'Inside' : 'Left',
        style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12),
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView({required this.onlyInside});
  final bool onlyInside;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const SizedBox(height: 120),
        Icon(Icons.inbox_outlined,
            size: 64, color: Theme.of(context).colorScheme.outline),
        const SizedBox(height: 12),
        Center(
          child: Text(
            onlyInside
                ? 'No visitors inside right now'
                : 'No entries yet',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        const SizedBox(height: 6),
        const Center(child: Text('Tap "New entry" to add a visitor')),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const SizedBox(height: 120),
        const Icon(Icons.error_outline, size: 56),
        const SizedBox(height: 12),
        Center(child: Text(message, textAlign: TextAlign.center)),
        const SizedBox(height: 16),
        Center(
          child: FilledButton(onPressed: onRetry, child: const Text('Retry')),
        ),
      ],
    );
  }
}
