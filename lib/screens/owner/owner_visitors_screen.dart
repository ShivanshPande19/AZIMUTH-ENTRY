import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../models/visitor.dart';
import '../../services/visitor_service.dart';
import '../../theme.dart';
import '../../utils/format.dart';

/// Owner's view of the register, paged like an email inbox: one page of results
/// at a time with Previous / Next controls and a "Page N of M" indicator.
/// Within a page, visitors are grouped by the day they arrived.
///
/// Date filtering and search are applied server-side; the page count comes from
/// an exact row count, so navigation is accurate for large registers.
class OwnerVisitorsScreen extends StatefulWidget {
  const OwnerVisitorsScreen({super.key});

  @override
  State<OwnerVisitorsScreen> createState() => _OwnerVisitorsScreenState();
}

class _OwnerVisitorsScreenState extends State<OwnerVisitorsScreen> {
  static const int _pageSize = 25;

  final _service = VisitorService();
  final _searchCtrl = TextEditingController();
  final _scroll = ScrollController();
  Timer? _debounce;

  List<Visitor> _items = [];
  int _page = 0;
  int _total = 0;
  String _query = '';
  DateTime _filterDate = DateTime.now(); // the day being viewed (default: today)

  bool get _isToday => isSameDay(_filterDate, DateTime.now());

  bool _loading = true;
  Object? _error;

  int get _pageCount =>
      _total == 0 ? 1 : ((_total + _pageSize - 1) ~/ _pageSize);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scroll.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      // While searching, look across ALL dates; otherwise scope to the day.
      final searching = _query.trim().isNotEmpty;
      final res = await _service.listVisitorsPage(
        day: searching ? null : _filterDate,
        search: _query,
        page: _page,
        pageSize: _pageSize,
      );
      if (!mounted) return;
      setState(() {
        _items = res.items;
        _total = res.total;
        _loading = false;
      });
      if (_scroll.hasClients) _scroll.jumpTo(0);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  void _onSearchChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (!mounted) return;
      setState(() {
        _query = v;
        _page = 0;
      });
      _load();
    });
  }

  void _clearSearch() {
    _debounce?.cancel();
    _searchCtrl.clear();
    setState(() {
      _query = '';
      _page = 0;
    });
    _load();
  }

  void _goToPage(int p) {
    if (p < 0 || p >= _pageCount || p == _page) return;
    setState(() => _page = p);
    _load();
  }

  Future<void> _pickFilterDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _filterDate,
      firstDate: DateTime(now.year - 3),
      lastDate: now,
      helpText: 'Show visitors on',
    );
    if (picked != null && mounted) {
      setState(() {
        _filterDate = picked;
        _page = 0;
      });
      _load();
    }
  }

  void _goToday() {
    if (_isToday) return;
    setState(() {
      _filterDate = DateTime.now();
      _page = 0;
    });
    _load();
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
                  child:
                      Text(v.name, style: Theme.of(ctx).textTheme.titleLarge),
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

  /// Group the current page's visitors into per-day sections.
  List<_Row> _buildRows(List<Visitor> list) {
    final now = DateTime.now();
    final rows = <_Row>[];

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
            onChanged: _onSearchChanged,
            decoration: InputDecoration(
              hintText: 'Search name or company',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _searchCtrl.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear_rounded),
                      onPressed: _clearSearch,
                    ),
            ),
          ),
        ),
        // When searching we scan all dates, so the day selector is replaced
        // by a small hint; otherwise show the guard-style date bar.
        if (_query.trim().isEmpty)
          _DateFilterBar(
            date: _filterDate,
            isToday: _isToday,
            onPick: _pickFilterDate,
            onToday: _goToday,
          )
        else
          const _SearchScopeHint(),
        Expanded(child: _buildBody()),
        if (!_loading && _error == null && _total > 0) _buildPaginationBar(),
      ],
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return _ErrorView(message: '$_error', onRetry: _load);
    }
    if (_items.isEmpty) {
      return _EmptyView(
        searching: _query.trim().isNotEmpty,
        isToday: _isToday,
      );
    }
    final rows = _buildRows(_items);
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      itemCount: rows.length,
      itemBuilder: (context, i) {
        final row = rows[i];
        return switch (row) {
          _HeaderRow() => _DayHeader(
              label: row.label, count: row.count, isToday: row.isToday),
          _VisitorRow() => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child:
                  _OwnerVisitorTile(visitor: row.visitor, onReveal: _reveal),
            ),
        };
      },
    );
  }

  Widget _buildPaginationBar() {
    final scheme = Theme.of(context).colorScheme;
    final from = _page * _pageSize + 1;
    final to = (_page * _pageSize + _items.length);
    final canPrev = _page > 0;
    final canNext = _page < _pageCount - 1;

    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 6, 16, 12),
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: 0.5)),
          boxShadow: [
            BoxShadow(
              color: AppTheme.seed.withValues(alpha: 0.12),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            _PageArrow(
              icon: Icons.chevron_left_rounded,
              tooltip: 'Previous page',
              enabled: canPrev,
              onTap: () => _goToPage(_page - 1),
            ),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Page ${_page + 1} of $_pageCount',
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    '$from–$to of $_total',
                    style: Theme.of(context)
                        .textTheme
                        .labelSmall
                        ?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            _PageArrow(
              icon: Icons.chevron_right_rounded,
              tooltip: 'Next page',
              enabled: canNext,
              onTap: () => _goToPage(_page + 1),
            ),
          ],
        ),
      ),
    );
  }
}

