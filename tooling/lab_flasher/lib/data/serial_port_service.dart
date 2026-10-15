/// Discovers USB serial ports and filters likely ESP32 adapters.
///
/// Used by the Lab Flasher UI for auto-detect + dropdown backup. Prefers
/// CH340 / CP210 / FTDI style descriptions; never guesses when 0 or 2+ match.
library;

import 'package:flutter_libserialport/flutter_libserialport.dart';

/// One available COM / tty port with a farmer-friendly label.
class SerialPortInfo {
  const SerialPortInfo({
    required this.name,
    required this.description,
  });

  final String name;
  final String description;

  String get displayLabel {
    final d = description.trim();
    if (d.isEmpty || d == name) return name;
    return '$name — $d';
  }
}

/// Result of scanning for ESP-looking USB serial devices.
class PortScanResult {
  const PortScanResult({
    required this.allPorts,
    required this.espCandidates,
    this.autoPort,
  });

  final List<SerialPortInfo> allPorts;
  final List<SerialPortInfo> espCandidates;

  /// Set only when exactly one ESP-looking port exists.
  final SerialPortInfo? autoPort;

  bool get hasAuto => autoPort != null;
  bool get needsManual => !hasAuto;
}

/// Lists ports and applies ESP heuristics.
class SerialPortService {
  static final _espHints = RegExp(
    r'CH340|CP210|CP2102|CP210x|FTDI|FT232|Silicon Labs|USB[- ]?SERIAL|USB Serial|Espressif|UART',
    caseSensitive: false,
  );

  /// Scans [SerialPort.availablePorts] and classifies ESP candidates.
  PortScanResult scan() {
    final names = SerialPort.availablePorts;
    final all = <SerialPortInfo>[];
    for (final name in names) {
      String desc = '';
      try {
        final p = SerialPort(name);
        desc = p.description ?? '';
        // Some builds expose manufacturer / product separately.
        final mfg = p.manufacturer ?? '';
        final product = p.productName ?? '';
        if (desc.isEmpty) {
          desc = [mfg, product].where((s) => s.trim().isNotEmpty).join(' · ');
        }
      } catch (_) {
        desc = '';
      }
      all.add(SerialPortInfo(name: name, description: desc));
    }

    var esp = all.where((p) => _looksLikeEsp(p)).toList();
    // If nothing matched hints but exactly one USB serial exists, treat it as
    // the candidate (typical single-board lab PC).
    if (esp.isEmpty && all.length == 1) {
      esp = List.of(all);
    }

    SerialPortInfo? auto;
    if (esp.length == 1) auto = esp.first;

    return PortScanResult(
      allPorts: all,
      espCandidates: esp.isEmpty ? all : esp,
      autoPort: auto,
    );
  }

  bool _looksLikeEsp(SerialPortInfo p) {
    final blob = '${p.name} ${p.description}';
    return _espHints.hasMatch(blob);
  }
}
