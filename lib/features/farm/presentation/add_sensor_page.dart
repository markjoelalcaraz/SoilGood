/// Pushed page to link a new kit to the crop the farmer already chose.
///
/// Opened from Profile sensors and from the selected plot on the Farm tab.
/// The sticker code is the name the farmer will see. Not a shell tab.
library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_content_width.dart';
import '../../../shared/widgets/ui_primitives.dart';
import '../../auth/presentation/widgets/auth_error_banner.dart';
import '../../auth/presentation/widgets/auth_primary_button.dart';
import '../../auth/presentation/widgets/auth_text_field.dart';
import '../data/plot_sensors_repository.dart';

/// Claim a sticker code onto [cropName]. Pops `true` when the kit is placed.
class AddSensorPage extends StatefulWidget {
  const AddSensorPage({
    required this.plantingId,
    required this.cropName,
    super.key,
  });

  final String plantingId;
  final String cropName;

  @override
  State<AddSensorPage> createState() => _AddSensorPageState();
}

class _AddSensorPageState extends State<AddSensorPage> {
  final _repo = PlotSensorsRepository();
  final _code = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  /// Claims the kit, then places it on this plot. Stays here if the code fails.
  Future<void> _link() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await _repo.claimOnPlot(
        claimCode: _code.text,
        plantingId: widget.plantingId,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is StateError ? e.message : e.toString();
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.primary,
        title: Text(
          'Add sensor',
          style: GoogleFonts.literata(fontWeight: FontWeight.w700),
        ),
      ),
      body: AppContentWidth(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          children: [
            SoftCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'PLOT',
                    style: TextStyle(
                      color: AppColors.navIcon,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.6,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.cropName,
                    style: GoogleFonts.literata(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Type the code on the new kit. It will watch this plot.',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SoftCard(
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    AuthTextField(
                      controller: _code,
                      label: 'Claim code',
                      hint: 'SG-XXXX',
                      icon: Icons.qr_code_2,
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    AuthErrorBanner(message: _error),
                    if (_error != null) const SizedBox(height: 12),
                    AuthPrimaryButton(
                      label: 'Link sensor',
                      isLoading: _saving,
                      onPressed: _link,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
