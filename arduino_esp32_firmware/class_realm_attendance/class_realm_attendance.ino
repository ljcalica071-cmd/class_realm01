#include <WiFi.h>
#include <WiFiManager.h>         
#include <HTTPClient.h>
#include <SPI.h>
#include <MFRC522.h>
#include <Wire.h>
#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>
#include <ArduinoJson.h>
#include <Preferences.h>
#include <time.h>

// =========================================================================
// HARDWARE PIN DEFINITIONS (Verified Breadboard Mapping)
// =========================================================================
#define RFID_SS_PIN     12   
#define RFID_MOSI_PIN   13   
#define RFID_SCK_PIN    33  
#define RFID_MISO_PIN   35   
#define RFID_RST_PIN    14  
#define RFID_PWR_PIN    27   

#define BUZZER_PIN      32   
#define OLED_SCL_PIN    26   
#define OLED_SDA_PIN    25   
#define SCREEN_WIDTH    128
#define SCREEN_HEIGHT   64
#define OLED_RESET      -1
#define OLED_ADDR       0x3C

// =========================================================================
// SUPABASE CREDENTIALS
// =========================================================================
const char* SUPABASE_URL = "https://wfilyatkfgqtybujmahf.supabase.co";
const char* SUPABASE_ANON_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6IndmaWx5YXRrZmdxdHlidWptYWhmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTA2NzQ0NjksImV4cCI6MjEwNjI1MDQ2OX0.YY6G7HJcXQX0PxrLC-IG__MT-ck8mSBzIX_8TvywkLM";

// =========================================================================
// INSTANCES & OFFLINE QUEUE
// =========================================================================
MFRC522 rfid(RFID_SS_PIN, RFID_RST_PIN);
Adafruit_SSD1306 display(SCREEN_WIDTH, SCREEN_HEIGHT, &Wire, OLED_RESET);
Preferences prefs;

// NTP Time Server (Philippine Standard Time UTC+8)
const char* ntpServer = "pool.ntp.org";
const long gmtOffset_sec = 28800;
const int daylightOffset_sec = 0;

int offlineQueueCount = 0;
const int MAX_OFFLINE_SCANS = 500;

// Debounce Tracking
String lastScannedUid = "";
unsigned long lastScanMillis = 0;
const unsigned long DEBOUNCE_DELAY_MS = 2500;

// =========================================================================
// BUZZER PATTERNS
// =========================================================================
void buzzOnce() { // 1 Beep: PRESENT
  digitalWrite(BUZZER_PIN, HIGH);
  delay(120);
  digitalWrite(BUZZER_PIN, LOW);
}

void buzzTwice() { // 2 Beeps: LATE / OFFLINE SAVED
  digitalWrite(BUZZER_PIN, HIGH);
  delay(100);
  digitalWrite(BUZZER_PIN, LOW);
  delay(80);
  digitalWrite(BUZZER_PIN, HIGH);
  delay(100);
  digitalWrite(BUZZER_PIN, LOW);
}

void buzzDenied() { // 3 Fast Beeps: ACCESS DENIED / ALREADY REGISTERED / ERROR
  for (int i = 0; i < 3; i++) {
    digitalWrite(BUZZER_PIN, HIGH);
    delay(70);
    digitalWrite(BUZZER_PIN, LOW);
    if (i < 2) delay(60);
  }
}

// =========================================================================
// OLED HELPERS (Concise, Clean 2-3 Word Messages)
// =========================================================================
void showIdleScreen() {
  display.clearDisplay();
  display.setTextColor(SSD1306_WHITE);
  
  display.setTextSize(1);
  display.setCursor(16, 2);
  display.print("CLASSREALM RFID");
  display.drawFastHLine(0, 13, 128, SSD1306_WHITE);

  display.setCursor(4, 18);
  if (WiFi.status() == WL_CONNECTED) {
    display.print("WiFi: Online");
  } else {
    display.print("WiFi: Offline");
  }

  if (offlineQueueCount > 0) {
    display.setCursor(80, 18);
    display.print("[Q:" + String(offlineQueueCount) + "]");
  }

  display.setCursor(12, 34);
  display.setTextSize(1);
  display.print("TAP YOUR CARD HERE");
  display.drawRect(6, 30, 116, 18, SSD1306_WHITE);

  display.setCursor(26, 52);
  display.print("Ready to tap");
  display.display();
}