/// Rounded, tonal arrow button for the pagination pill.
class _PageArrow extends StatelessWidget {
  const _PageArrow({
    required this.icon,
    required this.tooltip,
    required this.enabled,
    required this.onTap,
  });
  final IconData icon;
  final String tooltip;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: enabled
            ? scheme.primary.withValues(alpha: 0.12)
            : scheme.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: enabled ? onTap : null,
          child: SizedBox(
            width: 52,
            height: 44,
            child: Center(
              child: Icon(
                icon,
                color: enabled
                    ? scheme.primary
                    : scheme.onSurfaceVariant.withValues(alpha: 0.4),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---- Row model for the grouped list ---------------------------------------
sealed class _Row {
  const _Row();
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

// ---- Hint shown while searching (results span all dates) -------------------
class _SearchScopeHint extends StatelessWidget {
  const _SearchScopeHint();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        children: [
          Icon(Icons.travel_explore_rounded,
              size: 16, color: scheme.primary),
          const SizedBox(width: 8),
          Text(
            'Searching across all dates',
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

// ---- Date selector (matches the guard's working-date bar) ------------------
class _DateFilterBar extends StatelessWidget {
  const _DateFilterBar({
    required this.date,
    required this.isToday,
    required this.onPick,
    required this.onToday,
  });
  final DateTime date;
  final bool isToday;
  final VoidCallback onPick;
  final VoidCallback onToday;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = isToday ? scheme.onSurfaceVariant : scheme.primary;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Material(
                  color: isToday
                      ? scheme.surfaceContainerHighest.withValues(alpha: 0.5)
                      : scheme.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: onPick,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: accent.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(Icons.calendar_month_rounded,
                                size: 20, color: accent),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isToday ? 'Today' : 'Selected date',
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelSmall
                                      ?.copyWith(
                                          color: scheme.onSurfaceVariant),
                                ),
                                Text(
                                  relativeDayLabel(date),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        color: isToday
                                            ? scheme.onSurface
                                            : scheme.primary,
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
              if (!isToday) ...[
                const SizedBox(width: 8),
                FilledButton.tonalIcon(
                  onPressed: onToday,
                  icon: const Icon(Icons.today_rounded, size: 18),
                  label: const Text('Today'),
                ),
              ],
            ],
          ),
          if (!isToday)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded,
                      size: 15, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Viewing a previous date. Tap Today to return.',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ),
                ],
              ),
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
      padding: const EdgeInsets.fromLTRB(2, 14, 2, 10),
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
            child:
                Divider(color: scheme.outlineVariant.withValues(alpha: 0.6)),
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
  const _EmptyView({required this.searching, required this.isToday});
  final bool searching;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final IconData icon;
    final String message;
    if (searching) {
      icon = Icons.search_off_rounded;
      message = 'No matching visitors';
    } else if (isToday) {
      icon = Icons.people_outline_rounded;
      message = 'No visitors yet today';
    } else {
      icon = Icons.event_busy_rounded;
      message = 'No visitors on this date';
    }
    return ListView(
      children: [
        const SizedBox(height: 120),
        Center(child: Icon(icon, size: 64, color: scheme.onSurfaceVariant)),
        const SizedBox(height: 12),
        Center(
          child:
              Text(message, style: Theme.of(context).textTheme.titleMedium),
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
