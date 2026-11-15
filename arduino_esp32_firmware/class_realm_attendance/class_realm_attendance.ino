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
#define RFID_MISO_PIN    35   // RC522 MISO   (Row A, Col 8)
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

// Active Class Offering Pairing (Auto-synced from public.teacher_schedule)
String activeSubjectOfferingId = "d28fbca1-bbbe-478d-8c41-682391a37461";

// Default Network credentials
const char* DEFAULT_SSID = "connectka?";
const char* DEFAULT_PASS = "lmao0000";

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

// Anti-Cheat Debounce & Cooldown Tracking
String lastScannedUid = "";
unsigned long lastScanMillis = 0;
const unsigned long DEBOUNCE_DELAY_MS = 2500;
const unsigned long ANY_CARD_COOLDOWN_MS = 1500;

// Sync state & periodic refresh flags
bool pendingSync = false;
bool wasWifiConnected = false;
unsigned long lastScheduleRefreshMillis = 0;
unsigned long lastSyncRetryMillis = 0;

// Layer 1 Offline Schedule & Cutoff Cache (Loaded from NVS Preferences)
bool cachedHasScheduleToday = false;
bool cachedIsHoliday = false;
int cachedOpenBeforeMins = 15; // Default 15m before start_time
int cachedStartMins = 480;     // Default 08:00 AM
int cachedEndMins = 540;       // Default 09:00 AM
int cachedGraceMins = 15;      // Default +15m grace
int cachedLateMins = 45;       // Default +45m late cutoff

// =========================================================================
// BUZZER PATTERNS
// =========================================================================
void buzzOnce() { // 1 Long Beep: PRESENT / ALL SYNCED!
  digitalWrite(BUZZER_PIN, HIGH);
  delay(140);
  digitalWrite(BUZZER_PIN, LOW);
}

void buzzTwice() { // 2 Beeps: LATE / ALREADY MARKED / SAVED OFFLINE
  digitalWrite(BUZZER_PIN, HIGH);
  delay(100);
  digitalWrite(BUZZER_PIN, LOW);
  delay(80);
  digitalWrite(BUZZER_PIN, HIGH);
  delay(100);
  digitalWrite(BUZZER_PIN, LOW);
}

void buzzDenied() { // 3 Short Beeps: TOO LATE / UNREGISTERED / NO CLASS / WRONG SECTION
  for (int i = 0; i < 3; i++) {
    digitalWrite(BUZZER_PIN, HIGH);
    delay(70);
    digitalWrite(BUZZER_PIN, LOW);
    if (i < 2) delay(60);
  }
}

// =========================================================================
// OLED HELPERS (Master OLED Display Chart)
// =========================================================================
void showIdleScreen() {
  display.clearDisplay();
  display.setTextColor(SSD1306_WHITE);

  // Header (Taas)
  display.setTextSize(1);
  display.setCursor(16, 2);
  display.print("CLASSREALM RFID");
  display.drawFastHLine(0, 13, 128, SSD1306_WHITE);

  // Main Title (Gitna)
  display.drawRect(4, 19, 120, 22, SSD1306_WHITE);
  display.setCursor(10, 26);
  display.print("TAP YOUR CARD HERE");

  // Subtext (Baba)
  display.setCursor(4, 50);
  if (WiFi.status() == WL_CONNECTED) {
    display.print("WiFi: Online");
    if (offlineQueueCount > 0) {
      display.print(" [Q:" + String(offlineQueueCount) + "]");
    }
  } else {
    display.print("WiFi: Offline [Q:" + String(offlineQueueCount) + "]");
  }

  display.display();
}

