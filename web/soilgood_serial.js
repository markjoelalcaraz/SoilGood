/**
 * SoilGood Web Serial bridge — Option B flash from Chrome Admin.
 * Speaks SGCFG line protocol with soilgood_heartbeat firmware (115200).
 */
(function () {
  'use strict';

  let port = null;
  let reader = null;
  let readLoopPromise = null;
  let rxBuffer = '';
  let keepReading = false;

  function isSupported() {
    return typeof navigator !== 'undefined' && 'serial' in navigator;
  }

  function portLabel() {
    if (!port) return '';
    try {
      const info = port.getInfo ? port.getInfo() : {};
      const vid = info.usbVendorId != null ? info.usbVendorId.toString(16) : '';
      const pid = info.usbProductId != null ? info.usbProductId.toString(16) : '';
      if (vid || pid) return 'USB ' + vid + ':' + pid;
    } catch (_) {}
    return 'USB serial port';
  }

  async function stopReading() {
    keepReading = false;
    try {
      if (reader) {
        await reader.cancel().catch(function () {});
        reader.releaseLock();
      }
    } catch (_) {}
    reader = null;
    if (readLoopPromise) {
      await readLoopPromise.catch(function () {});
      readLoopPromise = null;
    }
  }

  async function startReading() {
    if (!port || !port.readable) return;
    keepReading = true;
    const textDecoder = new TextDecoderStream();
    const readableStreamClosed = port.readable.pipeTo(textDecoder.writable);
    reader = textDecoder.readable.getReader();
    readLoopPromise = (async function () {
      try {
        while (keepReading) {
          const result = await reader.read();
          if (result.done) break;
          if (result.value) rxBuffer += result.value;
        }
      } catch (_) {
        // Port closed / cancelled.
      } finally {
        try {
          reader.releaseLock();
        } catch (_) {}
        await readableStreamClosed.catch(function () {});
      }
    })();
  }

  async function requestPort() {
    if (!isSupported()) {
      throw new Error('Web Serial not supported. Use Chrome/Edge on desktop.');
    }
    await close();
    port = await navigator.serial.requestPort();
    return portLabel();
  }

  async function open(baudRate) {
    if (!port) throw new Error('No serial port selected. Click Connect board first.');
    if (port.readable || port.writable) {
      // Already open.
    } else {
      await port.open({ baudRate: baudRate || 115200 });
    }
    rxBuffer = '';
    await startReading();
    return portLabel();
  }

  async function writeLine(line) {
    if (!port || !port.writable) {
      throw new Error('Serial port is not open.');
    }
    const writer = port.writable.getWriter();
    try {
      const data = new TextEncoder().encode(line.endsWith('\n') ? line : line + '\n');
      await writer.write(data);
    } finally {
      writer.releaseLock();
    }
  }

  function bufferContains(token) {
    return rxBuffer.indexOf(token) !== -1;
  }

  async function waitForToken(token, timeoutMs) {
    const start = Date.now();
    const limit = timeoutMs || 25000;
    while (Date.now() - start < limit) {
      if (bufferContains('SGCFG_ERR')) {
        throw new Error('Board rejected config (SGCFG_ERR).');
      }
      if (bufferContains(token)) return true;
      await new Promise(function (r) {
        setTimeout(r, 50);
      });
    }
    throw new Error(
      'No ' +
        token +
        ' within ' +
        Math.round(limit / 1000) +
        's. Reset ESP32 (EN), close other Serial Monitors, retry.'
    );
  }

  async function close() {
    await stopReading();
    if (port) {
      try {
        await port.close();
      } catch (_) {}
    }
    port = null;
    rxBuffer = '';
  }

  function hasPort() {
    return port != null;
  }

  function loadWifi() {
    try {
      return {
        ssid: localStorage.getItem('soilgood_lab_wifi_ssid') || '',
        password: localStorage.getItem('soilgood_lab_wifi_password') || '',
      };
    } catch (_) {
      return { ssid: '', password: '' };
    }
  }

  function saveWifi(ssid, password) {
    try {
      localStorage.setItem('soilgood_lab_wifi_ssid', ssid || '');
      localStorage.setItem('soilgood_lab_wifi_password', password || '');
    } catch (_) {}
  }

  window.SoilGoodSerial = {
    isSupported: isSupported,
    requestPort: requestPort,
    open: open,
    writeLine: writeLine,
    waitForToken: waitForToken,
    close: close,
    hasPort: hasPort,
    portLabel: portLabel,
    loadWifi: loadWifi,
    saveWifi: saveWifi,
  };
})();
