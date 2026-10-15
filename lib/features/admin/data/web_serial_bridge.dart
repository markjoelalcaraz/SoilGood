/// Conditional export: Web Serial bridge (Chrome Admin Option B).
library;

export 'web_serial_bridge_stub.dart'
    if (dart.library.html) 'web_serial_bridge_web.dart';
