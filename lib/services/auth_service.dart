import 'package:supabase_flutter/supabase_flutter.dart';

enum UserRole { guard, owner }

/// Thin wrapper around Supabase Auth that also knows the signed-in user's role.
class AuthService {
  final SupabaseClient _client = Supabase.instance.client;

  Session? get currentSession => _client.auth.currentSession;
  User? get currentUser => _client.auth.currentUser;

  Stream<AuthState> get onAuthStateChange => _client.auth.onAuthStateChange;

  Future<void> signIn(String email, String password) async {
    await _client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<void> signOut() => _client.auth.signOut();

  /// Reads the current user's role from the `profiles` table.
  /// Defaults to guard if anything is missing — the safest fallback, since a
  /// guard can never see phone numbers.
  Future<UserRole> fetchRole() async {
    final uid = currentUser?.id;
    if (uid == null) return UserRole.guard;
    final row = await _client
        .from('profiles')
        .select('role')
        .eq('id', uid)
        .maybeSingle();
    final role = row?['role'] as String?;
    return role == 'owner' ? UserRole.owner : UserRole.guard;
  }

  Future<String> fetchFullName() async {
    final uid = currentUser?.id;
    if (uid == null) return '';
    final row = await _client
        .from('profiles')
        .select('full_name')
        .eq('id', uid)
        .maybeSingle();
    return (row?['full_name'] as String?) ?? '';
  }
}
