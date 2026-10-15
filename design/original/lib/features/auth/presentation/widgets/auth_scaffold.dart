/// Shared layout chrome for Login and Signup (editorial title, form slot, footer).
///
/// Not used inside the app shell. Gives both auth screens the same structure so
/// we do not duplicate the big branded form layout.
library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_content_width.dart';

/// Shared responsive editorial shell for login and signup forms.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    required this.title,
    required this.subtitle,
    required this.form,
    required this.footer,
    super.key,
  });

  final String title;
  final String subtitle;
  final Widget form;
  final Widget footer;

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < 360;
    return Scaffold(
      body: Stack(
        children: [
          const Positioned(
            top: -100,
            left: -100,
            child: _OrganicGlow(color: AppColors.primary),
          ),
          const Positioned(
            right: -130,
            bottom: -130,
            child: _OrganicGlow(color: Color(0xFF705C30)),
          ),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(narrow ? 16 : 24),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: kAuthContentMaxWidth,
                  ),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x0F2E3230),
                          blurRadius: 20,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: narrow ? 20 : 32,
                        vertical: narrow ? 28 : 40,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'SoilGood',
                            style: GoogleFonts.literata(
                              color: AppColors.primary,
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            title,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.literata(
                              color: AppColors.textPrimary,
                              fontSize: narrow ? 28 : 34,
                              fontWeight: FontWeight.w700,
                              height: 1.15,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            subtitle,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 16,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 32),
                          form,
                          const SizedBox(height: 28),
                          footer,
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Soft background shape that mirrors the supplied mockup.
class _OrganicGlow extends StatelessWidget {
  const _OrganicGlow({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 320,
      height: 320,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color.withValues(alpha: 0.08), Colors.transparent],
        ),
      ),
    );
  }
}
