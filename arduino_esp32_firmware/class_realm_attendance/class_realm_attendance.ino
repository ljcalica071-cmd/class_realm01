#include <WiFi.h>
#include <WiFiManager.h>          // Dynamic portal with password protection
#include <HTTPClient.h>
#include <SPI.h>
#include <MFRC522.h>
#include <Wire.h>
#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>
#include <Preferences.h>
#include <time.h>

// =========================================================================
// HARDWARE PIN DEFINITIONS (Verified Breadboard Mapping)
// =========================================================================
#define RFID_SS_PIN     12   // RC522 SDA/SS (Row A, Col 12)
#define RFID_MOSI_PIN   13   // RC522 MOSI   (Row A, Col 13)
#define RFID_SCK_PIN    33   // RC522 SCK    (Row A, Col 10)
#define RFID_MISO_PIN   35   // RC522 MISO   (Row A, Col 8)
#define RFID_RST_PIN    14   // RC522 RST    (Row A, Col 11)
#define RFID_PWR_PIN    27   // RC522 3.3V   (Row A, Col 5)

#define BUZZER_PIN      32   // Active Buzzer (Row A, Col 9)

#define OLED_SCL_PIN    26   // I2C SCL (Row A, Col 6)
#define OLED_SDA_PIN    25   // I2C SDA (Row A, Col 7)
#define SCREEN_WIDTH    128
#define SCREEN_HEIGHT   64
#define OLED_RESET      -1
#define OLED_ADDR       0x3C

// =========================================================================
// SUPABASE CREDENTIALS
// =========================================================================
const char* SUPABASE_URL = "https://wfilyatkfgqtybujmahf.supabase.co";
const char* SUPABASE_ANON_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6IndmaWx5YXRrZmdxdHlidWptYWhmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTA2NzQ0NjksImV4cCI6MjEwNjI1MDQ2OX0.YY6G7HJcXQX0PxrLC-IG__MT-ck8mSBzIX_8TvywkLM";

// Default Network credentials
const char* DEFAULT_SSID = "Dim light";
const char* DEFAULT_PASS = "012345678m";

// Secure Setup AP Credentials
const char* PORTAL_AP_NAME = "ClassRealm-Setup";
const char* PORTAL_AP_PASS = "classrealm_071";

// =========================================================================
// INSTANCES & MEMORY STORAGE
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

// Sync state flag to prevent blocking startup
bool pendingSync = false;

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

void buzzDenied() { // 3 Fast Beeps: ACCESS DENIED / UNREGISTERED / ERROR
  for (int i = 0; i < 3; i++) {
    digitalWrite(BUZZER_PIN, HIGH);
    delay(70);
    digitalWrite(BUZZER_PIN, LOW);
    if (i < 2) delay(60);
  }
}

// =========================================================================
// OLED HELPERS
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

  display.setCursor(24, 52);
  display.print("Ready to scan");
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
  display.setCursor(12, 2);
  display.print("WIFI SETUP ACTIVE");
  display.drawFastHLine(0, 13, 128, SSD1306_WHITE);
  display.setCursor(2, 18);
  display.print("SSID: ");
  display.print(PORTAL_AP_NAME);
  display.setCursor(2, 30);
  display.print("Pass: ");
  display.print(PORTAL_AP_PASS);
  display.setCursor(2, 44);
  display.print("IP: 192.168.4.1");
  display.setCursor(2, 54);
  display.print("Scan RFID anytime");
  display.display();
  buzzTwice();
}

