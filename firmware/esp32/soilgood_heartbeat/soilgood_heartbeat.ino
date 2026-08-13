// SoilGood ESP32 heartbeat — WiFi + HTTPS POST to ingest_soil_reading.
// Dummy reading (no soil sensor yet). Copy secrets.h.example → secrets.h first.

#include <WiFi.h>
#include <WiFiClientSecure.h>
#include <HTTPClient.h>
#include "secrets.h"

// First test: 30s so Home updates quickly. Later: 15 minutes = 900000UL
const unsigned long POST_EVERY_MS = 30000UL;

void setup() {
  Serial.begin(115200);
  delay(1000);

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
}

void loop() {
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("WiFi lost");
    delay(2000);
    return;
  }

  // Dummy heartbeat — real Modbus values replace these after 12V sensor works
  String body = "{";
  body += "\"p_device_uid\":\"";
  body += DEVICE_UID;
  body += "\",\"p_ingest_token\":\"";
  body += INGEST_TOKEN;
  body += "\",\"p_moisture_percent\":0";
  body += ",\"p_validation_status\":\"ok\"";
  body += ",\"p_validation_message\":\"esp32 heartbeat (no soil sensor yet)\"";
  body += "}";

  String url = String(SUPABASE_URL) + "/rest/v1/rpc/ingest_soil_reading";

  WiFiClientSecure client;
  client.setInsecure();  // TLS encrypts; skip cert pin for first bench test

  HTTPClient http;
  http.begin(client, url);
  http.addHeader("apikey", SUPABASE_ANON_KEY);
  http.addHeader("Authorization", String("Bearer ") + SUPABASE_ANON_KEY);
  http.addHeader("Content-Type", "application/json");

  int code = http.POST(body);
  Serial.print("POST ");
  Serial.print(code);
  Serial.print(" ");
  Serial.println(http.getString());
  http.end();

  delay(POST_EVERY_MS);
}
