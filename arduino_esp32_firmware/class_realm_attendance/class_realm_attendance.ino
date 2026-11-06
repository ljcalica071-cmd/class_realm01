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
// SUPABASE CREDENTIALS & DEFAULTS
// =========================================================================
const char* SUPABASE_URL = "https://wfilyatkfgqtybujmahf.supabase.co";
const char* SUPABASE_ANON_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6IndmaWx5YXRrZmdxdHlidWptYWhmIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTA2NzQ0NjksImV4cCI6MjEwNjI1MDQ2OX0.YY6G7HJcXQX0PxrLC-IG__MT-ck8mSBzIX_8TvywkLM";

// Active Class Offering Pairing (Default: Art Criticism & Creative Markets, Sec 1)
String activeSubjectOfferingId = "d28fbca1-bbbe-478d-8c41-682391a37461";

// Default Network credentials
const char* DEFAULT_SSID = "JETWO";
const char* DEFAULT_PASS = "Jethro103199";

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
void buzzOnce() { // 1 Long Beep: PRESENT (On-time Success)
  digitalWrite(BUZZER_PIN, HIGH);
  delay(120);
  digitalWrite(BUZZER_PIN, LOW);
}

void buzzTwice() { // 2 Beeps: LATE / ALREADY MARKED / TEACHER EXCUSED / OFFLINE SAVED
  digitalWrite(BUZZER_PIN, HIGH);
  delay(100);
  digitalWrite(BUZZER_PIN, LOW);
  delay(80);
  digitalWrite(BUZZER_PIN, HIGH);
  delay(100);
  digitalWrite(BUZZER_PIN, LOW);
}

void buzzDenied() { // 3 Fast Beeps: ACCESS DENIED / UNREGISTERED / WRONG SECTION / CLOSED
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

  // Line 1: Header category
  display.setTextSize(1);
  display.setCursor(4, 2);
  display.print(header);
  display.drawFastHLine(0, 13, 128, SSD1306_WHITE);

  // Line 2: Big Title (auto-adjust size if text is long to prevent horizontal truncation)
  if (bigTitle.length() > 10) {
    display.setTextSize(1);
    display.setCursor(4, 22);
  } else {
    display.setTextSize(2);
    display.setCursor(4, 20);
  }
  display.print(bigTitle);

  // Line 3: SubText (Student Name, time, or instructional message)
  display.setTextSize(1);
  display.setCursor(4, 46);
  if (subText.length() > 21) {
    subText = subText.substring(0, 21);
  }
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
    return "2026-11-05T08:00:00+08:00";
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

// Robust JSON Field Extractor supporting whitespace and non-string tokens
String extractJsonField(String payload, String fieldName) {
  int keyIdx = payload.indexOf("\"" + fieldName + "\"");
  if (keyIdx == -1) return "";
  int colonIdx = payload.indexOf(":", keyIdx);
  if (colonIdx == -1) return "";

  int valStart = colonIdx + 1;
  while (valStart < payload.length() && (payload[valStart] == ' ' || payload[valStart] == '\t')) {
    valStart++;
  }
  if (valStart >= payload.length()) return "";

  if (payload[valStart] == '\"') {
    valStart++;
    int valEnd = payload.indexOf("\"", valStart);
    if (valEnd == -1) return "";
    return payload.substring(valStart, valEnd);
  } else {
    int valEnd = valStart;
    while (valEnd < payload.length() && 
           payload[valEnd] != ',' && 
           payload[valEnd] != '}' && 
           payload[valEnd] != ' ' && 
           payload[valEnd] != '\n' && 
           payload[valEnd] != '\r') {
      valEnd++;
    }
    return payload.substring(valStart, valEnd);
  }
}

// Offline Whitelist Student Check
String getOfflineStudentName(String uid) {
  prefs.begin("card_cache", true);
  String name = prefs.getString(("c_" + uid).c_str(), "");
  prefs.end();
  return name;
}

// Download list of registered RFID cards to Flash Memory for Offline Mode
void syncRegisteredStudentsCache() {
  if (WiFi.status() != WL_CONNECTED) return;

  HTTPClient http;
  String url = String(SUPABASE_URL) + "/rest/v1/student_profiles?select=rfid_uid,first_name,last_name&rfid_uid=not.is.null";
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

// Auto-detect and sync today's active schedule offering from Supabase
void fetchActiveSchedule() {
  if (WiFi.status() != WL_CONNECTED) return;

  struct tm timeinfo;
  if (!getLocalTime(&timeinfo)) return;

  // ISO Day of Week: 1=Mon, 2=Tue, 3=Wed, 4=Thu, 5=Fri, 6=Sat, 7=Sun
  int isoDow = (timeinfo.tm_wday == 0) ? 7 : timeinfo.tm_wday;

  HTTPClient http;
  String url = String(SUPABASE_URL) + "/rest/v1/teacher_schedule?is_active=eq.true&day_of_week=eq." + String(isoDow) + "&select=subject_offering_id,start_time,end_time&order=start_time.asc&limit=1";
  http.begin(url);
  http.addHeader("apikey", SUPABASE_ANON_KEY);
  http.addHeader("Authorization", String("Bearer ") + SUPABASE_ANON_KEY);
  http.setTimeout(3000);

  int code = http.GET();
  if (code == 200) {
    String payload = http.getString();
    if (payload.length() > 2 && payload != "[]") {
      String foundOffering = extractJsonField(payload, "subject_offering_id");
      if (foundOffering.length() > 0) {
        activeSubjectOfferingId = foundOffering;
        prefs.begin("class_config", false);
        prefs.putString("active_offering", activeSubjectOfferingId);
        prefs.end();
        Serial.println("[SCHEDULE] Auto-assigned active offering: " + activeSubjectOfferingId);
      }
    }
  }
  http.end();
}

// Drain offline queue when WiFi reconnects by submitting true timestamps to record_rfid_attendance
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
    String timestamp = record.substring(sepIndex + 1);

    HTTPClient http;
    String url = String(SUPABASE_URL) + "/rest/v1/rpc/record_rfid_attendance";
    http.begin(url);
    http.addHeader("apikey", SUPABASE_ANON_KEY);
    http.addHeader("Authorization", String("Bearer ") + SUPABASE_ANON_KEY);
    http.addHeader("Content-Type", "application/json");
    http.setTimeout(3000);

    String body = "{\"p_rfid_uid\":\"" + uid + "\",\"p_subject_offering_id\":\"" + activeSubjectOfferingId + "\",\"p_scan_timestamp\":\"" + timestamp + "\",\"p_device_id\":\"HARDWARE_ESP32\"}";
    int code = http.POST(body);
    if (code == 200) {
      successCount++;
    }
    http.end();
    delay(40);
  }

  prefs.clear();
  offlineQueueCount = 0;
  prefs.putInt("count", 0);
  prefs.end();

  buzzOnce();
  showFeedbackScreen("SYNC COMPLETE", "SUCCESS", "Uploaded: " + String(successCount));
  delay(1500);
  showIdleScreen();
}

