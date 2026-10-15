/// Stub Web Serial API for non-web targets (analyzer / mobile).
///
/// Real implementation is [web_serial_bridge_web.dart] on Flutter web.
library;

/// Lab WiFi pair remembered in the browser (web only).
class LabWifiCredentials {
  const LabWifiCredentials({required this.ssid, required this.password});

  final String ssid;
  final String password;
}

/// No-op / fail-closed serial bridge outside Chrome.
class WebSerialBridge {
  bool get isSupported => false;

  bool get hasPort => false;

  String get portLabel => '';

  Future<String> requestPort() async {
    throw UnsupportedError(
      'Web Serial works only in Chrome/Edge Admin (flutter run -d chrome).',
    );
  }

  Future<void> open({int baudRate = 115200}) async {
    throw UnsupportedError('Web Serial is web-only.');
  }

  Future<void> writeLine(String line) async {
    throw UnsupportedError('Web Serial is web-only.');
  }

  Future<void> waitForToken(String token, {int timeoutMs = 25000}) async {
    throw UnsupportedError('Web Serial is web-only.');
  }

  Future<void> close() async {}

  LabWifiCredentials loadWifi() =>
      const LabWifiCredentials(ssid: '', password: '');

  void saveWifi({required String ssid, required String password}) {}

  /// Opens port, sends SGCFG JSON line, waits for SGCFG_OK, then closes.
  Future<void> injectConfig(Map<String, String> config) async {
    throw UnsupportedError('Web Serial is web-only.');
  }
}
