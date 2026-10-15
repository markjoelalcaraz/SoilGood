/// Reads the signed-in user's `profiles.role` for AuthGate routing.
///
/// Admin → AdminShell (web ops). Farmer → onboarding / AppShell.
/// Role is never trusted from the client for writes — RPCs check is_admin().
library;

import '../../../core/supabase/supabase_bootstrap.dart';

/// App role stored on profiles (default farmer).
enum AppRole { farmer, admin }

/// Loads role for the current auth user.
class ProfileRoleRepository {
  /// Returns farmer when missing/unknown so we fail closed for admin UI.
  Future<AppRole> loadCurrentRole() async {
    final uid = supabase.auth.currentUser?.id;
    if (uid == null) return AppRole.farmer;

    final row = await supabase
        .from('profiles')
        .select('role')
        .eq('id', uid)
        .maybeSingle();

    final role = (row?['role'] as String?)?.trim().toLowerCase() ?? 'farmer';
    if (role == 'admin') return AppRole.admin;
    return AppRole.farmer;
  }
}