// =========================================================================
// TIMESTAMP & OFFLINE QUEUE
// =========================================================================
String getTimestampIso() {
  struct tm timeinfo;
  if (!getLocalTime(&timeinfo)) {
    return "2026-11-02T08:00:00+08:00";
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

  Serial.println("[OFFLINE QUEUE] Saved: " + record);
}

String extractJsonField(String payload, String fieldName) {
  String searchStr = "\"" + fieldName + "\":\"";
  int startIdx = payload.indexOf(searchStr);
  if (startIdx == -1) return "";
  startIdx += searchStr.length();
  int endIdx = payload.indexOf("\"", startIdx);
  if (endIdx == -1) return "";
  return payload.substring(startIdx, endIdx);
}

// Offline Whitelist Student Check
String getOfflineStudentName(String uid) {
  prefs.begin("card_cache", true);
  String name = prefs.getString(("c_" + uid).c_str(), "");
  prefs.end();
  return name;
}

// Download list of enrolled RFID cards to Flash Memory for Offline Mode
void syncRegisteredStudentsCache() {
  if (WiFi.status() != WL_CONNECTED) return;

  HTTPClient http;
  String url = String(SUPABASE_URL) + "/rest/v1/students?select=rfid_uid,first_name,last_name&rfid_uid=not.is.null";
  http.begin(url);
  http.addHeader("apikey", SUPABASE_ANON_KEY);
  http.addHeader("Authorization", String("Bearer ") + SUPABASE_ANON_KEY);
  http.setTimeout(3500);

  int code = http.GET();
  if (code == 200) {
    String payload = http.getString();
    prefs.begin("card_cache", false);
    
    int cursor = 0;
    int cachedCount = 0;
    while ((cursor = payload.indexOf("{\"rfid_uid\":\"", cursor)) != -1) {
      cursor += 13;
      int uidEnd = payload.indexOf("\"", cursor);
      if (uidEnd == -1) break;
      String uid = payload.substring(cursor, uidEnd);
      uid.toUpperCase();

      int fnStart = payload.indexOf("\"first_name\":\"", uidEnd);
      String shortName = "STUDENT";
      if (fnStart != -1 && fnStart < uidEnd + 150) {
        fnStart += 14;
        int fnEnd = payload.indexOf("\"", fnStart);
        if (fnEnd != -1) {
          shortName = payload.substring(fnStart, fnEnd);
        }
      }

      prefs.putString(("c_" + uid).c_str(), shortName);
      cachedCount++;
      cursor = uidEnd;
    }
    prefs.putInt("total_cached", cachedCount);
    prefs.end();
    Serial.println("[WHITELIST] Cached " + String(cachedCount) + " students in Flash!");
  }
  http.end();
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
    String url = String(SUPABASE_URL) + "/rest/v1/students?rfid_uid=eq." + uid + "&select=id";
    http.begin(url);
    http.addHeader("apikey", SUPABASE_ANON_KEY);
    http.addHeader("Authorization", String("Bearer ") + SUPABASE_ANON_KEY);
    http.setTimeout(2500);
    int code = http.GET();
    if (code == 200) {
      String res = http.getString();
      if (res.length() > 2 && res != "[]") {
        successCount++;
      }
    }
    http.end();
    delay(30);
  }

  prefs.clear();
  offlineQueueCount = 0;
  prefs.putInt("count", 0);
  prefs.end();

  buzzOnce();
  showFeedbackScreen("SYNC COMPLETE", "SUCCESS", "All uploaded");
  delay(1500);
  showIdleScreen();
}