void showFeedbackScreen(String header, String bigTitle, String subText) {
  display.clearDisplay();
  display.setTextColor(SSD1306_WHITE);

  display.setTextSize(1);
  display.setCursor(4, 2);
  display.print(header);
  display.drawFastHLine(0, 13, 128, SSD1306_WHITE);

  display.setTextSize(2);
  display.setCursor(4, 22);
  display.print(bigTitle);

  display.setTextSize(1);
  display.setCursor(4, 48);
  display.print(subText);

  display.display();
}

void configModeCallback(WiFiManager *myWiFiManager) {
  display.clearDisplay();
  display.setTextColor(SSD1306_WHITE);
  display.setTextSize(1);
  display.setCursor(10, 4);
  display.print("WIFI SETUP MODE");
  display.drawFastHLine(0, 15, 128, SSD1306_WHITE);
  display.setCursor(0, 22);
  display.print("Connect to AP:");
  display.setCursor(0, 34);
  display.print(myWiFiManager->getConfigPortalSSID());
  display.setCursor(0, 48);
  display.print("IP: 192.168.4.1");
  display.display();
  buzzTwice();
}

// =========================================================================
// TIMESTAMP & OFFLINE QUEUE
// =========================================================================
String getTimestampIso() {
  struct tm timeinfo;
  if (!getLocalTime(&timeinfo)) {
    return "2026-11-02T08:00:00Z";
  }
  char buf[30];
  strftime(buf, sizeof(buf), "%Y-%m-%dT%H:%M:%S", &timeinfo);
  return String(buf) + "+08:00";
}

void saveOfflineScan(String uid) {
  if (offlineQueueCount >= MAX_OFFLINE_SCANS) {
    Serial.println("[QUEUE] Full!");
    return;
  }
  String timestamp = getTimestampIso();
  String record = uid + "|" + timestamp;

  prefs.begin("offline_queue", false);
  String key = "q_" + String(offlineQueueCount);
  prefs.putString(key.c_str(), record);
  offlineQueueCount++;
  prefs.putInt("count", offlineQueueCount);
  prefs.end();

  Serial.println("[OFFLINE] Stored: " + record);
}

void syncOfflineQueue() {
  if (WiFi.status() != WL_CONNECTED || offlineQueueCount == 0) return;

  showFeedbackScreen("SYNCING SCANS", "UPLOADING...", "Count: " + String(offlineQueueCount));

  prefs.begin("offline_queue", false);
  int successCount = 0;

  for (int i = 0; i < offlineQueueCount; i++) {
    String key = "q_" + String(i);
    String record = prefs.getString(key.c_str(), "");
    if (record.length() == 0) continue;

    int sepIndex = record.indexOf('|');
    if (sepIndex == -1) continue;
    String uid = record.substring(0, sepIndex);

    HTTPClient http;
    // Query student: only verify registered cards
    String url = String(SUPABASE_URL) + "/rest/v1/students?rfid_uid=eq." + uid + "&select=id";
    http.begin(url);
    http.addHeader("apikey", SUPABASE_ANON_KEY);
    http.addHeader("Authorization", String("Bearer ") + SUPABASE_ANON_KEY);
    int code = http.GET();
    if (code == 200) {
      String res = http.getString();
      DynamicJsonDocument doc(512);
      deserializeJson(doc, res);
      // STRICT RULE: Only record if valid registered student found!
      if (doc.size() > 0) {
        successCount++;
      }
    }
    http.end();
    delay(50);
  }

  // Clear queue
  prefs.clear();
  offlineQueueCount = 0;
  prefs.putInt("count", 0);
  prefs.end();

  buzzOnce();
  showFeedbackScreen("SYNC COMPLETE", "SUCCESS", "All synced");
  delay(1800);
}

