/// Admin Devices — inventory + Option B Provision & Flash (Chrome Web Serial).
///
/// Flutter web ops console (AdminShell). One primary action provisions the kit
/// in Supabase then injects SGCFG over USB. Windows Lab Flasher remains backup.
library;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/config/app_env.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/navigation/app_page_routes.dart';
import '../../../shared/widgets/app_content_width.dart';
import '../../../shared/widgets/app_refresh_scroll.dart';
import '../../../shared/widgets/ui_primitives.dart';
import '../../auth/presentation/widgets/auth_error_banner.dart';
import '../../auth/presentation/widgets/auth_primary_button.dart';
import '../../auth/presentation/widgets/auth_text_field.dart';
import '../data/admin_device.dart';
import '../data/admin_devices_repository.dart';
import '../data/web_serial_bridge.dart';
import '../logic/admin_datetime.dart';
import 'admin_device_detail_page.dart';

/// Filter chip values for the device list.
enum _StatusFilter { all, unclaimed, active, offline, error }

/// Admin inventory + Provision & Flash entry point.
class AdminDevicesPage extends StatefulWidget {
  const AdminDevicesPage({super.key});

  @override
  State<AdminDevicesPage> createState() => _AdminDevicesPageState();
}

class _AdminDevicesPageState extends State<AdminDevicesPage> {
  final _repo = AdminDevicesRepository();
  final _serial = WebSerialBridge();
  List<AdminDeviceSummary>? _devices;
  String? _error;
  bool _firstLoad = true;
  bool _busy = false;
  String _status = '';
  _StatusFilter _filter = _StatusFilter.all;

  final _nameController = TextEditingController();
  final _wifiSsidController = TextEditingController();
  final _wifiPassController = TextEditingController();

  String? _portLabel;
  AdminDeviceDetail? _lastSuccess;
  AdminDeviceDetail? _pendingRetry;
  bool _showDetails = false;
  final _details = <String>[];

  @override
  void initState() {
    super.initState();
    final wifi = _serial.loadWifi();
    _wifiSsidController.text = wifi.ssid;
    _wifiPassController.text = wifi.password;
    if (_serial.hasPort) {
      _portLabel = _serial.portLabel;
    }
    _reload();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _wifiSsidController.dispose();
    _wifiPassController.dispose();
    super.dispose();
  }

  bool get _serialOk => kIsWeb && _serial.isSupported;

  bool get _canFlash =>
      !_busy &&
      _serialOk &&
      (_portLabel != null && _portLabel!.isNotEmpty) &&
      _wifiSsidController.text.trim().isNotEmpty;

