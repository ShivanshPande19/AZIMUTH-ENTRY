import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/visitor.dart';
import '../../services/visitor_service.dart';
import '../../theme.dart';
import '../../utils/format.dart';

/// Owner's view of the full register, presented as a light dashboard:
/// a summary strip, a working-date selector, then visitors grouped by the day
/// they arrived (Today / Yesterday / dated sections).
///
/// The register is loaded a page at a time (infinite scroll) so it scales to
/// large numbers of visitors without fetching everything up front, and the
/// list renders lazily.
///
/// Phone numbers stay masked until the owner taps "Reveal", which fetches the
/// real number and records an audit entry on the server.
class OwnerVisitorsScreen extends StatefulWidget {
  const OwnerVisitorsScreen({super.key});

  @override
  State<OwnerVisitorsScreen> createState() => _OwnerVisitorsScreenState();
}

class _OwnerVisitorsScreenState extends State<OwnerVisitorsScreen> {
  static const int _pageSize = 30;

  final _service = VisitorService();
  final _searchCtrl = TextEditingController();
  final _scroll = ScrollController();

  final List<Visitor> _items = [];
  String _query = '';
  DateTime? _filterDate; // null = show all dates

  bool _initialLoading = true;
  bool _loadingMore = false;
  bool _hasMore = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _reload();
  }

  @override
  void dispose() {
    _scroll.removeListener(_onScroll);
    _scroll.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.position.pixels >=
        _scroll.position.maxScrollExtent - 320) {
      _loadMore();
    }
  }

  Future<void> _reload() async {
    setState(() {
      _initialLoading = true;
      _error = null;
      _items.clear();
      _hasMore = true;
    });
    await _loadPage(reset: true);
  }

  Future<void> _loadPage({bool reset = false}) async {
    try {
      final page = await _service.listVisitors(
        day: _filterDate,
        limit: _pageSize,
        offset: reset ? 0 : _items.length,
      );
      if (!mounted) return;
      setState(() {
        _items.addAll(page);
        _hasMore = page.length == _pageSize;
        _initialLoading = false;
        _loadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _initialLoading = false;
        _loadingMore = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore || _initialLoading) return;
    setState(() => _loadingMore = true);
    await _loadPage();
  }

  Future<void> _pickFilterDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _filterDate ?? now,
      firstDate: DateTime(now.year - 3),
      lastDate: now,
      helpText: 'Show visitors on',
    );
    if (picked != null && mounted) {
      setState(() => _filterDate = picked);
      _reload();
    }
  }

  void _clearFilterDate() {
    setState(() => _filterDate = null);
    _reload();
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

  /// Client-side search over the loaded items (date filtering is server-side).
  List<Visitor> _search(List<Visitor> all) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return all;
    return all
        .where((v) =>
            v.name.toLowerCase().contains(q) ||
            (v.company ?? '').toLowerCase().contains(q))
        .toList();
  }

  /// Flatten into an optional stats row + per-day sections + a trailing loader.
  List<_Row> _buildRows(List<Visitor> list, {required bool showStats}) {
    final now = DateTime.now();
    final rows = <_Row>[];

    if (showStats) {
      final todayCount = list.where((v) => isSameDay(v.entryTime, now)).length;
      final insideCount = list.where((v) => v.isInside).length;
      rows.add(_StatsRow(
        today: todayCount,
        inside: insideCount,
        total: list.length,
      ));
    }

    final counts = <DateTime, int>{};
    for (final v in list) {
      final d =
          DateTime(v.entryTime.year, v.entryTime.month, v.entryTime.day);
      counts[d] = (counts[d] ?? 0) + 1;
    }

    DateTime? current;
    for (final v in list) {
      final d =
          DateTime(v.entryTime.year, v.entryTime.month, v.entryTime.day);
      if (current == null || !isSameDay(current, d)) {
        current = d;
        rows.add(_HeaderRow(
          label: relativeDayLabel(d, now: now),
          count: counts[d]!,
          isToday: isSameDay(d, now),
        ));
      }
      rows.add(_VisitorRow(v));
    }

    if (_hasMore) rows.add(const _LoaderRow());
    return rows;
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
        _DateFilterBar(
          date: _filterDate,
          onPick: _pickFilterDate,
          onClear: _clearFilterDate,
        ),
        Expanded(child: _buildBody()),
      ],
    );
  }

  Widget _buildBody() {
    if (_initialLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _items.isEmpty) {
      return _ErrorView(message: '$_error', onRetry: _reload);
    }

    final list = _search(_items);
    final showStats = _filterDate == null && _query.trim().isEmpty;
    final rows = _buildRows(list, showStats: showStats);

    return RefreshIndicator(
      onRefresh: _reload,
      child: list.isEmpty
          ? _EmptyView(
              searching: _query.trim().isNotEmpty,
              dateFiltered: _filterDate != null,
            )
          : ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
              itemCount: rows.length,
              itemBuilder: (context, i) {
                final row = rows[i];
                return switch (row) {
                  _StatsRow() => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _StatsStrip(
                        today: row.today,
                        inside: row.inside,
                        total: row.total,
                      ),
                    ),
                  _HeaderRow() => _DayHeader(
                      label: row.label,
                      count: row.count,
                      isToday: row.isToday,
                    ),
                  _VisitorRow() => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _OwnerVisitorTile(
                          visitor: row.visitor, onReveal: _reveal),
                    ),
                  _LoaderRow() => const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Center(
                        child: SizedBox(
                          height: 24,
                          width: 24,
                          child: CircularProgressIndicator(strokeWidth: 2.4),
                        ),
                      ),
                    ),
                };
              },
            ),
    );
  }
}