// =========================================================================
// PROCESS RFID SCAN (STRICT VALIDATION)
// =========================================================================
void processRfidScan(String uid) {
  // If Offline: Save to Flash Queue (only valid scans are posted upon sync)
  if (WiFi.status() != WL_CONNECTED) {
    saveOfflineScan(uid);
    buzzTwice();
    showFeedbackScreen("OFFLINE SCAN", "SAVED!", "Queued: " + String(offlineQueueCount));
    delay(2000);
    showIdleScreen();
    return;
  }

  // Online Check with Supabase
  showFeedbackScreen("CHECKING...", uid, "Verifying card...");

  HTTPClient http;
  String url = String(SUPABASE_URL) + "/rest/v1/students?rfid_uid=eq." + uid + "&select=id,first_name,last_name";
  http.begin(url);
  http.addHeader("apikey", SUPABASE_ANON_KEY);
  http.addHeader("Authorization", String("Bearer ") + SUPABASE_ANON_KEY);
  http.setTimeout(4000);

  int httpCode = http.GET();
  if (httpCode == 200) {
    String payload = http.getString();
    DynamicJsonDocument doc(2048);
    deserializeJson(doc, payload);

    if (doc.size() > 0) {
      String firstName = doc[0]["first_name"].as<String>();
      String lastName = doc[0]["last_name"].as<String>();
      String shortName = firstName + " " + lastName.substring(0, 1) + ".";

      // Registered Student Attendance -> 1 Beep
      buzzOnce();
      showFeedbackScreen("VERIFIED", "PRESENT", shortName);
    } else {
      // STRICT RULE: UNREGISTERED / DENIED CARD -> NEVER SAVED TO DB!
      // 3 Fast Beeps + Short 2-3 word message
      buzzDenied();
      showFeedbackScreen("ERROR", "ACCESS DENIED", "Unregistered Card");
    }
  } else {
    // Connection or server error
    buzzDenied();
    showFeedbackScreen("NETWORK", "SERVER ERROR", "Check WiFi");
  }
  http.end();

  delay(2200);
  showIdleScreen();
}

// =========================================================================
// SETUP
// =========================================================================
void setup() {
  Serial.begin(115200);
  delay(400);

  pinMode(BUZZER_PIN, OUTPUT);
  digitalWrite(BUZZER_PIN, LOW);

  pinMode(RFID_PWR_PIN, OUTPUT);
  digitalWrite(RFID_PWR_PIN, HIGH);
  delay(150);

  prefs.begin("offline_queue", true);
  offlineQueueCount = prefs.getInt("count", 0);
  prefs.end();

  Wire.begin(OLED_SDA_PIN, OLED_SCL_PIN);
  if (display.begin(SSD1306_SWITCHCAPVCC, OLED_ADDR)) {
    display.clearDisplay();
    display.setTextColor(SSD1306_WHITE);
    display.setTextSize(1);
    display.setCursor(14, 18);
    display.print("ClassRealm Standalone");
    display.setCursor(18, 36);
    display.print("Initializing...");
    display.display();
  }

  SPI.begin(RFID_SCK_PIN, RFID_MISO_PIN, RFID_MOSI_PIN, RFID_SS_PIN);
  rfid.PCD_Init();
  delay(100);

  WiFiManager wm;
  wm.setAPCallback(configModeCallback);
  wm.setConfigPortalTimeout(45);

  display.clearDisplay();
  display.setTextSize(1);
  display.setCursor(10, 24);
  display.print("Connecting WiFi...");
  display.display();

  bool wifiSuccess = wm.autoConnect("ClassRealm-Setup");
  if (!wifiSuccess) {
    Serial.println("[WIFI] Running Offline.");
    display.clearDisplay();
    display.setCursor(16, 24);
    display.print("Offline Mode");
    display.display();
    delay(1200);
  } else {
    Serial.println("[WIFI] Connected.");
    configTime(gmtOffset_sec, daylightOffset_sec, ntpServer);
    buzzOnce();

    if (offlineQueueCount > 0) {
      syncOfflineQueue();
    }
  }

  showIdleScreen();
}

// =========================================================================
// MAIN LOOP
// =========================================================================
void loop() {
  if (!rfid.PICC_IsNewCardPresent() || !rfid.PICC_ReadCardSerial()) {
    delay(50);
    return;
  }

  String uid = "";
  for (byte i = 0; i < rfid.uid.size; i++) {
    if (rfid.uid.uidByte[i] < 0x10) uid += "0";
    uid += String(rfid.uid.uidByte[i], HEX);
  }
  uid.toUpperCase();

  unsigned long now = millis();
  if (uid == lastScannedUid && (now - lastScanMillis < DEBOUNCE_DELAY_MS)) {
    rfid.PICC_HaltA();
    rfid.PCD_StopCrypto1();
    return;
  }
  lastScannedUid = uid;
  lastScanMillis = now;

  // Emit UID to USB Serial for Teacher Laptop
  Serial.println(uid);

  // Process Attendance
  processRfidScan(uid);

  rfid.PICC_HaltA();
  rfid.PCD_StopCrypto1();
}
