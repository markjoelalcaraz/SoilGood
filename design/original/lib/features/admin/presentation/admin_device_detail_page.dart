/// Admin device detail — claim code + flash secrets + claim status.
///
/// Pushed from the Devices list after provision or row tap. Prefer
/// Provision & Flash on this Admin Web (Chrome). secrets.h / Lab Flasher = backup.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_content_width.dart';
import '../../../shared/widgets/app_refresh_scroll.dart';
import '../../../shared/widgets/ui_primitives.dart';
import '../../auth/presentation/widgets/auth_error_banner.dart';
import '../data/admin_device.dart';
import '../data/admin_devices_repository.dart';
import '../logic/admin_datetime.dart';

/// Shows one kit for ops: sticker code + firmware secrets.
class AdminDeviceDetailPage extends StatefulWidget {
  const AdminDeviceDetailPage({
    required this.deviceId,
    this.initial,
    super.key,
  });

  final String deviceId;
  final AdminDeviceDetail? initial;

  @override
  State<AdminDeviceDetailPage> createState() => _AdminDeviceDetailPageState();
}

class _AdminDeviceDetailPageState extends State<AdminDeviceDetailPage> {
  final _repo = AdminDevicesRepository();
  AdminDeviceDetail? _device;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _device = widget.initial;
    _loading = widget.initial == null;
    _reload();
  }

  Future<void> _reload() async {
    setState(() => _error = null);
    try {
      final d = await _repo
          .getDevice(widget.deviceId)
          .timeout(const Duration(seconds: 15));
      if (!mounted) return;
      setState(() {
        _device = d;
        _loading = false;
      });
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _copy(String label, String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label copied')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final d = _device;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.primary,
        title: Text(
          'Kit detail',
          style: GoogleFonts.literata(fontWeight: FontWeight.w700),
        ),
      ),
      body: _loading && d == null
          ? const Center(child: CircularProgressIndicator())
          : AppRefreshScroll(
              onRefresh: _reload,
              maxWidth: kAdminContentMaxWidth,
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              children: [
                AuthErrorBanner(message: _error),
                if (_error != null) const SizedBox(height: 12),
                if (d == null)
                  const SoftCard(
                    color: AppColors.surface,
                    child: Text('Device not found.'),
                  )
                else ...[
                  SoftCard(
                    color: AppColors.primarySoft.withValues(alpha: 0.45),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          d.name,
                          style: GoogleFonts.literata(
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Status: ${d.status}',
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        if (d.ownerEmail != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Claimed by: ${d.ownerEmail}'
                            '${d.farmName != null ? ' (${d.farmName})' : ''}',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                        if (d.lastSeenAt != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            'Last seen: ${formatAdminDateTime(d.lastSeenAt)}',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ],
                        const SizedBox(height: 4),
                        Text(
                          'Flashed: ${formatFlashedLabel(d.flashedAt)}',
                          style: TextStyle(
                            color: d.isFlashed
                                ? AppColors.primary
                                : AppColors.textSecondary,
                            fontSize: 13,
                            fontWeight:
                                d.isFlashed ? FontWeight.w700 : FontWeight.w500,
                            fontStyle: d.isFlashed
                                ? FontStyle.normal
                                : FontStyle.italic,
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
                          'Claim code (sticker)',
                          style: GoogleFonts.literata(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        SelectableText(
                          d.claimCode ?? '—',
                          style: GoogleFonts.literata(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: d.claimCode == null
                              ? null
                              : () => _copy('Claim code', d.claimCode!),
                          icon: const Icon(Icons.copy),
                          label: const Text('Copy claim code'),
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
                          'Flash secrets (fallback)',
                          style: GoogleFonts.literata(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Prefer Provision & Flash on Admin Devices (Chrome + USB). '
                          'Backup: Windows Lab Flasher or paste into secrets.h. '
                          'Farmer never sees these.',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            height: 1.4,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 12),
                        SelectableText(
                          d.secretsHSnippet(),
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 13,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: () => _copy(
                            'Secrets',
                            d.secretsHSnippet(),
                          ),
                          icon: const Icon(Icons.copy),
                          label: const Text('Copy DEVICE_UID + INGEST_TOKEN'),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}