// =========================================================================
// PROCESS RFID SCAN (GUARANTEED FEEDBACK FOR ALL CARDS)
// =========================================================================
void processRfidScan(String uid) {
  Serial.print("\n>>> [CARD SCANNED] UID: ");
  Serial.println(uid);

  // -------------------------------------------------------------
  // SITUATION A: OFFLINE MODE (No Internet / Standalone / No Laptop)
  // -------------------------------------------------------------
  if (WiFi.status() != WL_CONNECTED) {
    String cachedName = getOfflineStudentName(uid);

    if (cachedName.length() > 0) {
      // Registered student from local memory whitelist
      saveOfflineScan(uid);
      buzzOnce(); // 1 Beep: PRESENT
      showFeedbackScreen("OFFLINE SCAN", "PRESENT", cachedName);
    } else {
      // Unregistered card: 3 fast beeps + STRICTLY NOT STORED IN DB QUEUE
      buzzDenied();
      showFeedbackScreen("NOT REGISTERED", "UNREGISTERED", "UID: " + uid);
    }
    delay(2000);
    showIdleScreen();
    return;
  }

  // -------------------------------------------------------------
  // SITUATION B: ONLINE MODE (Live Supabase Verification)
  // -------------------------------------------------------------
  showFeedbackScreen("CHECKING...", uid, "Verifying card...");

  HTTPClient http;
  String url = String(SUPABASE_URL) + "/rest/v1/students?rfid_uid=eq." + uid + "&select=id,first_name,last_name";
  http.begin(url);
  http.addHeader("apikey", SUPABASE_ANON_KEY);
  http.addHeader("Authorization", String("Bearer ") + SUPABASE_ANON_KEY);
  http.setTimeout(3500);

  int httpCode = http.GET();
  if (httpCode == 200) {
    String payload = http.getString();

    if (payload.length() > 2 && payload != "[]") {
      String firstName = extractJsonField(payload, "first_name");
      String lastName = extractJsonField(payload, "last_name");
      String shortName = firstName + " " + (lastName.length() > 0 ? lastName.substring(0, 1) + "." : "");

      // Save to local cache for future offline use
      prefs.begin("card_cache", false);
      prefs.putString(("c_" + uid).c_str(), shortName);
      prefs.end();

      // Registered Student -> 1 Beep
      buzzOnce();
      showFeedbackScreen("VERIFIED", "PRESENT", shortName);
    } else {
      // STRICT RULE: Unregistered Card -> 3 Fast Beeps + NEVER SAVED TO DB!
      buzzDenied();
      showFeedbackScreen("ERROR", "ACCESS DENIED", "Unregistered Card");
    }
  } else {
    // If Supabase timed out: check local offline cache
    String cachedName = getOfflineStudentName(uid);
    if (cachedName.length() > 0) {
      saveOfflineScan(uid);
      buzzOnce();
      showFeedbackScreen("OFFLINE SCAN", "PRESENT", cachedName);
    } else {
      buzzDenied();
      showFeedbackScreen("ERROR", "ACCESS DENIED", "Unregistered Card");
    }
  }
  http.end();

  delay(2200);
  showIdleScreen();
}

// =========================================================================
// RC522 HARDWARE INIT
// =========================================================================
void initRfidHardware() {
  pinMode(RFID_PWR_PIN, OUTPUT);
  digitalWrite(RFID_PWR_PIN, HIGH);
  delay(80);

  // Hardware Reset via RST Pin D14
  pinMode(RFID_RST_PIN, OUTPUT);
  digitalWrite(RFID_RST_PIN, LOW);
  delay(40);
  digitalWrite(RFID_RST_PIN, HIGH);
  delay(80);

  SPI.begin(RFID_SCK_PIN, RFID_MISO_PIN, RFID_MOSI_PIN, RFID_SS_PIN);
  SPI.setFrequency(4000000);
  rfid.PCD_Init();
  delay(50);

  rfid.PCD_SetAntennaGain(MFRC522::RxGain_43dB);
  rfid.PCD_AntennaOn();

  byte version = rfid.PCD_ReadRegister(rfid.VersionReg);
  Serial.print("[RFID] Hardware Version: 0x");
  Serial.println(version, HEX);
}

