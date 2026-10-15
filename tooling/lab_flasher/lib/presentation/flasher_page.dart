/// Main Lab Flasher screen: one button Provision & Flash + port auto-detect.
///
/// Windows desktop station UI (matches docs/mocks/lab_flasher_mock.html).
/// Blocks provision if no COM port. Success shows claim code for the sticker.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/lab_env.dart';
import '../data/flash_repository.dart';
import '../data/serial_config_injector.dart';
import '../data/serial_port_service.dart';
import '../theme/app_colors.dart';

/// Single-window Provision & Flash workflow.
class FlasherPage extends StatefulWidget {
  const FlasherPage({super.key});

  @override
  State<FlasherPage> createState() => _FlasherPageState();
}

class _FlasherPageState extends State<FlasherPage> {
  final _labelController = TextEditingController();
  final _ports = SerialPortService();
  final _repo = FlashRepository();
  final _injector = SerialConfigInjector();

  PortScanResult? _scan;
  String? _selectedPort;
  bool _showPortDropdown = false;
  bool _busy = false;
  String _status = '';
  String? _error;
  ProvisionedKit? _success;
  ProvisionedKit? _pendingRetry;
  final _details = <String>[];
  bool _showDetails = false;

  @override
  void initState() {
    super.initState();
    _rescan();
  }

  @override
  void dispose() {
    _labelController.dispose();
    super.dispose();
  }

  /// Re-lists COM ports and applies auto / dropdown rules.
  void _rescan() {
    final scan = _ports.scan();
    setState(() {
      _scan = scan;
      _showPortDropdown = false;
      if (scan.hasAuto) {
        _selectedPort = scan.autoPort!.name;
      } else if (scan.espCandidates.isEmpty && scan.allPorts.isEmpty) {
        _selectedPort = null;
      } else if (scan.espCandidates.length == 1) {
        _selectedPort = scan.espCandidates.first.name;
      } else {
        _selectedPort = null;
        _showPortDropdown = true;
      }
    });
  }

  bool get _canGo =>
      !_busy && _selectedPort != null && _selectedPort!.isNotEmpty;

  /// Full flow: port check → provision → SGCFG → mark flashed.
  Future<void> _provisionAndFlash({bool retryFlashOnly = false}) async {
    final port = _selectedPort;
    if (port == null || port.isEmpty) {
      setState(() {
        _error = 'No ESP32 detected — plug the board, then Refresh ports.';
      });
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
      _status = retryFlashOnly ? 'Flashing…' : 'Provisioning…';
      _success = null;
      if (!retryFlashOnly) _details.clear();
    });

    ProvisionedKit? kit = retryFlashOnly ? _pendingRetry : null;

