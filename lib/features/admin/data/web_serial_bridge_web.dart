/// Chrome Web Serial bridge for Admin Option B (SGCFG inject).
///
/// Talks to `web/soilgood_serial.js`. Used only from Flutter web Admin
/// Devices — not the Windows Lab Flasher backup tool.
library;

import 'dart:convert';
import 'dart:js_interop';

/// Lab WiFi pair remembered in the browser.
class LabWifiCredentials {
  const LabWifiCredentials({required this.ssid, required this.password});

  final String ssid;
  final String password;
}

@JS('SoilGoodSerial')
external _SoilGoodSerialJs get _serial;

extension type _SoilGoodSerialJs._(JSObject _) implements JSObject {
  external bool isSupported();
  external JSPromise<JSString> requestPort();
  external JSPromise<JSString> open(int baudRate);
  external JSPromise<JSAny?> writeLine(String line);
  external JSPromise<JSAny?> waitForToken(String token, int timeoutMs);
  external JSPromise<JSAny?> close();
  external bool hasPort();
  external String portLabel();
  external _WifiJs loadWifi();
  external void saveWifi(String ssid, String password);
}

extension type _WifiJs._(JSObject _) implements JSObject {
  external String get ssid;
  external String get password;
}

/// Thin Dart wrapper around [window.SoilGoodSerial].
class WebSerialBridge {
  bool get isSupported {
    try {
      return _serial.isSupported();
    } catch (_) {
      return false;
    }
  }

  bool get hasPort {
    try {
      return _serial.hasPort();
    } catch (_) {
      return false;
    }
  }

  String get portLabel {
    try {
      return _serial.portLabel();
    } catch (_) {
      return '';
    }
  }

  /// Browser picker (must run from a user gesture).
  Future<String> requestPort() async {
    final js = await _serial.requestPort().toDart;
    return js.toDart;
  }

  Future<void> open({int baudRate = 115200}) async {
    await _serial.open(baudRate).toDart;
  }

  Future<void> writeLine(String line) async {
    await _serial.writeLine(line).toDart;
  }

  Future<void> waitForToken(String token, {int timeoutMs = 25000}) async {
    await _serial.waitForToken(token, timeoutMs).toDart;
  }

  Future<void> close() async {
    try {
      await _serial.close().toDart;
    } catch (_) {}
  }

  LabWifiCredentials loadWifi() {
    try {
      final w = _serial.loadWifi();
      return LabWifiCredentials(ssid: w.ssid, password: w.password);
    } catch (_) {
      return const LabWifiCredentials(ssid: '', password: '');
    }
  }

  void saveWifi({required String ssid, required String password}) {
    try {
      _serial.saveWifi(ssid, password);
    } catch (_) {}
  }

  /// Opens @ 115200, sends `SGCFG|{json}|`, waits for OK, closes.
  Future<void> injectConfig(Map<String, String> config) async {
    await open(baudRate: 115200);
    try {
      final jsonBody = jsonEncode(config);
      await writeLine('SGCFG|$jsonBody|');
      await waitForToken('SGCFG_OK', timeoutMs: 25000);
    } finally {
      await close();
    }
  }
}
