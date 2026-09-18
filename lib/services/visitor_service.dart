import 'dart:math';
import 'dart:typed_data';

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

  /// Public Storage bucket that holds visitor photos.
  static const String photoBucket = 'visitor-photos';

  /// Register a new visitor. The real phone number is passed to the server-side
  /// RPC, which stores it in a locked table and keeps only a masked copy where
  /// the guard can see it. [photoPath] is the Storage object key returned by
  /// [uploadVisitorPhoto] (null when no photo was taken).
  Future<void> addVisitor({
    required String name,
    required String phone,
    String? company,
    String? purpose,
    String? photoPath,
  }) async {
    await _client.rpc('add_visitor', params: {
      'p_name': name,
      'p_phone': phone,
      'p_company': company,
      'p_purpose': purpose,
      'p_photo_path': photoPath,
    });
  }

  /// Upload an already-compressed JPEG for a visitor photo and return the
  /// Storage object key (e.g. `1699999999999-ab12.jpg`).
  ///
  /// The bytes are expected to be small (the picker downsizes/compresses before
  /// this is called), so the upload stays light even on slow connections.
  Future<String> uploadVisitorPhoto(Uint8List bytes) async {
    final path = '${_randomName()}.jpg';
    await _client.storage.from(photoBucket).uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(
            contentType: 'image/jpeg',
            upsert: true,
          ),
        );
    return path;
  }

  /// Build the public URL for a stored visitor photo, or null if [path] is
  /// empty. The bucket is public so this needs no network round-trip.
  String? photoUrl(String? path) {
    if (path == null || path.isEmpty) return null;
    return _client.storage.from(photoBucket).getPublicUrl(path);
  }

  /// Unguessable, lowercase alphanumeric object name (the bucket is public, so
  /// filenames must not be predictable).
  String _randomName() {
    const chars = '0123456789abcdefghijklmnopqrstuvwxyz';
    final rand = Random.secure();
    return List.generate(24, (_) => chars[rand.nextInt(chars.length)]).join();
  }

  /// List visitors, newest first. Contains only masked phone numbers.
  ///
  /// [day] optionally restricts results to entries whose entry_time falls on
  /// that calendar day (local time). [limit]/[offset] enable server-side
  /// pagination so large registers are fetched a page at a time.
  Future<List<Visitor>> listVisitors({
    bool onlyInside = false,
    DateTime? day,
    int? limit,
    int? offset,
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
    var transform = query.order('entry_time', ascending: false);
    if (limit != null) {
      final from = offset ?? 0;
      transform = transform.range(from, from + limit - 1);
    }
    final rows = await transform;
    return (rows as List)
        .map((r) => Visitor.fromMap(r as Map<String, dynamic>))
        .toList();
  }

  /// Fetch one page of visitors plus the total count for the current filter,
  /// so the UI can show classic numbered pages (Page N of M).
  Future<({List<Visitor> items, int total})> listVisitorsPage({
    DateTime? day,
    String? search,
    required int page,
    required int pageSize,
  }) async {
    final from = page * pageSize;
    final to = from + pageSize - 1;

    var query = _client.from('visitors').select();
    if (day != null) {
      final start = DateTime(day.year, day.month, day.day);
      final end = start.add(const Duration(days: 1));
      query = query
          .gte('entry_time', start.toUtc().toIso8601String())
          .lt('entry_time', end.toUtc().toIso8601String());
    }
    final q = (search ?? '').trim().replaceAll(RegExp(r'[%,()]'), ' ').trim();
    if (q.isNotEmpty) {
      query = query.or('name.ilike.%$q%,company.ilike.%$q%');
    }

    final res = await query
        .order('entry_time', ascending: false)
        .range(from, to)
        .count(CountOption.exact);

    final items = res.data.map((r) => Visitor.fromMap(r)).toList();
    return (items: items, total: res.count);
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

  // Note: reveal_phone() still records an audit row in the database on every
  // call (server-side). The in-app audit view was removed as it wasn't needed.
}