    try {
      if (kit == null) {
        _log('Calling admin_provision_device…');
        kit = await _repo.provision(name: _labelController.text);
        _pendingRetry = kit;
        _log('Provisioned ${kit.deviceUid} · ${kit.claimCode}');
      }

      setState(() => _status = 'Writing credentials on $port…');
      _log('Open $port @ 115200');

      await _injector.inject(
        portName: port,
        config: {
          'device_uid': kit.deviceUid,
          'ingest_token': kit.ingestToken,
          'wifi_ssid': LabEnv.wifiSsid,
          'wifi_password': LabEnv.wifiPassword,
          'supabase_url': LabEnv.supabaseUrl,
          'supabase_anon': LabEnv.supabaseAnonKey,
        },
        onLog: _log,
      );

      setState(() => _status = 'Marking flashed…');
      await _repo.markFlashed(kit.id);
      _log('admin_mark_device_flashed OK');

      if (!mounted) return;
      setState(() {
        _busy = false;
        _status = '';
        _success = kit;
        _pendingRetry = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _status = '';
        _error = '$e';
        _showDetails = true;
        // Keep claim code visible if we already provisioned.
        if (kit != null) {
          _success = kit;
        }
      });
    }
  }

  void _log(String line) {
    _details.add(line);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final scan = _scan;
    final autoOk = scan?.hasAuto == true && !_showPortDropdown;
    final noPorts = scan != null &&
        scan.allPorts.isEmpty &&
        (_selectedPort == null || _selectedPort!.isEmpty);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Material(
              color: AppColors.surface,
              elevation: 2,
              shadowColor: Colors.black26,
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Lab Flasher',
                            style: GoogleFonts.literata(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: _busy
                              ? null
                              : () => Supabase.instance.client.auth.signOut(),
                          child: Text(
                            'Sign out',
                            style: GoogleFonts.nunitoSans(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      'One button: provision + flash. Port auto-detects when possible.',
                      style: GoogleFonts.nunitoSans(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Label (optional)',
                      style: GoogleFonts.nunitoSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _labelController,
                      enabled: !_busy,
                      decoration: InputDecoration(
                        hintText: 'Kit #12',
                        filled: true,
                        fillColor: const Color(0xFFFAFBFA),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _PortPill(
                      ok: autoOk && !noPorts,
                      text: _portPillText(scan, noPorts),
                      onChange: autoOk
                          ? () => setState(() => _showPortDropdown = true)
                          : null,
                      onRefresh: _busy ? null : _rescan,
                    ),
                    if (_showPortDropdown ||
                        (scan != null &&
                            !scan.hasAuto &&
                            scan.allPorts.isNotEmpty)) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Select USB port',
                        style: GoogleFonts.nunitoSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        // ignore: deprecated_member_use
                        value: _selectedPort,
                        items: (scan?.espCandidates.isNotEmpty == true
                                ? scan!.espCandidates
                                : scan?.allPorts ?? const <SerialPortInfo>[])
                            .map(
                              (p) => DropdownMenuItem(
                                value: p.name,
                                child: Text(
                                  p.displayLabel,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: _busy
                            ? null
                            : (v) => setState(() => _selectedPort = v),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: const Color(0xFFFAFBFA),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          isDense: true,
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 48,
                      child: FilledButton(
                        onPressed: _canGo ? () => _provisionAndFlash() : null,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          disabledBackgroundColor:
                              AppColors.primary.withValues(alpha: 0.4),
                        ),
                        child: _busy
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                'Provision & Flash',
                                style: GoogleFonts.nunitoSans(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 15,
                                ),
                              ),
                      ),
                    ),
                    if (_status.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text(
                        _status,
                        style: GoogleFonts.nunitoSans(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.errorSoft,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              _error!,
                              style: GoogleFonts.nunitoSans(
                                color: AppColors.error,
                                fontSize: 13,
                              ),
                            ),
                            if (_pendingRetry != null) ...[
                              const SizedBox(height: 8),
                              OutlinedButton(
                                onPressed: _busy
                                    ? null
                                    : () => _provisionAndFlash(
                                          retryFlashOnly: true,
                                        ),
                                child: const Text('Retry flash only'),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                    if (_success != null) ...[
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.primarySoft,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          children: [
                            Text(
                              _error == null
                                  ? 'Write this on the box'
                                  : 'Provisioned — flash incomplete',
                              style: GoogleFonts.nunitoSans(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            SelectableText(
                              _success!.claimCode,
                              style: GoogleFonts.literata(
                                fontSize: 28,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _error == null
                                  ? 'Unplug the board · give kit to farmer'
                                  : 'Keep this code; retry flash or paste secrets manually',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.nunitoSans(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextButton.icon(
                              onPressed: () async {
                                await Clipboard.setData(
                                  ClipboardData(text: _success!.claimCode),
                                );
                              },
                              icon: const Icon(Icons.copy, size: 16),
                              label: const Text('Copy claim code'),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () =>
                          setState(() => _showDetails = !_showDetails),
                      child: Text(
                        _showDetails
                            ? 'Hide technical details'
                            : 'Technical details',
                        style: GoogleFonts.nunitoSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    if (_showDetails && _details.isNotEmpty)
                      Container(
                        constraints: const BoxConstraints(maxHeight: 140),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0F2F0),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ListView(
                          children: _details
                              .map(
                                (l) => Text(
                                  l,
                                  style: GoogleFonts.nunitoSans(
                                    fontSize: 11,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _portPillText(PortScanResult? scan, bool noPorts) {
    if (scan == null) return 'Scanning ports…';
    if (noPorts) return 'No ESP32 detected — plug the board';
    if (scan.hasAuto && !_showPortDropdown) {
      final p = scan.autoPort!;
      final short = p.description.trim().isEmpty
          ? p.name
          : '${p.name} · ${p.description}';
      return 'Auto: $short';
    }
    if (_selectedPort != null) return 'Port: $_selectedPort';
    return 'Multiple ports — choose one';
  }
}

class _PortPill extends StatelessWidget {
  const _PortPill({
    required this.ok,
    required this.text,
    this.onChange,
    this.onRefresh,
  });

  final bool ok;
  final String text;
  final VoidCallback? onChange;
  final VoidCallback? onRefresh;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: ok ? AppColors.primarySoft : AppColors.errorSoft,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.nunitoSans(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: ok ? AppColors.primary : AppColors.error,
              ),
            ),
          ),
          if (onChange != null)
            TextButton(
              onPressed: onChange,
              child: Text(
                'Change',
                style: GoogleFonts.nunitoSans(
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                  color: AppColors.primary,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          IconButton(
            tooltip: 'Refresh ports',
            onPressed: onRefresh,
            icon: Icon(
              Icons.refresh,
              size: 20,
              color: ok ? AppColors.primary : AppColors.error,
            ),
          ),
        ],
      ),
    );
  }
}
