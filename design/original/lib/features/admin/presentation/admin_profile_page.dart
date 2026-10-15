/// Admin Profile page — account hub inside the admin website shell.
///
/// Shows name from profiles, email from Auth, role badge, and sign out.
/// Not the farmer Profile tab; lives under AdminShell IndexedStack.
library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/supabase/supabase_bootstrap.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/data/refresh_timeout.dart';
import '../../../shared/widgets/app_content_width.dart';
import '../../../shared/widgets/app_refresh_scroll.dart';
import '../../../shared/widgets/ui_primitives.dart';
import '../../onboarding/data/onboarding_repository.dart';

/// Admin account summary with pull-to-refresh.
class AdminProfilePage extends StatefulWidget {
  const AdminProfilePage({super.key});

  @override
  State<AdminProfilePage> createState() => _AdminProfilePageState();
}

class _AdminProfilePageState extends State<AdminProfilePage> {
  final _onboarding = OnboardingRepository();

  bool _loadDone = false;
  String? _error;
  String _displayName = '';
  String _role = 'admin';

  @override
  void initState() {
    super.initState();
    _reload();
  }

  /// Loads name + role from profiles.
  Future<void> _reload() async {
    setState(() => _error = null);
    try {
      final row = await withRefreshTimeout(_onboarding.loadProfile());
      if (!mounted) return;
      final first = (row?['first_name'] as String?)?.trim() ?? '';
      final last = (row?['last_name'] as String?)?.trim() ?? '';
      final name = '$first $last'.trim();
      final role = (row?['role'] as String?)?.trim() ?? 'admin';
      setState(() {
        _displayName = name.isEmpty ? 'Admin' : name;
        _role = role;
        _loadDone = true;
      });
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loadDone = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = supabase.auth.currentUser?.email ?? '—';

    if (!_loadDone && _error == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return AppRefreshScroll(
      onRefresh: _reload,
      maxWidth: kAdminContentMaxWidth,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        if (_error != null) ...[
          SoftCard(
            color: AppColors.surface,
            child: Text(
              _error!,
              style: const TextStyle(color: AppColors.error, height: 1.4),
            ),
          ),
          const SizedBox(height: 12),
        ],
        SoftCard(
          color: AppColors.surface,
          child: Row(
            children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: AppColors.primarySoft,
                child: Text(
                  _initials(_displayName),
                  style: GoogleFonts.literata(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.literata(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primarySoft.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _role.toUpperCase(),
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SoftCard(
          color: AppColors.surface,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Account',
                style: GoogleFonts.literata(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'This account can provision kits and view device inventory. '
                'Farmers use a separate account on the mobile app.',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => supabase.auth.signOut(),
                icon: const Icon(Icons.logout),
                label: const Text('Sign out'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'A';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
}
