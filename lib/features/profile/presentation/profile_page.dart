/// Profile feature page shown inside the app shell content area (fourth bottom-nav tab).
///
/// Account hub for the signed-in farmer: view email, jump to edit-profile
/// onboarding, and sign out. Not a standalone auth screen.
library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/supabase/supabase_bootstrap.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/ui_primitives.dart';
import '../../../shared/navigation/app_page_routes.dart';
import '../../auth/data/auth_repository.dart';
import '../../onboarding/presentation/profile_onboarding_page.dart';
import '../../shell/app_shell.dart';

/// Account / profile hub — UI navigation only (except sign out).
class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final email = supabase.auth.currentUser?.email ?? 'farmer@example.com';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: const SoilGoodTopBar(title: 'Profile', leadingIcon: Icons.person),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
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
                        'Farmer account',
                        style: GoogleFonts.literata(
                          fontWeight: FontWeight.w700,
                          fontSize: 20,
                        ),
                      ),
                      Text(
                        email,
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          SoftCard(
            onTap: () {
              Navigator.of(context).push(
                AppPageRoutes.slideFromRight(
                  const ProfileOnboardingPage(fromProfile: true),
                ),
              );
            },
            child: const ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(Icons.badge_outlined, color: AppColors.primary),
              title: Text(
                'Edit profile details',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text('Name & address (UI only for now)'),
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
