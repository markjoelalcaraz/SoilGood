/// Profile feature page shown inside the app shell content area (fourth bottom-nav tab).
///
/// Account hub for the signed-in farmer: real name from `profiles`, email from
/// Auth, jump to edit-profile, and sign out. Not a standalone auth screen.
library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/supabase/supabase_bootstrap.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/data/refresh_timeout.dart';
import '../../../shared/navigation/app_page_routes.dart';
import '../../../shared/widgets/app_refresh_scroll.dart';
import '../../../shared/widgets/ui_primitives.dart';
import '../../auth/data/auth_repository.dart';
import '../../onboarding/data/onboarding_repository.dart';
import '../../onboarding/presentation/profile_onboarding_page.dart';
import '../../shell/app_shell.dart';

/// Account / profile hub with the farmer’s saved name and email.
class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _onboarding = OnboardingRepository();

  bool _loadDone = false;
  Object? _loadError;
  String _displayName = '';

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  /// Loads first + last name from `profiles`. Email comes from Auth.
  Future<void> _loadProfile() async {
    try {
      final row = await withRefreshTimeout(_onboarding.loadProfile());
      if (!mounted) return;
      final first = (row?['first_name'] as String?)?.trim() ?? '';
      final last = (row?['last_name'] as String?)?.trim() ?? '';
      final name = '$first $last'.trim();
      setState(() {
        _displayName = name;
        _loadError = null;
        _loadDone = true;
      });
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e;
        _loadDone = true;
      });
    }
  }

  Future<void> _openEdit() async {
    await Navigator.of(context).push(
      AppPageRoutes.slideFromRight(
        const ProfileOnboardingPage(fromProfile: true),
      ),
    );
    if (mounted) await _loadProfile();
  }

  @override
  Widget build(BuildContext context) {
    final email = supabase.auth.currentUser?.email;
    final waitingFirst = !_loadDone && _loadError == null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const SoilGoodTopBar(title: 'Profile', leadingIcon: Icons.person),
      body: AppRefreshScroll(
        onRefresh: _loadProfile,
        children: [
          if (_loadError != null) ...[
            SoftCard(
              color: AppColors.errorContainer,
              child: Text(
                'Could not load profile:\n$_loadError',
                style: const TextStyle(color: Color(0xFF690005), height: 1.5),
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (waitingFirst)
            const SoftCard(
              color: AppColors.surfaceMuted,
              child: SizedBox(height: 72),
            )
          else
            SoftCard(
              color: AppColors.surface,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                    child: const Icon(
                      Icons.person,
                      color: AppColors.primary,
                      size: 30,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _displayName.isEmpty ? 'Name not set' : _displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.literata(
                            fontWeight: FontWeight.w700,
                            fontSize: 20,
                          ),
                        ),
                        Text(
                          email == null || email.isEmpty
                              ? 'No email on this account'
                              : email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          SoftCard(
            onTap: _openEdit,
            child: const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.badge_outlined, color: AppColors.primary),
              title: Text(
                'Edit profile details',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text('Name and address'),
              trailing: Icon(Icons.chevron_right),
            ),
          ),
          const SizedBox(height: 10),
          SoftCard(
            child: const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                Icons.agriculture_outlined,
                color: AppColors.primary,
              ),
              title: Text(
                'Farm & device',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text('Location + ESP32 claim — coming next'),
              trailing: Icon(Icons.lock_outline, size: 18),
            ),
          ),
          const SizedBox(height: 10),
          SoftCard(
            onTap: () => AuthRepository().signOut(),
            child: const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.logout, color: AppColors.error),
              title: Text(
                'Sign out',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.error,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
