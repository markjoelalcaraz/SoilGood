/// Opens a COM port, sends SGCFG JSON, waits for SGCFG_OK from firmware.
///
/// "Flash" in Lab Flasher v1 means serial credential inject into shared
/// firmware already on the board (Preferences/NVS). Not a full esptool
/// binary rewrite — base sketch is uploaded once via Arduino IDE.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_libserialport/flutter_libserialport.dart';

/// Builds and sends one SGCFG line; returns when the board ACKs or times out.
class SerialConfigInjector {
  /// Injects credentials at [portName] (115200 8N1).
  ///
  /// [onLog] receives short status lines for the optional details panel.
  Future<void> inject({
    required String portName,
    required Map<String, String> config,
    required void Function(String line) onLog,
    Duration timeout = const Duration(seconds: 25),
  }) async {
    final port = SerialPort(portName);
    if (!port.openReadWrite()) {
      final err = SerialPort.lastError;
      throw StateError(
        'Could not open $portName'
        '${err != null ? ': ${err.message}' : ''}. '
        'Close Arduino Serial Monitor and retry.',
      );
    }

    SerialPortReader? reader;
    SerialPortConfig? config;
    try {
      config = SerialPortConfig()
        ..baudRate = 115200
        ..bits = 8
        ..stopBits = 1
        ..parity = SerialPortParity.none;
      config.setFlowControl(SerialPortFlowControl.none);
      port.config = config;

      reader = SerialPortReader(port);
      final buffer = StringBuffer();
      final ok = Completer<void>();
      late final StreamSubscription<Uint8List> sub;

      sub = reader.stream.listen((data) {
        buffer.write(utf8.decode(data, allowMalformed: true));
        final text = buffer.toString();
        if (text.contains('SGCFG_OK')) {
          if (!ok.isCompleted) ok.complete();
        } else if (text.contains('SGCFG_ERR')) {
          if (!ok.isCompleted) {
            ok.completeError(
              StateError('Board rejected config (SGCFG_ERR). Check JSON fields.'),
            );
          }
        }
      });

      // Give a freshly reset board a moment; firmware prints SGCFG_WAIT ~20s.
      await Future<void>.delayed(const Duration(milliseconds: 400));

      final jsonBody = jsonEncode(config);
      final line = 'SGCFG|$jsonBody|\n';
      onLog('TX SGCFG (${jsonBody.length} chars)');
      final written = port.write(Uint8List.fromList(utf8.encode(line)));
      if (written <= 0) {
        throw StateError('Write to $portName failed (0 bytes).');
      }

      try {
        await ok.future.timeout(timeout);
        onLog('RX SGCFG_OK');
      } on TimeoutException {
        throw StateError(
          'No SGCFG_OK within ${timeout.inSeconds}s. '
          'Reset the ESP32 (EN) so it prints SGCFG_WAIT, then retry. '
          'Base firmware must include the SGCFG listener.',
        );
      } finally {
        await sub.cancel();
      }
    } finally {
      reader?.close();
      config?.dispose();
      if (port.isOpen) port.close();
      port.dispose();
    }
  }
}