// =========================================================================
// SETUP
// =========================================================================
void setup() {
  Serial.begin(115200);
  delay(300);

  pinMode(BUZZER_PIN, OUTPUT);
  digitalWrite(BUZZER_PIN, LOW);

  // Power-on quick beep
  digitalWrite(BUZZER_PIN, HIGH);
  delay(60);
  digitalWrite(BUZZER_PIN, LOW);

  // Read saved queue count from flash
  prefs.begin("offline_queue", true);
  offlineQueueCount = prefs.getInt("count", 0);
  prefs.end();

  // 1. Initialize OLED Screen
  Wire.begin(OLED_SDA_PIN, OLED_SCL_PIN);
  display.begin(SSD1306_SWITCHCAPVCC, OLED_ADDR);
  display.clearDisplay();
  display.setTextColor(SSD1306_WHITE);
  display.setTextSize(1);
  display.setCursor(14, 18);
  display.print("ClassRealm RFID");
  display.setCursor(20, 36);
  display.print("Connecting WiFi...");
  display.display();

  // 2. Initialize RFID Hardware
  initRfidHardware();

  // 3. Connect to Default Wi-Fi First
  Serial.print("[WIFI] Connecting to: ");
  Serial.println(DEFAULT_SSID);

  WiFi.mode(WIFI_STA);
  WiFi.begin(DEFAULT_SSID, DEFAULT_PASS);

  int attempts = 0;
  while (WiFi.status() != WL_CONNECTED && attempts < 16) { // 8 seconds max wait
    delay(500);
    attempts++;
    Serial.print(".");
  }

  // If Default Wi-Fi fails, open Multi-WiFi Setup Portal with Password
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("\n[WIFI] Checking saved networks or opening Portal...");
    WiFiManager wm;
    wm.setAPCallback(configModeCallback);
    wm.setConfigPortalTimeout(30); // 30s timeout so it doesn't stay stuck forever
    wm.autoConnect(PORTAL_AP_NAME, PORTAL_AP_PASS);
  }

  if (WiFi.status() == WL_CONNECTED) {
    Serial.println("\n[WIFI] Connected! IP: " + WiFi.localIP().toString());
    configTime(gmtOffset_sec, daylightOffset_sec, ntpServer);
    buzzOnce();
    
    // Set flag to sync students and queue in background without freezing boot
    if (offlineQueueCount > 0) {
      pendingSync = true;
    }
    syncRegisteredStudentsCache();
  } else {
    Serial.println("\n[WIFI] Offline. Running Standalone.");
  }

  // Ensure RFID is active
  initRfidHardware();

  // 4. Show Idle Screen Immediately!
  showIdleScreen();
  Serial.println("[SYSTEM] Ready! Tap card anytime.");
}

// =========================================================================
// MAIN LOOP
// =========================================================================
unsigned long lastHeartbeatMillis = 0;

void loop() {
  // If there are pending offline records and WiFi is online, sync them gracefully
  if (pendingSync && WiFi.status() == WL_CONNECTED) {
    pendingSync = false;
    syncOfflineQueue();
  }

  // Heartbeat every 4 seconds so you can see in Serial Monitor that scanner is alive
  unsigned long now = millis();
  if (now - lastHeartbeatMillis >= 4000) {
    lastHeartbeatMillis = now;
    byte ver = rfid.PCD_ReadRegister(rfid.VersionReg);
    Serial.println("[RFID MONITOR] Waiting for card... (Chip: 0x" + String(ver, HEX) + ")");
  }

  // Robust Card Detection
  bool cardPresent = rfid.PICC_IsNewCardPresent();
  if (!cardPresent) {
    // If card is already in the field or halted, try reading directly
    cardPresent = rfid.PICC_ReadCardSerial();
    if (!cardPresent) {
      delay(25);
      return;
    }
  } else {
    if (!rfid.PICC_ReadCardSerial()) {
      delay(15);
      if (!rfid.PICC_ReadCardSerial()) {
        delay(25);
        return;
      }
    }
  }

  // Extract UID
  String uid = "";
  for (byte i = 0; i < rfid.uid.size; i++) {
    if (rfid.uid.uidByte[i] < 0x10) uid += "0";
    uid += String(rfid.uid.uidByte[i], HEX);
  }
  uid.toUpperCase();

  Serial.println("[RFID DETECTED] Card UID: " + uid);

  // Debounce check
  if (uid == lastScannedUid && (now - lastScanMillis < DEBOUNCE_DELAY_MS)) {
    delay(30);
    return;
  }
  lastScannedUid = uid;
  lastScanMillis = now;

  // Print to USB Serial (Laptop Web App receives this directly)
  Serial.println(uid);

  // Process Attendance (Online to Supabase OR Offline to Flash Memory)
  processRfidScan(uid);

  // Clean halt for next card
  rfid.PICC_HaltA();
  rfid.PCD_StopCrypto1();

  delay(60);
}
