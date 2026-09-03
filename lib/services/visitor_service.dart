import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/visitor.dart';

/// All visitor data access goes through here.
///
/// Note that the guard-facing calls (add / list / mark exit) never touch the
/// real phone number. The number is written by `add_visitor` on the server and
/// can only be read back through `reveal_phone`, which the database restricts
/// to owners and audits on every call.
class VisitorService {
  final SupabaseClient _client = Supabase.instance.client;

  /// Register a new visitor. The real phone number is passed to the server-side
  /// RPC, which stores it in a locked table and keeps only a masked copy where
  /// the guard can see it.
  Future<void> addVisitor({
    required String name,
    required String phone,
    String? company,
    String? purpose,
  }) async {
    await _client.rpc('add_visitor', params: {
      'p_name': name,
      'p_phone': phone,
      'p_company': company,
      'p_purpose': purpose,
    });
  }

  /// List visitors, newest first. Contains only masked phone numbers.
  ///
  /// [day] optionally restricts results to entries whose entry_time falls on
  /// that calendar day (local time).
  Future<List<Visitor>> listVisitors({
    bool onlyInside = false,
    DateTime? day,
  }) async {
    var query = _client.from('visitors').select();
    if (onlyInside) {
      query = query.filter('exit_time', 'is', null);
    }
    if (day != null) {
      final start = DateTime(day.year, day.month, day.day);
      final end = start.add(const Duration(days: 1));
      query = query
          .gte('entry_time', start.toUtc().toIso8601String())
          .lt('entry_time', end.toUtc().toIso8601String());
    }
    final rows = await query.order('entry_time', ascending: false);
    return (rows as List)
        .map((r) => Visitor.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  Future<void> markExit(String visitorId) async {
    await _client.rpc('mark_exit', params: {'p_visitor_id': visitorId});
  }

  /// OWNER ONLY. Returns the full phone number and writes an audit row.
  /// Throws a PostgrestException if a guard ever calls it.
  Future<String> revealPhone(String visitorId) async {
    final result =
        await _client.rpc('reveal_phone', params: {'p_visitor_id': visitorId});
    return (result as String?) ?? '';
  }

  /// OWNER ONLY. The phone-reveal audit trail with visitor names joined in.
  Future<List<AuditEntry>> listAudit() async {
    final rows = await _client
        .from('phone_view_audit')
        .select('id, visitor_id, viewed_at, visitors(name)')
        .order('viewed_at', ascending: false)
        .limit(200);
    return (rows as List)
        .map((r) => AuditEntry.fromMap(r as Map<String, dynamic>))
        .toList();
  }
}
