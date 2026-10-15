// SoilGood — THE01888S Modbus read + HTTPS POST to ingest_soil_reading.
// Credentials: Preferences (NVS) preferred; secrets.h used as bench fallback.
// Lab Flasher sends one line: SGCFG|{json}| then board replies SGCFG_OK and reboots.
// USB Serial 115200. Sensor Serial2 9600 on D16/D17 via MAX485.

#include <WiFi.h>
#include <WiFiClientSecure.h>
#include <HTTPClient.h>
#include <Preferences.h>
#include <ArduinoJson.h>
#include "secrets.h"

#define RXD2 16
#define TXD2 17
#define DE_PIN 4
#define RE_PIN 5

// Farm default: ~15 minutes between successful reads/POSTs.
const unsigned long POST_EVERY_MS = 1000UL;
const unsigned long RETRY_FAIL_MS = 2000UL;
// Listen for Lab Flasher config after boot.
const unsigned long CONFIG_WINDOW_MS = 20000UL;

Preferences prefs;

String gDeviceUid;
String gIngestToken;
String gWifiSsid;
String gWifiPassword;
String gSupabaseUrl;
String gSupabaseAnon;

void rs485Speak(bool speak) {
  digitalWrite(DE_PIN, speak ? HIGH : LOW);
  digitalWrite(RE_PIN, speak ? HIGH : LOW);
}

int16_t asSigned(uint16_t u) { return (int16_t)u; }

// Loads NVS; falls back to secrets.h compile-time defaults for bench.
bool loadConfig() {
  prefs.begin("soilgood", true);
  gDeviceUid = prefs.getString("device_uid", "");
  gIngestToken = prefs.getString("ingest_token", "");
  gWifiSsid = prefs.getString("wifi_ssid", "");
  gWifiPassword = prefs.getString("wifi_password", "");
  gSupabaseUrl = prefs.getString("supabase_url", "");
  gSupabaseAnon = prefs.getString("supabase_anon", "");
  prefs.end();

  if (gDeviceUid.length() == 0) gDeviceUid = DEVICE_UID;
  if (gIngestToken.length() == 0) gIngestToken = INGEST_TOKEN;
  if (gWifiSsid.length() == 0) gWifiSsid = WIFI_SSID;
  if (gWifiPassword.length() == 0) gWifiPassword = WIFI_PASSWORD;
  if (gSupabaseUrl.length() == 0) gSupabaseUrl = SUPABASE_URL;
  if (gSupabaseAnon.length() == 0) gSupabaseAnon = SUPABASE_ANON_KEY;

  return gDeviceUid.length() > 0 && gIngestToken.length() >= 8
      && gWifiSsid.length() > 0 && gSupabaseUrl.length() > 0
      && gSupabaseAnon.length() > 0;
}

// Persists Lab Flasher JSON into Preferences (NVS).
bool saveConfigFromJson(const String& json) {
  StaticJsonDocument<768> doc;
  DeserializationError err = deserializeJson(doc, json);
  if (err) return false;

  const char* uid = doc["device_uid"] | "";
  const char* token = doc["ingest_token"] | "";
  const char* ssid = doc["wifi_ssid"] | "";
  const char* pass = doc["wifi_password"] | "";
  const char* url = doc["supabase_url"] | "";
  const char* anon = doc["supabase_anon"] | "";

  if (strlen(uid) == 0 || strlen(token) < 8) return false;

  prefs.begin("soilgood", false);
  prefs.putString("device_uid", uid);
  prefs.putString("ingest_token", token);
  if (strlen(ssid) > 0) prefs.putString("wifi_ssid", ssid);
  if (strlen(pass) > 0) prefs.putString("wifi_password", pass);
  if (strlen(url) > 0) prefs.putString("supabase_url", url);
  if (strlen(anon) > 0) prefs.putString("supabase_anon", anon);
  prefs.end();
  return true;
}