// ---- Row model for the flattened, grouped list ----------------------------
sealed class _Row {
  const _Row();
}

class _StatsRow extends _Row {
  const _StatsRow(
      {required this.today, required this.inside, required this.total});
  final int today;
  final int inside;
  final int total;
}

class _HeaderRow extends _Row {
  const _HeaderRow(
      {required this.label, required this.count, required this.isToday});
  final String label;
  final int count;
  final bool isToday;
}

class _VisitorRow extends _Row {
  const _VisitorRow(this.visitor);
  final Visitor visitor;
}

class _LoaderRow extends _Row {
  const _LoaderRow();
}

// ---- Date selector (styled to match the guard's working-date bar) ----------
class _DateFilterBar extends StatelessWidget {
  const _DateFilterBar(
      {required this.date, required this.onPick, required this.onClear});
  final DateTime? date;
  final VoidCallback onPick;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final active = date != null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: Material(
              color: active
                  ? scheme.primary.withValues(alpha: 0.10)
                  : scheme.surfaceContainerHighest.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(14),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: onPick,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: (active
                                  ? scheme.primary
                                  : scheme.onSurfaceVariant)
                              .withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(Icons.calendar_month_rounded,
                            size: 20,
                            color: active
                                ? scheme.primary
                                : scheme.onSurfaceVariant),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Showing',
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(color: scheme.onSurfaceVariant),
                            ),
                            Text(
                              active ? relativeDayLabel(date!) : 'All dates',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: active
                                        ? scheme.primary
                                        : scheme.onSurface,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.expand_more_rounded,
                          color: scheme.onSurfaceVariant),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (active) ...[
            const SizedBox(width: 8),
            FilledButton.tonalIcon(
              onPressed: onClear,
              icon: const Icon(Icons.event_available_rounded, size: 18),
              label: const Text('All'),
            ),
          ],
        ],
      ),
    );
  }
}

// ---- Summary strip ---------------------------------------------------------
class _StatsStrip extends StatelessWidget {
  const _StatsStrip(
      {required this.today, required this.inside, required this.total});
  final int today;
  final int inside;
  final int total;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            icon: Icons.today_rounded,
            label: 'Today',
            value: '$today',
            color: scheme.primary,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            icon: Icons.meeting_room_rounded,
            label: 'Inside now',
            value: '$inside',
            color: const Color(0xFF10B981),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatCard(
            icon: Icons.groups_rounded,
            label: 'Total',
            value: '$total',
            color: scheme.tertiary,
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: scheme.outlineVariant.withValues(alpha: 0.7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: Theme.of(context)
                .textTheme
                .headlineSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

// ---- Day section header ----------------------------------------------------
class _DayHeader extends StatelessWidget {
  const _DayHeader(
      {required this.label, required this.count, required this.isToday});
  final String label;
  final int count;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = isToday ? scheme.primary : scheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 18, 2, 10),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Text(
            label,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: isToday ? scheme.primary : scheme.onSurface,
                ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                  color: accent, fontWeight: FontWeight.w700, fontSize: 12),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Divider(
                color: scheme.outlineVariant.withValues(alpha: 0.6)),
          ),
        ],
      ),
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
    final statusColor =
        inside ? const Color(0xFF10B981) : scheme.onSurfaceVariant;

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
                Text(formatClock(visitor.entryTime),
                    style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(width: 16),
                Icon(Icons.logout_rounded, size: 15, color: scheme.error),
                const SizedBox(width: 6),
                Text(formatClock(visitor.exitTime),
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                Icon(Icons.phone_outlined,
                    size: 18, color: scheme.onSurfaceVariant),
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
                      padding: const EdgeInsets.symmetric(horizontal: 18),
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
  const _EmptyView({required this.searching, this.dateFiltered = false});
  final bool searching;
  final bool dateFiltered;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final IconData icon;
    final String message;
    if (searching) {
      icon = Icons.search_off_rounded;
      message = 'No matching visitors';
    } else if (dateFiltered) {
      icon = Icons.event_busy_rounded;
      message = 'No visitors on this date';
    } else {
      icon = Icons.people_outline_rounded;
      message = 'No visitors yet';
    }
    return ListView(
      children: [
        const SizedBox(height: 120),
        Center(child: Icon(icon, size: 64, color: scheme.onSurfaceVariant)),
        const SizedBox(height: 12),
        Center(
          child: Text(message,
              style: Theme.of(context).textTheme.titleMedium),
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
        Center(
            child: Icon(Icons.error_outline_rounded,
                size: 56, color: scheme.error)),
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
