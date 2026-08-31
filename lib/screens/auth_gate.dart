import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/auth_service.dart';
import 'guard/guard_home.dart';
import 'login_screen.dart';
import 'owner/owner_home.dart';

/// Decides what to show based on auth state and role.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final AuthService _auth = AuthService();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: _auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = _auth.currentSession;
        if (session == null) {
          return const LoginScreen();
        }
        return _RoleRouter(auth: _auth);
      },
    );
  }
}

/// Once logged in, resolve the role and route accordingly.
class _RoleRouter extends StatefulWidget {
  const _RoleRouter({required this.auth});

  final AuthService auth;

  @override
  State<_RoleRouter> createState() => _RoleRouterState();
}

class _RoleRouterState extends State<_RoleRouter> {
  late Future<UserRole> _roleFuture;

  @override
  void initState() {
    super.initState();
    _roleFuture = widget.auth.fetchRole();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<UserRole>(
      future: _roleFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, size: 48),
                    const SizedBox(height: 12),
                    Text('Could not load your profile.\n${snapshot.error}',
                        textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () => widget.auth.signOut(),
                      child: const Text('Sign out'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        return snapshot.data == UserRole.owner
            ? const OwnerHome()
            : const GuardHome();
      },
    );
  }
}
