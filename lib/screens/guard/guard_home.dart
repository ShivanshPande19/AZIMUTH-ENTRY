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
  DateTime _workingDate = DateTime.now();
  late Future<List<Visitor>> _future;

  bool get _isToday => isSameDay(_workingDate, DateTime.now());

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() {
      _future = _service.listVisitors(
        onlyInside: _onlyInside,
        day: _workingDate,
      );
    });
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _workingDate,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 1),
      helpText: 'Select working date',
    );
    if (picked != null && mounted) {
      _workingDate = picked;
      _reload();
    }
  }

  void _goToday() {
    _workingDate = DateTime.now();
    _reload();
  }

  Future<void> _addVisitor() async {
    // Blocker: entries may only be recorded for today. If the guard left the
    // working date on another day, warn instead of silently saving it wrong.
    if (!_isToday) {
      final switchToday = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          icon: Icon(Icons.event_busy_rounded,
              color: Theme.of(ctx).colorScheme.error, size: 32),
          title: const Text('Correct date not selected'),
          content: Text(
            'The working date is set to ${formatFullDay(_workingDate)}, '
            'not today (${formatFullDay(DateTime.now())}).\n\n'
            'New entries can only be recorded for today. Switch to today to '
            'continue.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Switch to today'),
            ),
          ],
        ),
      );
      if (switchToday != true) return;
      _goToday();
    }

    if (!mounted) return;
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
          WorkingDateBar(
            date: _workingDate,
            isToday: _isToday,
            onPick: _pickDate,
            onToday: _goToday,
          ),
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
                    return _EmptyView(onlyInside: _onlyInside, isToday: _isToday);
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

/// Working-date selector shown above the list. Tapping it opens a calendar;
/// when the date is not today a subtle "not today" hint + quick reset appear.
class WorkingDateBar extends StatelessWidget {
  const WorkingDateBar({
    super.key,
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Material(
                  color: isToday
                      ? scheme.surfaceContainerHighest.withValues(alpha: 0.5)
                      : scheme.errorContainer.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: onPick,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_month_rounded,
                              size: 20,
                              color: isToday
                                  ? scheme.primary
                                  : scheme.error),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isToday ? 'Today' : 'Working date',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelSmall
                                      ?.copyWith(
                                          color: scheme.onSurfaceVariant),
                                ),
                                Text(
                                  formatDay(date),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style:
                                      Theme.of(context).textTheme.titleMedium,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
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
                      size: 15, color: scheme.error),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Not today — new entries are blocked until you switch back.',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: scheme.error),
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

/// Modern, solid "New entry" action button — icon + short label, rounded with
/// a soft shadow and an ink splash.
class _NewEntryFab extends StatelessWidget {
  const _NewEntryFab({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.primary,
      borderRadius: BorderRadius.circular(18),
      elevation: 3,
      shadowColor: scheme.primary.withValues(alpha: 0.5),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.person_add_alt_1_rounded,
                  color: scheme.onPrimary, size: 22),
              const SizedBox(width: 10),
              Text(
                'New entry',
                style: TextStyle(
                  color: scheme.onPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  letterSpacing: 0.2,
                ),
              ),
            ],
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
  const _EmptyView({required this.onlyInside, required this.isToday});
  final bool onlyInside;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final title = !isToday
        ? 'No entries on this date'
        : (onlyInside ? 'No visitors inside right now' : 'No entries yet');
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
          child: Text(title, style: Theme.of(context).textTheme.titleMedium),
        ),
        const SizedBox(height: 6),
        Center(
          child: Text(
            isToday
                ? 'Tap “New entry” to add a visitor'
                : 'Switch to today to add a visitor',
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
