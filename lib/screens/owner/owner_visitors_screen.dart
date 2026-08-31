import 'package:flutter/material.dart';

import '../../models/visitor.dart';
import '../../services/visitor_service.dart';
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
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(v.name),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SelectableText(
                phone.isEmpty ? 'No number on record' : phone,
                style: Theme.of(ctx).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                'This view was recorded in the audit log.',
                style: Theme.of(ctx).textTheme.bodySmall,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Could not reveal: $e')));
    }
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
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: TextField(
            controller: _searchCtrl,
            onChanged: (v) => setState(() => _query = v),
            decoration: InputDecoration(
              hintText: 'Search name or company',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear),
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
                final list = _filter(snapshot.data ?? []);
                if (list.isEmpty) {
                  return const Center(child: Text('No matching visitors'));
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
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
                Text(
                  visitor.isInside ? 'Inside' : 'Left',
                  style: TextStyle(
                    color: visitor.isInside ? Colors.green : scheme.outline,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            if (visitor.company != null)
              Text(visitor.company!,
                  style: Theme.of(context).textTheme.bodyMedium),
            if (visitor.purpose != null)
              Text(visitor.purpose!,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: scheme.outline)),
            const SizedBox(height: 8),
            Text('In:  ${formatTime(visitor.entryTime)}',
                style: Theme.of(context).textTheme.bodySmall),
            Text('Out: ${formatTime(visitor.exitTime)}',
                style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.phone_outlined, size: 18, color: scheme.outline),
                const SizedBox(width: 8),
                Text(
                  hasPhone ? visitor.phoneMasked : 'No number',
                  style: TextStyle(letterSpacing: 1, color: scheme.outline),
                ),
                const Spacer(),
                if (hasPhone)
                  FilledButton.tonalIcon(
                    onPressed: () => onReveal(visitor),
                    icon: const Icon(Icons.visibility, size: 18),
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