void showFeedbackScreen(String header, String bigTitle, String subText) {
  display.clearDisplay();
  display.setTextColor(SSD1306_WHITE);

  // Line 1: Header (Taas)
  display.setTextSize(1);
  display.setCursor(4, 2);
  if (header.length() > 21) {
    header = header.substring(0, 21);
  }
  display.print(header);
  display.drawFastHLine(0, 13, 128, SSD1306_WHITE);

  // Line 2: Main Title (Gitna)
  if (bigTitle.length() > 10) {
    display.drawRect(2, 18, 124, 20, SSD1306_WHITE);
    display.setTextSize(1);
    int xPos = 6;
    if (bigTitle.length() < 20) {
      xPos = (128 - (bigTitle.length() * 6)) / 2;
      if (xPos < 4) xPos = 4;
    }
    display.setCursor(xPos, 24);
  } else {
    display.setTextSize(2);
    int xPos = (128 - (bigTitle.length() * 12)) / 2;
    if (xPos < 4) xPos = 4;
    display.setCursor(xPos, 20);
  }
  display.print(bigTitle);

  // Line 3: Subtext (Baba)
  display.setTextSize(1);
  display.setCursor(4, 48);
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
// TIMESTAMP, FORMATTING & OFFLINE QUEUE
// =========================================================================
String getTimestampIso() {
  struct tm timeinfo;
  if (!getLocalTime(&timeinfo)) {
    return "2026-11-15T08:00:00+08:00";
  }
  char buf[30];
  strftime(buf, sizeof(buf), "%Y-%m-%dT%H:%M:%S", &timeinfo);
  return String(buf) + "+08:00";
}

String getTodayDateIso() {
  struct tm timeinfo;
  if (!getLocalTime(&timeinfo)) {
    return "2026-11-15";
  }
  char buf[16];
  strftime(buf, sizeof(buf), "%Y-%m-%d", &timeinfo);
  return String(buf);
}

String formatMinsTo12h(int totalMins) {
  if (totalMins < 0) totalMins = 0;
  totalMins = totalMins % 1440;
  int hh = totalMins / 60;
  int mm = totalMins % 60;
  String period = (hh >= 12) ? "PM" : "AM";
  int dispH = hh % 12;
  if (dispH == 0) dispH = 12;
  char buf[16];
  snprintf(buf, sizeof(buf), "%02d:%02d %s", dispH, mm, period.c_str());
  return String(buf);
}

bool isUidAlreadyQueuedToday(String uid) {
  if (offlineQueueCount <= 0) return false;
  String todayPrefix = getTodayDateIso();
  prefs.begin("offline_queue", true);
  bool found = false;
  for (int i = 0; i < offlineQueueCount; i++) {
    String key = "q_" + String(i);
    String rec = prefs.getString(key.c_str(), "");
    if (rec.startsWith(uid + "|" + todayPrefix)) {
      found = true;
      break;
    }
  }
  prefs.end();
  return found;
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

  pendingSync = true;
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
      String shortName = "Student";
      if (fnStart != -1 && fnStart < uidEnd + 150) {
        fnStart += 14;
        int fnEnd = payload.indexOf("\"", fnStart);
        if (fnEnd != -1) {
          shortName = payload.substring(fnStart, fnEnd);
        }
      }

      int lnStart = payload.indexOf("\"last_name\":\"", uidEnd);
      if (lnStart != -1 && lnStart < uidEnd + 150) {
        lnStart += 13;
        int lnEnd = payload.indexOf("\"", lnStart);
        if (lnEnd != -1 && lnEnd > lnStart) {
          shortName = shortName + " " + payload.substring(lnStart, lnStart + 1) + ".";
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

// Parse HH:MM:SS or HH:MM into minutes since midnight
int parseTimeToMins(String timeStr) {
  if (timeStr.length() < 4) return -1;
  int colonIdx = timeStr.indexOf(':');
  if (colonIdx == -1) return -1;
  int hh = timeStr.substring(0, colonIdx).toInt();
  int mm = timeStr.substring(colonIdx + 1, colonIdx + 3).toInt();
  return (hh * 60) + mm;
}

// Auto-detect and sync today's active schedule offering, cutoffs, & holiday from Supabase
void fetchActiveSchedule() {
  if (WiFi.status() != WL_CONNECTED) return;

  struct tm timeinfo;
  if (!getLocalTime(&timeinfo)) return;

  // ISO Day of Week: 1=Mon, 2=Tue, 3=Wed, 4=Thu, 5=Fri, 6=Sat, 7=Sun
  int isoDow = (timeinfo.tm_wday == 0) ? 7 : timeinfo.tm_wday;
  int currentMins = (timeinfo.tm_hour * 60) + timeinfo.tm_min;
  char dateBuf[16];
  strftime(dateBuf, sizeof(dateBuf), "%Y-%m-%d", &timeinfo);
  String todayStr = String(dateBuf);

  // 1. Check active holiday today
  {
    HTTPClient http;
    String hUrl = String(SUPABASE_URL) + "/rest/v1/school_holidays?is_active=eq.true&holiday_date=eq." + todayStr + "&select=holiday_name&limit=1";
    http.begin(hUrl);
    http.addHeader("apikey", SUPABASE_ANON_KEY);
    http.addHeader("Authorization", String("Bearer ") + SUPABASE_ANON_KEY);
    http.setTimeout(2500);
    int hCode = http.GET();
    if (hCode == 200) {
      String hPayload = http.getString();
      cachedIsHoliday = (hPayload.length() > 2 && hPayload != "[]");
    }
    http.end();
  }

  // 2. Check active schedules for today and pick the one matching current time (or next upcoming)
  HTTPClient http;
  String url = String(SUPABASE_URL) + "/rest/v1/teacher_schedule?is_active=eq.true&day_of_week=eq." + String(isoDow) + "&select=subject_offering_id,start_time,end_time&order=start_time.asc";
  http.begin(url);
  http.addHeader("apikey", SUPABASE_ANON_KEY);
  http.addHeader("Authorization", String("Bearer ") + SUPABASE_ANON_KEY);
  http.setTimeout(3000);

  int code = http.GET();
  if (code == 200) {
    String payload = http.getString();
    if (payload.length() > 2 && payload != "[]") {
      String chosenOffering = "";
      int chosenStart = -1;
      int chosenEnd = -1;

      int cursor = 0;
      while ((cursor = payload.indexOf("{", cursor)) != -1) {
        int objEnd = payload.indexOf("}", cursor);
        if (objEnd == -1) break;
        String item = payload.substring(cursor, objEnd + 1);
        String offId = extractJsonField(item, "subject_offering_id");
        int stMins = parseTimeToMins(extractJsonField(item, "start_time"));
        int enMins = parseTimeToMins(extractJsonField(item, "end_time"));

        if (offId.length() > 0 && stMins >= 0) {
          // Prefer the schedule currently active (from 30 mins before start until end_time)
          if (currentMins >= (stMins - 30) && (enMins < 0 || currentMins <= enMins)) {
            chosenOffering = offId;
            chosenStart = stMins;
            chosenEnd = enMins;
            break;
          }
          // Otherwise keep the first schedule of the day as fallback
          if (chosenOffering.length() == 0) {
            chosenOffering = offId;
            chosenStart = stMins;
            chosenEnd = enMins;
          }
        }
        cursor = objEnd + 1;
      }

      if (chosenOffering.length() > 0) {
        activeSubjectOfferingId = chosenOffering;
        cachedHasScheduleToday = true;
        if (chosenStart >= 0) cachedStartMins = chosenStart;
        if (chosenEnd >= 0) cachedEndMins = chosenEnd;
        Serial.println("[SCHEDULE] Active offering: " + activeSubjectOfferingId + " (" + formatMinsTo12h(cachedStartMins) + " - " + formatMinsTo12h(cachedEndMins) + ")");
      }
    } else {
      cachedHasScheduleToday = false;
      Serial.println("[SCHEDULE] No active schedule plotted for today.");
    }
  }
  http.end();

  // 3. Fetch cutoff configuration for active offering
  if (activeSubjectOfferingId.length() > 0) {
    HTTPClient cHttp;
    String cUrl = String(SUPABASE_URL) + "/rest/v1/attendance_cutoffs?subject_offering_id=eq." + activeSubjectOfferingId + "&select=present_start_mins_before,present_grace_mins,late_cutoff_mins&limit=1";
    cHttp.begin(cUrl);
    cHttp.addHeader("apikey", SUPABASE_ANON_KEY);
    cHttp.addHeader("Authorization", String("Bearer ") + SUPABASE_ANON_KEY);
    cHttp.setTimeout(2500);
    int cCode = cHttp.GET();
    if (cCode == 200) {
      String cPayload = cHttp.getString();
      if (cPayload.length() > 2 && cPayload != "[]") {
        String bStr = extractJsonField(cPayload, "present_start_mins_before");
        String gStr = extractJsonField(cPayload, "present_grace_mins");
        String lStr = extractJsonField(cPayload, "late_cutoff_mins");
        if (bStr.length() > 0) cachedOpenBeforeMins = bStr.toInt();
        if (gStr.length() > 0) cachedGraceMins = gStr.toInt();
        if (lStr.length() > 0) cachedLateMins = lStr.toInt();
      }
    }
    cHttp.end();
  }

  prefs.begin("class_config", false);
  prefs.putString("active_offering", activeSubjectOfferingId);
  prefs.putBool("has_sched", cachedHasScheduleToday);
  prefs.putBool("is_holiday", cachedIsHoliday);
  prefs.putInt("open_before", cachedOpenBeforeMins);
  prefs.putInt("start_mins", cachedStartMins);
  prefs.putInt("end_mins", cachedEndMins);
  prefs.putInt("grace_mins", cachedGraceMins);
  prefs.putInt("late_mins", cachedLateMins);
  prefs.end();
}

// =========================================================================
// LAYER 1 OFFLINE VALIDATION (Master Chart Rows 3, 4, 5, 8, 9, 10, 11, 12, 13)
// =========================================================================
void handleOfflineValidatedScan(String uid) {
  // Row 13: Holiday o Walang Pasok
  if (cachedIsHoliday) {
    buzzDenied();
    showFeedbackScreen("[ HOLIDAY ]", "NO CLASS", "Class Suspended");
    return;
  }

  // Row 12: Walang Klase sa Araw na Ito
  if (!cachedHasScheduleToday) {
    buzzDenied();
    showFeedbackScreen("[ SCHEDULE ]", "NO CLASS TODAY", "No Class Today");
    return;
  }

  // Row 9: Bagong Card (Wala pang may-ari)
  String cachedName = getOfflineStudentName(uid);
  if (cachedName.length() == 0) {
    buzzDenied();
    showFeedbackScreen("[ CARD SCAN ]", "UNREGISTERED", "Ready to Link!");
    return;
  }

  // Row 8: Re-Tap (Na-record na kanina sa Offline Queue)
  if (isUidAlreadyQueuedToday(uid)) {
    buzzTwice();
    showFeedbackScreen("[ VERIFIED ]", "ALREADY MARKED", "Recorded Today");
    return;
  }

  struct tm timeinfo;
  if (getLocalTime(&timeinfo)) {
    int scanMins = (timeinfo.tm_hour * 60) + timeinfo.tm_min;
    int openMins = cachedStartMins - cachedOpenBeforeMins;
    int presentCutoff = cachedStartMins + cachedGraceMins;
    int lateCutoff = cachedStartMins + cachedLateMins;

    // Row 10: Sobrang Aga (Sarado pa)
    if (scanMins < openMins) {
      buzzDenied();
      showFeedbackScreen("[ SCHEDULE ]", "TOO EARLY", "Opens at " + formatMinsTo12h(openMins));
      return;
    }

    // Row 11: Tapos na ang Oras ng Klase
    if (cachedEndMins > 0 && scanMins > cachedEndMins) {
      buzzDenied();
      showFeedbackScreen("[ SCHEDULE ]", "CLASS ENDED", "Scans Closed");
      return;
    }

    // Save to Non-Volatile Flash Queue with true physical timestamp
    saveOfflineScan(uid);

    // Row 4: Offline Scan (On-Time)
    if (scanMins <= presentCutoff) {
      buzzTwice();
      showFeedbackScreen("[ OFFLINE ]", "SAVED: PRESENT", cachedName + " (Queued)");
    }
    // Row 5: Offline Scan (Late)
    else if (scanMins <= lateCutoff) {
      buzzTwice();
      showFeedbackScreen("[ OFFLINE ]", "SAVED: LATE", cachedName + " (Queued)");
    }
    // Row 3: Sobrang Late (Lagpas Cutoff)
    else {
      buzzDenied();
      showFeedbackScreen("[ CUTOFF ]", "TOO LATE", "Marked Absent");
    }
  } else {
    saveOfflineScan(uid);
    buzzTwice();
    showFeedbackScreen("[ OFFLINE ]", "SAVED: PRESENT", cachedName + " (Queued)");
  }
}

// =========================================================================
// AUTOMATIC OFFLINE QUEUE DRAIN (Master Chart Rows 6 & 7)
// =========================================================================
void syncOfflineQueue() {
  if (WiFi.status() != WL_CONNECTED || offlineQueueCount == 0) return;

  // Row 6: Pagbalik ng WiFi (Habang Nag-sy-sync)
  showFeedbackScreen("[ SYNCING ]", "UPLOADING...", "Queue: " + String(offlineQueueCount) + " Scans");

  prefs.begin("offline_queue", false);
  int successCount = 0;
  int remainingCount = 0;

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
    http.setTimeout(3500);

    String body = "{\"p_rfid_uid\":\"" + uid + "\",\"p_subject_offering_id\":\"" + activeSubjectOfferingId + "\",\"p_scan_timestamp\":\"" + timestamp + "\",\"p_device_id\":\"HARDWARE_ESP32\"}";
    int code = http.POST(body);
    if (code == 200) {
      successCount++;
    } else {
      // Keep failed item for next retry
      String keepKey = "q_" + String(remainingCount);
      if (keepKey != key) {
        prefs.putString(keepKey.c_str(), record);
      }
      remainingCount++;
    }
    http.end();
    delay(40);
  }

  if (remainingCount == 0) {
    prefs.clear();
    offlineQueueCount = 0;
    prefs.putInt("count", 0);
  } else {
    offlineQueueCount = remainingCount;
    prefs.putInt("count", offlineQueueCount);
  }
  prefs.end();

  if (successCount > 0) {
    // Row 7: Tapos na ang Sync
    buzzOnce();
    showFeedbackScreen("[ SYNC COMPLETE ]", "ALL SYNCED!", "Uploaded: " + String(successCount) + " Logs");
    delay(1800);
  }
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
  }
  http.end();
}

// =========================================================================
// PROCESS RFID SCAN (Master Chart Rows 1–14)
// =========================================================================
void processRfidScan(String uid) {
  Serial.print("\n>>> [CARD SCANNED] UID: ");
  Serial.println(uid);

  // -------------------------------------------------------------
  // SITUATION A: OFFLINE MODE (Layer 1 Local Schedule & Cutoff Validation)
  // -------------------------------------------------------------
  if (WiFi.status() != WL_CONNECTED) {
    handleOfflineValidatedScan(uid);
    delay(2200);
    showIdleScreen();
    return;
  }

  // -------------------------------------------------------------
  // SITUATION B: ONLINE MODE (Atomic Supabase RPC Validation)
  // -------------------------------------------------------------
  showFeedbackScreen("[ CHECKING... ]", uid, "Verifying card...");

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
    String openTime = extractJsonField(payload, "open_time");

    // Format display name (e.g. "Aguilar, Fiona" -> "Fiona A.")
    String displayName = studentName;
    if (displayName.indexOf(',') != -1) {
      int commaIdx = displayName.indexOf(',');
      String lastName = displayName.substring(0, commaIdx);
      String firstName = displayName.substring(commaIdx + 1);
      lastName.trim();
      firstName.trim();
      int spaceIdx = firstName.indexOf(' ');
      if (spaceIdx != -1) {
        firstName = firstName.substring(0, spaceIdx);
      }
      displayName = firstName + " " + (lastName.length() > 0 ? lastName.substring(0, 1) + "." : "");
    }
    if (displayName.length() == 0) {
      displayName = uid;
    }

    // Cache verified student name in NVS Flash for future offline use
    if (studentName.length() > 0) {
      prefs.begin("card_cache", false);
      prefs.putString(("c_" + uid).c_str(), displayName);
      prefs.end();
    }

    // Rows 1, 2, 3: On-Time Present, Late Arrival, or Past Cutoff (Too Late -> Absent)
    if (code == "RECORDED_SUCCESS" || code == "PROMOTED_FROM_AUTO_ABSENT" || code == "PROMOTED_TO_PRESENT") {
      if (status == "late") {
        buzzTwice();
        showFeedbackScreen("[ VERIFIED ]", "LATE", displayName + "  " + timeIn);
      } else if (status == "absent") {
        buzzDenied();
        showFeedbackScreen("[ CUTOFF ]", "TOO LATE", "Marked Absent");
      } else {
        buzzOnce();
        showFeedbackScreen("[ VERIFIED ]", "PRESENT", displayName + "  " + timeIn);
      }
    }
    // Row 8: Re-Tap (Na-record na kanina)
    else if (code == "IDEMPOTENT_ALREADY_RECORDED" || code == "MANUAL_OVERRIDE_PRESERVED" || code == "present_TIMESTAMP_PROMOTED" || code == "late_TIMESTAMP_PROMOTED") {
      buzzTwice();
      showFeedbackScreen("[ VERIFIED ]", "ALREADY MARKED", "Recorded Today");
    }
    // Row 9: Bagong Card (Wala pang may-ari)
    else if (code == "UNREGISTERED_CARD") {
      buzzDenied();
      showFeedbackScreen("[ CARD SCAN ]", "UNREGISTERED", "Ready to Link!");
    }
    // Row 10: Sobrang Aga (Sarado pa)
    else if (code == "BEFORE_WINDOW_OPENS") {
      buzzDenied();
      showFeedbackScreen("[ SCHEDULE ]", "TOO EARLY", openTime.length() > 0 ? ("Opens at " + openTime) : "Opens Soon");
    }
    // Row 11: Tapos na ang Oras ng Klase
    else if (code == "AFTER_CLASS_ENDS" || code == "SCANS_CLOSED") {
      buzzDenied();
      showFeedbackScreen("[ SCHEDULE ]", "CLASS ENDED", "Scans Closed");
    }
    // Row 12: Walang Klase sa Araw na Ito
    else if (code == "NO_SCHEDULE_TODAY") {
      buzzDenied();
      showFeedbackScreen("[ SCHEDULE ]", "NO CLASS TODAY", "No Class Today");
    }
    // Row 13: Holiday o Walang Pasok
    else if (code == "HOLIDAY_LOCKED") {
      buzzDenied();
      showFeedbackScreen("[ HOLIDAY ]", "NO CLASS", "Class Suspended");
    }
    // Row 14: Ibang Section ang Estudyante
    else if (code == "CROSS_SECTION_TAP") {
      buzzDenied();
      showFeedbackScreen("[ ENROLLMENT ]", "WRONG SECTION", "Not in this Class");
    }
    // Generic Fallback
    else {
      buzzOnce();
      showFeedbackScreen("[ VERIFIED ]", "PRESENT", displayName);
    }
  } else {
    Serial.println("[RPC ERROR] HTTP Code: " + String(httpCode));
    // Fallback to Layer 1 local offline validation when cloud RPC fails/times out
    handleOfflineValidatedScan(uid);
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

  // Load saved offering, schedule & cutoff cache, and queue count from flash
  prefs.begin("class_config", true);
  activeSubjectOfferingId = prefs.getString("active_offering", activeSubjectOfferingId);
  cachedHasScheduleToday = prefs.getBool("has_sched", false);
  cachedIsHoliday = prefs.getBool("is_holiday", false);
  cachedOpenBeforeMins = prefs.getInt("open_before", 15);
  cachedStartMins = prefs.getInt("start_mins", 480);
  cachedEndMins = prefs.getInt("end_mins", 540);
  cachedGraceMins = prefs.getInt("grace_mins", 15);
  cachedLateMins = prefs.getInt("late_mins", 45);
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

  // 3. Connect to Saved Hotspot First, then Default Wi-Fi, then Setup Portal
  prefs.begin("wifi_creds", true);
  String savedSsid = prefs.getString("ssid", "");
  String savedPass = prefs.getString("pass", "");
  prefs.end();

  WiFi.mode(WIFI_STA);
  WiFi.setAutoReconnect(true);
  WiFi.persistent(true);

  if (savedSsid.length() > 0 && savedSsid != String(DEFAULT_SSID)) {
    Serial.print("[WIFI] Trying saved Hotspot: ");
    Serial.println(savedSsid);
    WiFi.begin(savedSsid.c_str(), savedPass.c_str());
    int savedAttempts = 0;
    while (WiFi.status() != WL_CONNECTED && savedAttempts < 12) { // 6 seconds max wait
      delay(500);
      savedAttempts++;
      Serial.print(".");
    }
  }

  if (WiFi.status() != WL_CONNECTED) {
    Serial.print("\n[WIFI] Connecting to Default Wi-Fi: ");
    Serial.println(DEFAULT_SSID);
    WiFi.begin(DEFAULT_SSID, DEFAULT_PASS);

    int attempts = 0;
    while (WiFi.status() != WL_CONNECTED && attempts < 12) { // 6 seconds max wait
      delay(500);
      attempts++;
      Serial.print(".");
    }
  }

  // If still not connected, open Multi-WiFi Setup Portal (ClassRealm-Setup / classrealm_071)
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("\n[WIFI] Opening ClassRealm-Setup Portal for Hotspot pairing...");
    WiFiManager wm;
    wm.setAPCallback(configModeCallback);
    wm.setConfigPortalTimeout(40); // 40s timeout so it continues to Offline Mode if no Hotspot yet
    wm.autoConnect(PORTAL_AP_NAME, PORTAL_AP_PASS);
  }

  if (WiFi.status() == WL_CONNECTED) {
    wasWifiConnected = true;
    String connectedSsid = WiFi.SSID();
    String connectedPass = WiFi.psk();
    if (connectedSsid.length() > 0) {
      prefs.begin("wifi_creds", false);
      prefs.putString("ssid", connectedSsid);
      prefs.putString("pass", connectedPass);
      prefs.end();
    }
    Serial.println("\n[WIFI] Connected to " + connectedSsid + "! IP: " + WiFi.localIP().toString());
    configTime(gmtOffset_sec, daylightOffset_sec, ntpServer);
    buzzOnce();

    // Auto-detect today's active schedule offering from cloud
    fetchActiveSchedule();

    // Set flag to sync students and queue in background without freezing boot
    if (offlineQueueCount > 0) {
      pendingSync = true;
    }
    syncRegisteredStudentsCache();
    lastScheduleRefreshMillis = millis();
  } else {
    wasWifiConnected = false;
    WiFi.mode(WIFI_STA);
    WiFi.setAutoReconnect(true);
    if (savedSsid.length() > 0) {
      WiFi.begin(savedSsid.c_str(), savedPass.c_str());
    } else {
      WiFi.begin(DEFAULT_SSID, DEFAULT_PASS);
    }
    Serial.println("\n[WIFI] Offline. Running Standalone (Auto-Reconnect Armed).");
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
unsigned long lastWifiReconnectAttemptMillis = 0;
bool toggleReconnectNetwork = false;

void loop() {
  unsigned long now = millis();
  bool isOnline = (WiFi.status() == WL_CONNECTED);

  // Detect WiFi state transition (Offline <-> Online) to update Idle Screen & trigger auto-sync
  if (isOnline != wasWifiConnected) {
    wasWifiConnected = isOnline;
    if (isOnline) {
      configTime(gmtOffset_sec, daylightOffset_sec, ntpServer);
      fetchActiveSchedule();
      syncRegisteredStudentsCache();
      if (offlineQueueCount > 0) {
        pendingSync = true;
      }
    }
    showIdleScreen();
  }

  // Non-blocking background WiFi reconnect every 15s when offline (so turning Hotspot back ON auto-connects)
  if (!isOnline && (now - lastWifiReconnectAttemptMillis >= 15000)) {
    lastWifiReconnectAttemptMillis = now;
    prefs.begin("wifi_creds", true);
    String savedSsid = prefs.getString("ssid", "");
    String savedPass = prefs.getString("pass", "");
    prefs.end();

    if (savedSsid.length() > 0 && savedSsid != String(DEFAULT_SSID)) {
      if (toggleReconnectNetwork) {
        WiFi.begin(savedSsid.c_str(), savedPass.c_str());
      } else {
        WiFi.begin(DEFAULT_SSID, DEFAULT_PASS);
      }
      toggleReconnectNetwork = !toggleReconnectNetwork;
    } else {
      WiFi.reconnect();
    }
  }

  // Automatically drain offline queue when WiFi is connected
  if (isOnline && (pendingSync || (offlineQueueCount > 0 && (now - lastSyncRetryMillis >= 10000)))) {
    pendingSync = false;
    lastSyncRetryMillis = now;
    syncOfflineQueue();
  }

  // Periodically refresh active schedule & registered cards cache every 90 seconds when online
  if (isOnline && (now - lastScheduleRefreshMillis >= 90000)) {
    lastScheduleRefreshMillis = now;
    fetchActiveSchedule();
    syncRegisteredStudentsCache();
  }

  // Heartbeat every 4 seconds so you can see in Serial Monitor that scanner is alive
  if (now - lastHeartbeatMillis >= 4000) {
    lastHeartbeatMillis = now;
    byte ver = rfid.PCD_ReadRegister(rfid.VersionReg);
    Serial.println("[RFID MONITOR] Waiting for card... (Chip: 0x" + String(ver, HEX) + ")");
  }

  // Robust Card Detection
  bool cardPresent = rfid.PICC_IsNewCardPresent();
  if (!cardPresent) {
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

  // Anti-Cheat Hardware Cooldown:
  // 1) 2.5s debounce for same card
  // 2) 1.5s minimum gap between different cards to prevent rapid "Buddy Punching / Pasa-Card"
  if (uid == lastScannedUid && (now - lastScanMillis < DEBOUNCE_DELAY_MS)) {
    rfid.PICC_HaltA();
    rfid.PCD_StopCrypto1();
    delay(30);
    return;
  }
  if (uid != lastScannedUid && (now - lastScanMillis < ANY_CARD_COOLDOWN_MS)) {
    rfid.PICC_HaltA();
    rfid.PCD_StopCrypto1();
    delay(30);
    return;
  }

  lastScannedUid = uid;
  lastScanMillis = now;

  Serial.println("[RFID DETECTED] Card UID: " + uid);

  // Print to USB Serial (Laptop Web App receives this directly)
  Serial.println(uid);

  // Process Attendance (Online to Supabase RPC OR Offline to Flash Memory)
  processRfidScan(uid);

  // Clean halt for next card
  rfid.PICC_HaltA();
  rfid.PCD_StopCrypto1();

  delay(60);
}