// Broadcast an unregistered card tap to Supabase Realtime so Teacher app can link it instantly
void broadcastPendingScan(String uid) {
  if (WiFi.status() != WL_CONNECTED) return;
  HTTPClient http;
  String url = String(SUPABASE_URL) + "/rest/v1/rfid_pending_scans";
  http.begin(url);
  http.addHeader("apikey", SUPABASE_ANON_KEY);
  http.addHeader("Authorization", String("Bearer ") + SUPABASE_ANON_KEY);
  http.addHeader("Content-Type", "application/json");
  http.addHeader("Prefer", "return=minimal");
  http.setTimeout(2500);

  String body = "{\"rfid_uid\":\"" + uid + "\",\"device_id\":\"HARDWARE_ESP32\"}";
  int code = http.POST(body);
  if (code >= 200 && code < 300) {
    Serial.println("[PENDING SCAN] Broadcasted unregistered UID " + uid + " to Teacher App!");
  } else {
    Serial.println("[PENDING SCAN] Failed to broadcast UID, code: " + String(code));
  }
  http.end();
}

// =========================================================================
// PROCESS RFID SCAN (100% PARITY WITH PHONE NFC & SCHEDULE VALIDATION)
// =========================================================================
void processRfidScan(String uid) {
  Serial.print("\n>>> [CARD SCANNED] UID: ");
  Serial.println(uid);

  // -------------------------------------------------------------
  // SITUATION A: OFFLINE MODE (No WiFi / Standalone / No Laptop)
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
  // SITUATION B: ONLINE MODE (Atomic Supabase RPC Validation)
  // -------------------------------------------------------------
  showFeedbackScreen("CHECKING...", uid, "Verifying card...");

  HTTPClient http;
  String url = String(SUPABASE_URL) + "/rest/v1/rpc/record_rfid_attendance";
  http.begin(url);
  http.addHeader("apikey", SUPABASE_ANON_KEY);
  http.addHeader("Authorization", String("Bearer ") + SUPABASE_ANON_KEY);
  http.addHeader("Content-Type", "application/json");
  http.setTimeout(3500);

  String timestamp = getTimestampIso();
  String body = "{\"p_rfid_uid\":\"" + uid + "\",\"p_subject_offering_id\":\"" + activeSubjectOfferingId + "\",\"p_scan_timestamp\":\"" + timestamp + "\",\"p_device_id\":\"HARDWARE_ESP32\"}";

  int httpCode = http.POST(body);
  if (httpCode == 200) {
    String payload = http.getString();
    Serial.println("[RPC RESPONSE] " + payload);

    String code = extractJsonField(payload, "code");
    String status = extractJsonField(payload, "status");
    String studentName = extractJsonField(payload, "student_name");
    String timeIn = extractJsonField(payload, "time_in");

    // Format display name (e.g. "Aguilar, Fiona" -> "Fiona A.")
    String displayName = studentName;
    if (displayName.indexOf(',') != -1) {
      int commaIdx = displayName.indexOf(',');
      String lastName = displayName.substring(0, commaIdx);
      String firstName = displayName.substring(commaIdx + 1);
      lastName.trim();
      firstName.trim();
      displayName = firstName + " " + (lastName.length() > 0 ? lastName.substring(0, 1) + "." : "");
    }
    if (displayName.length() == 0) {
      displayName = uid;
    }

    // Cache verified student name for future offline use
    if (studentName.length() > 0) {
      prefs.begin("card_cache", false);
      prefs.putString(("c_" + uid).c_str(), displayName);
      prefs.end();
    }

    // 1. Success Cases (On-Time Present, Late, or Absent Cutoff)
    if (code == "RECORDED_SUCCESS" || code == "PROMOTED_FROM_AUTO_ABSENT" || code == "PROMOTED_TO_PRESENT") {
      if (status == "late") {
        buzzTwice();
        showFeedbackScreen("ATTENDANCE OK", "LATE", displayName + " " + timeIn);
      } else if (status == "absent") {
        buzzDenied();
        showFeedbackScreen("CUTOFF CLOSED", "TOO LATE", displayName);
      } else {
        buzzOnce();
        showFeedbackScreen("ATTENDANCE OK", "PRESENT", displayName + " " + timeIn);
      }
    } 
    // 2. Already Recorded Today: Confirmation Tap for Already Scanned Student
    else if (code == "IDEMPOTENT_ALREADY_RECORDED" || code == "present_TIMESTAMP_PROMOTED" || code == "late_TIMESTAMP_PROMOTED") {
      buzzTwice();
      showFeedbackScreen("ALREADY SCANNED", "RECORDED NA!", displayName);
    } 
    // 3. Teacher Manual Override / Excused Protected
    else if (code == "MANUAL_OVERRIDE_PRESERVED") {
      buzzTwice();
      showFeedbackScreen("EXCUSED", "TEACHER MARK", "Excused by Teacher");
    } 
    // 4. Cross-Section Protection: Student not enrolled in this subject offering
    else if (code == "CROSS_SECTION_TAP") {
      buzzDenied();
      showFeedbackScreen("NOT ENROLLED", "WRONG SECTION", displayName);
    } 
    // 5. Unregistered Card: UID not in school database
    else if (code == "UNREGISTERED_CARD") {
      broadcastPendingScan(uid);
      buzzDenied();
      showFeedbackScreen("LINK READY", "UNREGISTERED", "Ready to Link!");
    } 
    // 6. Schedule Lock / School Holiday
    else if (code == "NO_SCHEDULE_TODAY" || code == "HOLIDAY_LOCKED") {
      buzzDenied();
      showFeedbackScreen("SCHEDULE LOCKED", "NO CLASS", "No Class Today");
    } 
    // 7. Window not yet open
    else if (code == "BEFORE_WINDOW_OPENS") {
      buzzDenied();
      showFeedbackScreen("TOO EARLY", "WINDOW CLOSED", "Class not started");
    } 
    // 8. Session ended / scans closed
    else if (code == "AFTER_CLASS_ENDS" || code == "SCANS_CLOSED") {
      buzzDenied();
      showFeedbackScreen("CUTOFF CLOSED", "SCANS CLOSED", "Session Ended");
    } 
    // 9. Generic Fallback
    else {
      buzzOnce();
      showFeedbackScreen("ATTENDANCE", status.length() > 0 ? status : "OK", displayName);
    }
  } else {
    Serial.println("[RPC ERROR] HTTP Code: " + String(httpCode));
    // Fallback to local offline cache when cloud RPC fails/times out
    String cachedName = getOfflineStudentName(uid);
    if (cachedName.length() > 0) {
      saveOfflineScan(uid);
      buzzOnce();
      showFeedbackScreen("OFFLINE SCAN", "PRESENT", cachedName);
    } else {
      buzzDenied();
      showFeedbackScreen("ERROR", "ACCESS DENIED", "Check Network");
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

  // Load saved offering & queue count from flash
  prefs.begin("class_config", true);
  activeSubjectOfferingId = prefs.getString("active_offering", activeSubjectOfferingId);
  prefs.end();

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
    
    // Auto-detect today's active schedule offering from cloud
    fetchActiveSchedule();

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

  // Process Attendance (Online to Supabase RPC OR Offline to Flash Memory)
  processRfidScan(uid);

  // Clean halt for next card
  rfid.PICC_HaltA();
  rfid.PCD_StopCrypto1();

  delay(60);
}
