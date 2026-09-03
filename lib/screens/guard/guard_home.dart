import 'package:flutter/material.dart';

import '../../models/visitor.dart';
import '../../services/auth_service.dart';
import '../../services/visitor_service.dart';
import '../../theme.dart';
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
            icon: const Icon(Icons.logout_rounded),
            onPressed: () => _auth.signOut(),
          ),
          const SizedBox(width: 4),
        ],
      ),
      floatingActionButton: _NewEntryFab(onTap: _addVisitor),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(
                    value: true,
                    label: Text('Inside now'),
                    icon: Icon(Icons.meeting_room_rounded, size: 18),
                  ),
                  ButtonSegment(
                    value: false,
                    label: Text('All'),
                    icon: Icon(Icons.list_alt_rounded, size: 18),
                  ),
                ],
                selected: {_onlyInside},
                onSelectionChanged: (s) {
                  _onlyInside = s.first;
                  _reload();
                },
              ),
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
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                    itemCount: list.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
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

/// Modern gradient "New entry" action button — icon + short label, soft shadow
/// and an ink splash, sitting above the content.
class _NewEntryFab extends StatelessWidget {
  const _NewEntryFab({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: AppTheme.brandGradient(Theme.of(context).brightness),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.seed.withValues(alpha: 0.45),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: const Padding(
            padding: EdgeInsets.symmetric(horizontal: 22, vertical: 16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.person_add_alt_1_rounded, color: Colors.white),
                SizedBox(width: 10),
                Text(
                  'New entry',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        ),
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
    final aColor = avatarColor(visitor.name, scheme);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Avatar(color: aColor, text: initialsOf(visitor.name)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        visitor.name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      if (visitor.company != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          visitor.company!,
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ],
                  ),
                ),
                _StatusChip(inside: visitor.isInside),
              ],
            ),
            if (visitor.purpose != null) ...[
              const SizedBox(height: 10),
              Text(
                visitor.purpose!,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
            const SizedBox(height: 14),
            // ---- Meta chips -------------------------------------------------
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _MetaChip(
                  icon: Icons.phone_locked_outlined,
                  label: visitor.phoneMasked.isEmpty
                      ? 'No number'
                      : visitor.phoneMasked,
                  monospace: true,
                ),
                _MetaChip(
                  icon: Icons.login_rounded,
                  label: 'In ${formatTime(visitor.entryTime)}',
                  color: scheme.primary,
                ),
                if (!visitor.isInside)
                  _MetaChip(
                    icon: Icons.logout_rounded,
                    label: 'Out ${formatTime(visitor.exitTime)}',
                    color: scheme.error,
                  ),
                _MetaChip(
                  icon: Icons.schedule_rounded,
                  label: visitor.isInside
                      ? formatDuration(visitor.entryTime, null)
                      : formatDuration(visitor.entryTime, visitor.exitTime),
                ),
              ],
            ),
            if (visitor.isInside) ...[
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.tonalIcon(
                  onPressed: () => onExit(visitor),
                  icon: const Icon(Icons.logout_rounded, size: 18),
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

class _Avatar extends StatelessWidget {
  const _Avatar({required this.color, required this.text});
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 46,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 16,
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.icon,
    required this.label,
    this.color,
    this.monospace = false,
  });

  final IconData icon;
  final String label;
  final Color? color;
  final bool monospace;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final c = color ?? scheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: c),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: c,
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              letterSpacing: monospace ? 1 : 0,
            ),
          ),
        ],
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
    final color = inside ? const Color(0xFF10B981) : scheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            inside ? 'Inside' : 'Left',
            style: TextStyle(
                color: color, fontWeight: FontWeight.w700, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView({required this.onlyInside});
  final bool onlyInside;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      children: [
        const SizedBox(height: 100),
        Center(
          child: Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(28),
            ),
            child: Icon(Icons.inbox_rounded,
                size: 48, color: scheme.primary.withValues(alpha: 0.7)),
          ),
        ),
        const SizedBox(height: 20),
        Center(
          child: Text(
            onlyInside ? 'No visitors inside right now' : 'No entries yet',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        const SizedBox(height: 6),
        Center(
          child: Text(
            'Tap “New entry” to add a visitor',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ),
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
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      children: [
        const SizedBox(height: 100),
        Center(
          child: Icon(Icons.error_outline_rounded, size: 56, color: scheme.error),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(message, textAlign: TextAlign.center),
        ),
        const SizedBox(height: 20),
        Center(
          child: FilledButton.tonal(
              onPressed: onRetry, child: const Text('Retry')),
        ),
      ],
    );
  }
}