// Lines look like: SGCFG|{...}|
void tryConsumeConfigLine(const String& line) {
  if (!line.startsWith("SGCFG|")) return;
  int end = line.lastIndexOf('|');
  if (end <= 6) return;
  String json = line.substring(6, end);
  if (saveConfigFromJson(json)) {
    Serial.println("SGCFG_OK");
    delay(200);
    ESP.restart();
  } else {
    Serial.println("SGCFG_ERR");
  }
}

void pollConfigSerial(unsigned long windowMs) {
  Serial.println("SGCFG_WAIT");
  unsigned long start = millis();
  String buf;
  while (millis() - start < windowMs) {
    while (Serial.available()) {
      char c = (char)Serial.read();
      if (c == '\n' || c == '\r') {
        if (buf.length() > 0) {
          tryConsumeConfigLine(buf);
          buf = "";
        }
      } else {
        buf += c;
        if (buf.length() > 700) buf = "";
      }
    }
    delay(5);
  }
}

int readFrame(byte* buf, int maxLen) {
  while (Serial2.available()) Serial2.read();

  byte ask[] = {0x01, 0x03, 0x00, 0x00, 0x00, 0x08, 0x44, 0x0C};

  rs485Speak(true);
  delay(10);
  Serial2.write(ask, sizeof(ask));
  Serial2.flush();
  delay(10);
  rs485Speak(false);
  delay(200);

  int n = 0;
  unsigned long t = millis();
  while (millis() - t < 400 && n < maxLen) {
    if (Serial2.available()) {
      buf[n++] = Serial2.read();
      t = millis();
    }
  }
  return n;
}

int find0103(byte* buf, int n) {
  for (int i = 0; i + 1 < n; i++) {
    if (buf[i] == 0x01 && buf[i + 1] == 0x03) return i;
  }
  return -1;
}

bool readSoil(
  float& temperatureC,
  float& moisturePct,
  float& salinity,
  float& ec,
  float& ph,
  float& nitrogen,
  float& phosphorus,
  float& potassium
) {
  byte buf[64];
  int found = -1;
  int n = 0;

  for (int tryN = 0; tryN < 5; tryN++) {
    n = readFrame(buf, 64);
    found = find0103(buf, n);
    if (found >= 0 && found + 4 < n && buf[found + 2] == 0x10) break;
    found = -1;
    delay(100);
  }
  if (found < 0) return false;

  int data = found + 3;
  uint16_t r0 = (buf[data + 0] << 8) | buf[data + 1];
  uint16_t r1 = (buf[data + 2] << 8) | buf[data + 3];
  uint16_t r2 = (buf[data + 4] << 8) | buf[data + 5];
  uint16_t r3 = (buf[data + 6] << 8) | buf[data + 7];
  uint16_t r4 = (buf[data + 8] << 8) | buf[data + 9];
  uint16_t r5 = (buf[data + 10] << 8) | buf[data + 11];
  uint16_t r6 = (buf[data + 12] << 8) | buf[data + 13];
  uint16_t r7 = (buf[data + 14] << 8) | buf[data + 15];

  temperatureC = asSigned(r0) / 10.0;
  moisturePct = r1 / 10.0;
  salinity = r2;
  ec = r3;
  ph = r4 / 100.0;
  nitrogen = r5;
  phosphorus = r6;
  potassium = r7;
  return true;
}

