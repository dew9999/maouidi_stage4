// lib/auth/supabase_auth/auth_util.dart

import 'dart:async';
// 'rxdart' is no longer needed, so we remove it.
import 'package:maouidi/backend/supabase/supabase.dart';
import '../base_auth_user_provider.dart';
import '../auth_manager.dart';
import 'supabase_auth_manager.dart';

final AuthManager authManager = SupabaseAuthManager();

String get currentUserEmail => currentUser?.email ?? '';
String get currentUserUid => currentUser?.uid ?? '';
String get currentUserDisplayName => currentUser?.displayName ?? '';
String get currentUserPhoto => currentUser?.photoUrl ?? '';
String get currentPhoneNumber => currentUser?.phoneNumber ?? '';
bool get currentUserEmailVerified => currentUser?.emailVerified ?? false;

String get currentJwtToken =>
    (currentUser is MaouidiSupabaseUser
        ? (currentUser as MaouidiSupabaseUser).jwtToken
        : null) ??
    '';

Stream<BaseAuthUser?> maouidiSupabaseUserStream() {
  final supabaseAuthStream = SupaFlow.client.auth.onAuthStateChange;
  return supabaseAuthStream.map((authState) {
    // --- THIS IS THE FIX ---
    // This is a cleaner way to handle the logic that avoids all warnings.
    final user = authState.session?.user;
    currentUser = user == null ? null : MaouidiSupabaseUser(user);
    return currentUser;
    // -----------------------
  });
}

final jwtTokenStream = SupaFlow.client.auth.onAuthStateChange
    .map((authState) => authState.session?.accessToken);