  /// Loads inventory; keeps last-known on pull failure.
  Future<void> _reload() async {
    setState(() => _error = null);
    try {
      final list =
          await _repo.listDevices().timeout(const Duration(seconds: 15));
      if (!mounted) return;
      setState(() {
        _devices = list;
        _firstLoad = false;
      });
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _firstLoad = false;
      });
    }
  }

  List<AdminDeviceSummary> get _filtered {
    final all = _devices ?? const <AdminDeviceSummary>[];
    return switch (_filter) {
      _StatusFilter.all => all,
      _StatusFilter.unclaimed =>
        all.where((d) => d.status == 'unclaimed').toList(),
      _StatusFilter.active => all.where((d) => d.status == 'active').toList(),
      _StatusFilter.offline =>
        all.where((d) => d.status == 'offline').toList(),
      _StatusFilter.error => all.where((d) => d.status == 'error').toList(),
    };
  }

  int _count(String status) =>
      (_devices ?? []).where((d) => d.status == status).length;

  void _log(String line) {
    _details.add(line);
    if (mounted) setState(() {});
  }

  /// Chrome serial port picker (user gesture).
  Future<void> _connectBoard() async {
    setState(() {
      _error = null;
      _status = 'Choose USB port…';
    });
    try {
      final label = await _serial.requestPort();
      if (!mounted) return;
      setState(() {
        _portLabel = label.isEmpty ? 'USB serial connected' : label;
        _status = '';
      });
      _log('Port: $_portLabel');
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _status = '';
        _portLabel = null;
      });
    }
  }

  /// Provision (unless retry) → SGCFG → mark flashed.
  Future<void> _provisionAndFlash({bool retryFlashOnly = false}) async {
    if (!_serialOk) {
      setState(() {
        _error =
            'Provision & Flash needs Chrome/Edge on desktop (Web Serial).';
      });
      return;
    }
    if (_portLabel == null || _portLabel!.isEmpty) {
      setState(() {
        _error = 'Connect the ESP32 first (Connect board).';
      });
      return;
    }
    final ssid = _wifiSsidController.text.trim();
    final pass = _wifiPassController.text;
    if (ssid.isEmpty) {
      setState(() => _error = 'Lab WiFi SSID is required.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
      _lastSuccess = null;
      _status = retryFlashOnly ? 'Flashing…' : 'Provisioning…';
      if (!retryFlashOnly) _details.clear();
    });

    AdminDeviceDetail? kit = retryFlashOnly ? _pendingRetry : null;

    try {
      _serial.saveWifi(ssid: ssid, password: pass);

      if (kit == null) {
        _log('admin_provision_device…');
        kit = await _repo
            .provisionDevice(name: _nameController.text)
            .timeout(const Duration(seconds: 15));
        _pendingRetry = kit;
        _log('Provisioned ${kit.deviceUid} · ${kit.claimCode}');
      }

      setState(() => _status = 'Writing credentials over USB…');
      _log('SGCFG inject…');
      await _serial.injectConfig({
        'device_uid': kit.deviceUid,
        'ingest_token': kit.ingestToken,
        'wifi_ssid': ssid,
        'wifi_password': pass,
        'supabase_url': AppEnv.supabaseUrl,
        'supabase_anon': AppEnv.supabaseAnonKey,
      });
      _log('SGCFG_OK');

      // Port was closed after inject; ask admin to reconnect for next kit.
      setState(() {
        _portLabel = null;
        _status = 'Marking flashed…';
      });

      await _repo.markFlashed(kit.id).timeout(const Duration(seconds: 15));
      _log('admin_mark_device_flashed OK');

      if (!mounted) return;
      _nameController.clear();
      setState(() {
        _busy = false;
        _status = '';
        _lastSuccess = kit;
        _pendingRetry = null;
      });
      await _reload();
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _status = '';
        _error = e.toString();
        _showDetails = true;
        _portLabel = null;
        if (kit != null) _lastSuccess = kit;
      });
      await _serial.close();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_firstLoad && _devices == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final total = _devices?.length ?? 0;
    final portOk = _portLabel != null && _portLabel!.isNotEmpty;

    return AppRefreshScroll(
      onRefresh: _reload,
      maxWidth: kAdminContentMaxWidth,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      children: [
        Text(
          'Kit inventory',
          style: GoogleFonts.literata(
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'One button: provision + USB flash (Chrome). '
          'Windows Lab Flasher remains a backup.',
          style: TextStyle(color: AppColors.textSecondary, height: 1.4),
        ),
        const SizedBox(height: 16),
        SoftCard(
          color: AppColors.surface,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Provision & Flash',
                style: GoogleFonts.literata(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Plug ESP32 → Connect board → flash. Claim code appears for the sticker.',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  height: 1.35,
                  fontSize: 13,
                ),
              ),
              if (!_serialOk) ...[
                const SizedBox(height: 10),
                SoftCard(
                  color: AppColors.errorContainer,
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    kIsWeb
                        ? 'This browser has no Web Serial. Use Chrome/Edge on desktop.'
                        : 'Open Admin on Chrome (`flutter run -d chrome`) to flash over USB.',
                    style: const TextStyle(
                      color: AppColors.error,
                      fontSize: 13,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              AuthTextField(
                controller: _nameController,
                label: 'Label (optional)',
                hint: 'Kit #12',
                icon: Icons.label_outline,
              ),
              const SizedBox(height: 10),
              AuthTextField(
                controller: _wifiSsidController,
                label: 'Lab WiFi SSID (2.4 GHz)',
                hint: 'FarmOffice_2.4',
                icon: Icons.wifi,
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 10),
              AuthTextField(
                controller: _wifiPassController,
                label: 'Lab WiFi password',
                hint: '••••••••',
                icon: Icons.lock_outline,
                obscureText: true,
              ),
              const SizedBox(height: 12),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: portOk
                      ? AppColors.primarySoft.withValues(alpha: 0.55)
                      : AppColors.errorContainer.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        portOk
                            ? 'Port: $_portLabel'
                            : 'No board — Connect ESP32 USB',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: portOk ? AppColors.primary : AppColors.error,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: _busy || !_serialOk ? null : _connectBoard,
                      child: Text(
                        portOk ? 'Change' : 'Connect board',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: portOk ? AppColors.primary : AppColors.error,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              AuthPrimaryButton(
                label: 'Provision & Flash',
                isLoading: _busy,
                onPressed: _canFlash ? () => _provisionAndFlash() : null,
              ),
              if (_status.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  _status,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
              AuthErrorBanner(message: _error),
              if (_error != null && _pendingRetry != null) ...[
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: _busy || !_serialOk || !portOk
                      ? null
                      : () => _provisionAndFlash(retryFlashOnly: true),
                  child: const Text('Retry flash only (reconnect board first)'),
                ),
              ],
              if (_lastSuccess != null) ...[
                const SizedBox(height: 14),
                SoftCard(
                  color: AppColors.primarySoft.withValues(alpha: 0.5),
                  child: Column(
                    children: [
                      Text(
                        _error == null
                            ? 'Write this on the box'
                            : 'Provisioned — flash incomplete',
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      SelectableText(
                        _lastSuccess!.claimCode ?? '—',
                        style: GoogleFonts.literata(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _error == null
                            ? 'Unplug · sticker · give kit to farmer'
                            : 'Keep this code; reconnect board and retry flash',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: _lastSuccess!.claimCode == null
                            ? null
                            : () async {
                                await Clipboard.setData(
                                  ClipboardData(
                                    text: _lastSuccess!.claimCode!,
                                  ),
                                );
                              },
                        icon: const Icon(Icons.copy, size: 16),
                        label: const Text('Copy claim code'),
                      ),
                    ],
                  ),
                ),
              ],
              TextButton(
                onPressed: () =>
                    setState(() => _showDetails = !_showDetails),
                child: Text(
                  _showDetails
                      ? 'Hide technical details'
                      : 'Technical details',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              if (_showDetails && _details.isNotEmpty)
                SoftCard(
                  color: AppColors.surfaceMuted,
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final line in _details)
                        Text(
                          line,
                          style: const TextStyle(
                            fontSize: 11,
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
          color: AppColors.primarySoft.withValues(alpha: 0.4),
          child: Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              _CountChip(label: 'Total', value: total),
              _CountChip(label: 'Unclaimed', value: _count('unclaimed')),
              _CountChip(label: 'Active', value: _count('active')),
              _CountChip(label: 'Offline', value: _count('offline')),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final f in _StatusFilter.values)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(_filterLabel(f)),
                    selected: _filter == f,
                    onSelected: (_) => setState(() => _filter = f),
                    selectedColor: AppColors.primarySoft,
                    checkmarkColor: AppColors.primary,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (_filtered.isEmpty)
          SoftCard(
            color: AppColors.surface,
            child: Text(
              _devices == null || _devices!.isEmpty
                  ? 'No devices yet. Use Provision & Flash to create a kit.'
                  : 'No devices in this filter.',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          )
        else
          ..._filtered.map(
            (d) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: SoftCard(
                color: AppColors.surface,
                onTap: () async {
                  await Navigator.of(context).push(
                    AppPageRoutes.slideFromRight(
                      AdminDeviceDetailPage(deviceId: d.id),
                    ),
                  );
                  if (mounted) await _reload();
                },
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            d.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            d.claimCode ?? '—',
                            style: GoogleFonts.literata(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${d.status}'
                            '${d.ownerEmail != null ? ' · ${d.ownerEmail}' : ''}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Flashed: ${formatFlashedLabel(d.flashedAt)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: d.isFlashed
                                  ? AppColors.primary
                                  : AppColors.textSecondary,
                              fontSize: 12,
                              fontWeight: d.isFlashed
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              fontStyle: d.isFlashed
                                  ? FontStyle.normal
                                  : FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right,
                      color: AppColors.textSecondary,
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  String _filterLabel(_StatusFilter f) => switch (f) {
        _StatusFilter.all => 'All',
        _StatusFilter.unclaimed => 'Unclaimed',
        _StatusFilter.active => 'Active',
        _StatusFilter.offline => 'Offline',
        _StatusFilter.error => 'Error',
      };
}

class _CountChip extends StatelessWidget {
  const _CountChip({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$value',
          style: GoogleFonts.literata(
            fontSize: 22,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
