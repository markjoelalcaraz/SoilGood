// SoilGood — THE01888S Modbus read + HTTPS POST to ingest_soil_reading.
// Needs secrets.h (WiFi, DEVICE_UID, INGEST_TOKEN, SUPABASE_URL, SUPABASE_ANON_KEY).
// USB Serial 115200. Sensor Serial2 9600 on D16/D17 via MAX485.

#include <WiFi.h>
#include <WiFiClientSecure.h>
#include <HTTPClient.h>
#include "secrets.h"

#define RXD2 16
#define TXD2 17
#define DE_PIN 4
#define RE_PIN 5

// Farm default: ~15 minutes between successful reads/POSTs.
// Bench debug only: temporarily use 30000UL (30s) for POST_EVERY_MS.
const unsigned long POST_EVERY_MS = 900000UL;
// Modbus fail: retry soon — do not wait a full farm interval.
const unsigned long RETRY_FAIL_MS = 10000UL;

void rs485Speak(bool speak) {
  digitalWrite(DE_PIN, speak ? HIGH : LOW);
  digitalWrite(RE_PIN, speak ? HIGH : LOW);
}

int16_t asSigned(uint16_t u) { return (int16_t)u; }

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

// Returns true if a full 8-register frame was decoded into the floats.
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
  // JSON keys must match RPC arg names (p_...)
  String body = "{";
  body += "\"p_device_uid\":\"";
  body += DEVICE_UID;
  body += "\",\"p_ingest_token\":\"";
  body += INGEST_TOKEN;
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

  String url = String(SUPABASE_URL) + "/rest/v1/rpc/ingest_soil_reading";

  WiFiClientSecure client;
  client.setInsecure();

  HTTPClient http;
  http.begin(client, url);
  http.addHeader("apikey", SUPABASE_ANON_KEY);
  http.addHeader("Authorization", String("Bearer ") + SUPABASE_ANON_KEY);
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
  delay(1000);
  Serial2.begin(9600, SERIAL_8N1, RXD2, TXD2);

  WiFi.mode(WIFI_STA);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
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

  // Cheap probe pH is often weak; flag out-of-band for farmers.
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
