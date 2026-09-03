import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/visitor.dart';
import '../../services/visitor_service.dart';
import '../../theme.dart';
import '../../utils/format.dart';

/// Owner's view of the full register. Phone numbers stay masked until the owner
/// explicitly taps "Reveal", which fetches the real number and records an audit
/// entry on the server.
class OwnerVisitorsScreen extends StatefulWidget {
  const OwnerVisitorsScreen({super.key});

  @override
  State<OwnerVisitorsScreen> createState() => _OwnerVisitorsScreenState();
}

class _OwnerVisitorsScreenState extends State<OwnerVisitorsScreen> {
  final _service = VisitorService();
  final _searchCtrl = TextEditingController();

  late Future<List<Visitor>> _future;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _reload();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _reload() {
    setState(() {
      _future = _service.listVisitors();
    });
  }

  Future<void> _reveal(Visitor v) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final phone = await _service.revealPhone(v.id);
      if (!mounted) return;
      Navigator.of(context).pop(); // dismiss spinner
      _showPhoneSheet(v, phone);
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not reveal: $e')));
    }
  }

  void _showPhoneSheet(Visitor v, String phone) {
    final scheme = Theme.of(context).colorScheme;
    final hasPhone = phone.isNotEmpty;
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 4, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                _Avatar(
                    color: avatarColor(v.name, scheme),
                    text: initialsOf(v.name)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(v.name,
                      style: Theme.of(ctx).textTheme.titleLarge),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Icon(Icons.phone_rounded, color: scheme.primary),
                  const SizedBox(width: 14),
                  Expanded(
                    child: SelectableText(
                      hasPhone ? phone : 'No number on record',
                      style: Theme.of(ctx).textTheme.headlineSmall?.copyWith(
                            letterSpacing: 1,
                          ),
                    ),
                  ),
                  if (hasPhone)
                    IconButton.filledTonal(
                      tooltip: 'Copy',
                      icon: const Icon(Icons.copy_rounded, size: 20),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: phone));
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(content: Text('Number copied')),
                        );
                      },
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Icon(Icons.history_rounded,
                    size: 16, color: scheme.onSurfaceVariant),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'This view has been recorded in the audit log.',
                    style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<Visitor> _filter(List<Visitor> all) {
    if (_query.trim().isEmpty) return all;
    final q = _query.toLowerCase();
    return all
        .where((v) =>
            v.name.toLowerCase().contains(q) ||
            (v.company ?? '').toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: TextField(
            controller: _searchCtrl,
            onChanged: (v) => setState(() => _query = v),
            decoration: InputDecoration(
              hintText: 'Search name or company',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear_rounded),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() => _query = '');
                      },
                    ),
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
                      message: '${snapshot.error}', onRetry: _reload);
                }
                final list = _filter(snapshot.data ?? []);
                if (list.isEmpty) {
                  return _EmptyView(searching: _query.trim().isNotEmpty);
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, i) =>
                      _OwnerVisitorTile(visitor: list[i], onReveal: _reveal),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _OwnerVisitorTile extends StatelessWidget {
  const _OwnerVisitorTile({required this.visitor, required this.onReveal});

  final Visitor visitor;
  final void Function(Visitor) onReveal;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final hasPhone = visitor.phoneMasked.isNotEmpty;
    final inside = visitor.isInside;
    final statusColor = inside ? const Color(0xFF10B981) : scheme.onSurfaceVariant;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Avatar(
                    color: avatarColor(visitor.name, scheme),
                    text: initialsOf(visitor.name)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(visitor.name,
                          style: Theme.of(context).textTheme.titleMedium),
                      if (visitor.company != null) ...[
                        const SizedBox(height: 2),
                        Text(visitor.company!,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(color: scheme.onSurfaceVariant)),
                      ],
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(inside ? 'Inside' : 'Left',
                      style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 12)),
                ),
              ],
            ),
            if (visitor.purpose != null) ...[
              const SizedBox(height: 10),
              Text(visitor.purpose!,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant)),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.login_rounded, size: 15, color: scheme.primary),
                const SizedBox(width: 6),
                Text(formatTime(visitor.entryTime),
                    style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(width: 16),
                Icon(Icons.logout_rounded, size: 15, color: scheme.error),
                const SizedBox(width: 6),
                Text(formatTime(visitor.exitTime),
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                Icon(Icons.phone_outlined, size: 18, color: scheme.onSurfaceVariant),
                const SizedBox(width: 8),
                Text(
                  hasPhone ? visitor.phoneMasked : 'No number',
                  style: TextStyle(
                      letterSpacing: 1,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurfaceVariant),
                ),
                const Spacer(),
                if (hasPhone)
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 42),
                      padding:
                          const EdgeInsets.symmetric(horizontal: 18),
                    ),
                    onPressed: () => onReveal(visitor),
                    icon: const Icon(Icons.visibility_rounded, size: 18),
                    label: const Text('Reveal'),
                  ),
              ],
            ),
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
      child: Text(text,
          style: TextStyle(
              color: color, fontWeight: FontWeight.w700, fontSize: 16)),
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView({required this.searching});
  final bool searching;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      children: [
        const SizedBox(height: 120),
        Center(
          child: Icon(
            searching ? Icons.search_off_rounded : Icons.people_outline_rounded,
            size: 64,
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: Text(
            searching ? 'No matching visitors' : 'No visitors yet',
            style: Theme.of(context).textTheme.titleMedium,
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
        const SizedBox(height: 120),
        Center(child: Icon(Icons.error_outline_rounded, size: 56, color: scheme.error)),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(message, textAlign: TextAlign.center),
        ),
        const SizedBox(height: 20),
        Center(
          child: FilledButton.tonal(onPressed: onRetry, child: const Text('Retry')),
        ),
      ],
    );
  }
}