bool postReading(
  float moisturePct,
  float ph,
  float temperatureC,
  float ec,
  float salinity,
  float nitrogen,
  float phosphorus,
  float potassium,
  const char* status,
  const char* message
) {
  String body = "{";
  body += "\"p_device_uid\":\"";
  body += gDeviceUid;
  body += "\",\"p_ingest_token\":\"";
  body += gIngestToken;
  body += "\",\"p_moisture_percent\":";
  body += String(moisturePct, 1);
  body += ",\"p_ph\":";
  body += String(ph, 2);
  body += ",\"p_soil_temperature_c\":";
  body += String(temperatureC, 1);
  body += ",\"p_ec\":";
  body += String(ec, 0);
  body += ",\"p_salinity\":";
  body += String(salinity, 0);
  body += ",\"p_nitrogen\":";
  body += String(nitrogen, 0);
  body += ",\"p_phosphorus\":";
  body += String(phosphorus, 0);
  body += ",\"p_potassium\":";
  body += String(potassium, 0);
  body += ",\"p_validation_status\":\"";
  body += status;
  body += "\",\"p_validation_message\":\"";
  body += message;
  body += "\"}";

  String url = gSupabaseUrl + "/rest/v1/rpc/ingest_soil_reading";

  WiFiClientSecure client;
  client.setInsecure();

  HTTPClient http;
  http.begin(client, url);
  http.addHeader("apikey", gSupabaseAnon);
  http.addHeader("Authorization", String("Bearer ") + gSupabaseAnon);
  http.addHeader("Content-Type", "application/json");
  http.addHeader("Prefer", "return=representation");

  int code = http.POST(body);
  Serial.print("POST ");
  Serial.print(code);
  Serial.print(" ");
  Serial.println(http.getString());
  http.end();
  return code == 200;
}

void setup() {
  pinMode(DE_PIN, OUTPUT);
  pinMode(RE_PIN, OUTPUT);
  rs485Speak(false);

  Serial.begin(115200);
  delay(800);
  Serial2.begin(9600, SERIAL_8N1, RXD2, TXD2);

  // Lab Flasher window: accept credentials before WiFi connect.
  pollConfigSerial(CONFIG_WINDOW_MS);

  if (!loadConfig()) {
    Serial.println("Config missing — use Lab Flasher or fill secrets.h");
    return;
  }

  Serial.print("device_uid ");
  Serial.println(gDeviceUid);

  WiFi.mode(WIFI_STA);
  WiFi.begin(gWifiSsid.c_str(), gWifiPassword.c_str());
  Serial.print("WiFi ");
  int tries = 0;
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
    Serial.print(".");
    if (++tries > 40) {
      Serial.println(" failed");
      return;
    }
  }
  Serial.println(" OK");
  Serial.println(WiFi.localIP());
  delay(2000);
}

void loop() {
  // Keep accepting re-flash / re-provision over USB while running.
  while (Serial.available()) {
    static String liveBuf;
    char c = (char)Serial.read();
    if (c == '\n' || c == '\r') {
      if (liveBuf.length() > 0) {
        tryConsumeConfigLine(liveBuf);
        liveBuf = "";
      }
    } else {
      liveBuf += c;
      if (liveBuf.length() > 700) liveBuf = "";
    }
  }

  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("WiFi lost");
    delay(2000);
    return;
  }

  float temperatureC, moisturePct, salinity, ec, ph, nitrogen, phosphorus, potassium;
  if (!readSoil(temperatureC, moisturePct, salinity, ec, ph, nitrogen, phosphorus, potassium)) {
    Serial.println("No Modbus frame — skip POST, retry soon");
    delay(RETRY_FAIL_MS);
    return;
  }

  Serial.println("----------");
  Serial.print("Temp C:      "); Serial.println(temperatureC, 1);
  Serial.print("Moisture %:  "); Serial.println(moisturePct, 1);
  Serial.print("Salinity:    "); Serial.println(salinity, 0);
  Serial.print("EC:          "); Serial.println(ec, 0);
  Serial.print("pH:          "); Serial.println(ph, 2);
  Serial.print("N mg/kg:     "); Serial.println(nitrogen, 0);
  Serial.print("P mg/kg:     "); Serial.println(phosphorus, 0);
  Serial.print("K mg/kg:     "); Serial.println(potassium, 0);

  const char* status = "ok";
  const char* message = "THE01888S live reading";
  if (ph < 3.0 || ph > 10.0) {
    status = "warning";
    message = "pH out of typical soil band — treat as unreliable";
  }

  postReading(
    moisturePct, ph, temperatureC, ec, salinity,
    nitrogen, phosphorus, potassium,
    status, message
  );

  delay(POST_EVERY_MS);
}
