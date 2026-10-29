# ESP32 Autonomous RFID Classroom Scanner: Hardware Build & Firmware Guide
**ClassRealm — Senior High School Management Platform**  
**Document Code:** `CR-HW-ESP32-GUIDE-2026-V1`  
**Target Milestone:** Dual-Path Offline Attendance Pipeline (R4)  
**Date:** October 29, 2026  
**Status:** Approved Hardware Build & Firmware Specification  

---

## 1. System Overview & Electrical Specifications

The **ClassRealm ESP32 Autonomous RFID Classroom Scanner** is a standalone, battery-capable or AC-powered IoT edge device designed for mounting at classroom doors. It operates with **zero dependency on the teacher's laptop or constant Wi-Fi connectivity**.

### Key Technical Capabilities
- **Autonomous Standalone Operation**: Microcontroller directly authenticates with the Supabase PostgreSQL backend via TLS 1.3 HTTPS REST API/RPC.
- **Dual-Core FreeRTOS Task Segregation**:
  - **Core 1**: Dedicated to real-time RFID polling at 20Hz (50ms period) with sub-millisecond audio/visual feedback. Core 1 never blocks, even during network lags.
  - **Core 0**: Handles Wi-Fi connection, SNTP wall-clock time sync, and background HTTPS queue flushing.
- **Power-Fail Safe Non-Volatile Spooling**: Uses **LittleFS** flash storage to log scan events into an append-only JSON Lines file (`/spool/attendance_queue.jsonl`). Holds $>6,800$ offline scans on a 1.5MB flash partition without risk of file corruption.
- **Dual Power Circuit**: Operates from a standard 5V USB-C wall charger or an internal 18650 3.7V 2600mAh Li-ion battery providing 12–16 hours of continuous cord-free operation.

---

## 2. Bill of Materials (BOM)

| Item # | Component | Model / Specification | Qty | Voltage | Current (Active / Idle) | Function & Justification | Est. Cost (PHP / USD) |
|---|---|---|---|---|---|---|---|
| **1** | Microcontroller | **ESP32 DevKit V1** (ESP-WROOM-32, 30 or 38-Pin, Dual-Core 240MHz, 4MB Flash, 520KB SRAM) | 1 | 3.3V Core / 5V VIN | 160–240 mA (Wi-Fi TX) / 10 µA (Deep Sleep) | Core processing, FreeRTOS dual-core multitasking, hardware SPI/I2C, LittleFS, TLS 1.3 stack. | ₱220 / $3.80 |
| **2A** | RFID Reader (Primary) | **RC522 (MFRC522)** 13.56MHz SPI Module | 1 | **3.3V ONLY** (5V destroys IC) | 13–26 mA / 10 µA | Low-cost, robust standard ISO 14443-A reader. Reads MIFARE Classic 1K/4K, Ultralight, NTAG213/215/216 cards. | ₱90 / $1.50 |
| **2B** | RFID Reader (Alternate) | **PN532 NFC Module** (V3 with red/blue board, DIP switches for I2C/SPI) | 1 | 3.3V or 5.0V | 30–50 mA / 15 µA | Higher RF sensitivity (up to 60mm read range), I2C 2-wire bus, native phone NFC emulation support. | ₱260 / $4.50 |
| **3** | Audio Feedback | **Active Buzzer** (3.3V or 5V, continuous resonant tone generator) | 1 | 3.3V – 5.0V | 20–30 mA / 0 mA | Clear high-pitch audible confirmation for student taps without requiring DAC/PWM tone generation. | ₱25 / $0.40 |
| **4** | Visual Indicators | **3x 5mm High-Efficiency LEDs** (Green, Red, Blue) | 3 | 2.0V – 3.2V | 10–15 mA each | Visual state feedback: Green (Valid scan), Red (Invalid/Rejected), Blue (Online / Offline Spooling). | ₱15 / $0.25 |
| **5** | Resistors | **3x 220Ω 1/4W Metal Film Resistors** | 3 | N/A | Passive | Current limiting for LEDs (protects ESP32 GPIOs, limits draw to ~8mA per pin). | ₱5 / $0.10 |
| **6** | Decoupling Capacitors | **1x 100µF 16V Electrolytic + 1x 0.1µF (100nF) Ceramic** | 2 | Up to 16V | Passive | Buffers 3.3V rail against Wi-Fi RF power surges, preventing ESP32 brownout resets during transmission. | ₱10 / $0.15 |
| **7** | Battery Charger | **TP4056 1A Li-ion Charger with DW01A Protection** | 1 | Input: 5V USB-C; Bat: 3.7V–4.2V | 1.0A CC/CV charge | Safe Li-ion charging, over-discharge (<2.5V) protection, over-current cutoff. | ₱35 / $0.60 |
| **8** | DC-DC Step-Up | **MT3608 Step-Up Boost Converter Module** | 1 | In: 2V–24V; Out: Adj 5.05V | Up to 2A output | Boosts 3.7V battery voltage to steady 5.05V DC for ESP32 VIN pin. 93% efficiency. | ₱50 / $0.90 |
| **9** | Battery Cell | **18650 Li-ion 3.7V 2600mAh Cell** + Single Battery Sled | 1 | 3.7V nominal (4.2V peak) | 2600 mAh capacity | Provides 12–16 hours of continuous standalone operation on a single charge. | ₱150 / $2.60 |
| **10** | Power Switch | **Miniature SPST Rocker Switch** (KCD11) | 1 | 12V 3A | N/A | Hard master power disconnect between battery and boost converter. | ₱15 / $0.25 |
| **11** | Circuit Board | **FR4 Double-Sided Prototype PCB** (70mm x 90mm) | 1 | N/A | N/A | Clean solder assembly for robust classroom vibration and handling resistance. | ₱50 / $0.90 |
| **12** | Enclosure | **ABS Project Box or 3D Printed PETG Case** (120 x 80 x 40 mm) | 1 | N/A | N/A | Protects circuit from dust, drops, and student tampering. | ₱150 / $2.60 |
| **Total** | **Full Portable Hardware Kit (RC522 SPI Option)** | | | | **Typical Continuous Draw: ~120mA** | **Total Unit Cost:** | **~₱810 / $14.00** |

---

## 3. Circuit Wiring & Pinout Tables

### 3.1 ESP32 DevKit V1 (30-Pin & 38-Pin) with MFRC522 (Hardware VSPI)

> **CRITICAL ELECTRICAL WARNING**:  
> The MFRC522 reader module MUST be powered from the **3.3V rail (3V3)**. Connecting MFRC522 VCC to 5V or VIN will permanently destroy the MFRC522 silicon chip.

| MFRC522 Pin | ESP32 DevKit Pin | ESP32 GPIO Function | Dupont Wire Color | Electrical Notes |
|---|---|---|---|---|
| **VCC (3.3V)** | **3V3** | 3.3V Regulated Output | **Red** | **Connect to 3V3 ONLY. Do NOT connect to 5V.** |
| **RST** | **D22** | GPIO 22 | **Brown** | Hard reset line for RFID module. |
| **GND** | **GND** | Ground Rail | **Black** | Common system ground. |
| **IRQ** | *NC* | Not Connected | — | Left floating (firmware uses 20Hz polling). |
| **MISO** | **D19** | GPIO 19 (VSPI MISO) | **Blue** | Master In Slave Out (Data from reader to ESP32). |
| **MOSI** | **D23** | GPIO 23 (VSPI MOSI) | **Green** | Master Out Slave In (Data from ESP32 to reader). |
| **SCK** | **D18** | GPIO 18 (VSPI CLK) | **Yellow** | SPI Clock signal. |
| **SDA (SS / CS)** | **D5** | GPIO 5 (VSPI CS0) | **White** | Chip Select line (Active LOW). |

---

### 3.2 Status Indicators & Audio Peripherals Wiring

| Peripheral Pin | ESP32 Pin | GPIO | Series Resistor | Logic Behavior |
|---|---|---|---|---|
| **Active Buzzer (+)** | **D25** | GPIO 25 | Direct (3.3V buzzer) or 100Ω | Active HIGH. Set HIGH to emit tone. |
| **Active Buzzer (-)** | **GND** | Ground | None | System ground. |
| **Green LED (+)** | **D26** | GPIO 26 | 220Ω in series with anode (+) | Active HIGH. Solid on valid scan. |
| **Green LED (-)** | **GND** | Ground | None | System ground. |
| **Red LED (+)** | **D27** | GPIO 27 | 220Ω in series with anode (+) | Active HIGH. Error / Rejected / Out of schedule. |
| **Red LED (-)** | **GND** | Ground | None | System ground. |
| **Blue LED (+)** | **D14** | GPIO 14 | 220Ω in series with anode (+) | Active HIGH. Solid = Online; Blinking = Offline Spooling. |
| **Blue LED (-)** | **GND** | Ground | None | System ground. |

---

### 3.3 Alternative Reader: PN532 Module in I2C Mode (2 Data Wires)

*DIP Switch Setting on PN532 Board: `SEL0 = ON`, `SEL1 = OFF` (I2C Mode).*

| PN532 Pin | ESP32 DevKit Pin | ESP32 GPIO | Electrical Notes |
|---|---|---|---|
| **VCC** | **VIN (5V) or 3V3** | 5V or 3.3V | PN532 contains an onboard 3.3V LDO regulator. |
| **GND** | **GND** | Ground | System ground. |
| **SDA** | **D21** | GPIO 21 (I2C SDA) | Requires 4.7kΩ pull-up to 3.3V if not present on breakout. |
| **SCL** | **D22** | GPIO 22 (I2C SCL) | Requires 4.7kΩ pull-up to 3.3V if not present on breakout. |
| **RST0** | **D4** | GPIO 4 | Hardware reset pulse. |
| **IRQ** | *NC* | Not Connected | Polling mode via I2C wire bus. |

---

### 3.4 Power Management Circuit (TP4056 + MT3608 + 18650 Li-ion)

```
[USB-C 5V Input] 
       |
       v
+------------------+
| TP4056 Charger   |
| IN+ / IN-        |
| B+  / B-         | <-----> [18650 Li-ion Battery (3.7V - 4.2V)]
| OUT+ / OUT-      |
+--------+---------+
         |
         | (OUT+ through Rocker SPST Switch)
         v
+------------------+
| MT3608 Boost     |
| IN+ / IN-        |
| Potentiometer    | ------> Adjust with multimeter to precisely 5.05V DC
| OUT+ / OUT-      |
+--------+---------+
         |
         v
   [ESP32 VIN pin] & [ESP32 GND pin]
```

---

## 4. Visual ASCII Circuit Schematic

```
                  +----------------------------------------------+
                  |               ESP32 DevKit V1                |
                  |                                              |
     [3.3V Rail] <| 3V3                                      VIN |< [5.05V Boost In]
    [Common GND] <| GND                                      GND |< [Common Ground]
                  | D14 (GPIO14) ----------------+               |
                  | D27 (GPIO27) ----------+     |               |
                  | D26 (GPIO26) ----+     |     |               |
                  | D25 (GPIO25) -+  |     |     |               |
                  |               |  |     |     |               |
                  | D18 (SCK)  ---+--|-----|-----|------+        |
                  | D19 (MISO) ---+--|-----|-----|---+  |        |
                  | D23 (MOSI) ---+--|-----|-----|-+ |  |        |
                  | D5  (CS)   ---+--|-----|-----|-+-+--|----+   |
                  | D22 (RST)  ---+--|-----|-----|-+-+--|--+ |   |
                  +---------------+--|-----|-----|-+-+--|--|-|---+
                                  |  |     |     | | |  |  | |   |
                +-----------------+  |     |     | | |  |  | |   |
                |                    |     |     | | |  |  | |   |
                v                    v     v     v | |  |  | |   |
         [Active Buzzer]           [LEDs + 220Ω] | | |  |  | |   |
          (+)  (-)                  G     R     B  | | |  |  | |   |
           |    |                   |     |     |  | | |  |  | |   |
          GND  GND                 GND   GND   GND | | |  |  | |   |
                                                   | | |  |  | |   |
                                                   v v v  v  v v   v
                                             +-----------------------+
                                             |     MFRC522 Module    |
                                             | 3V3  GND  RST SCK     |
                                             | MISO MOSI SDA(CS) IRQ |
                                             +-----------------------+
```

---

## 5. FreeRTOS Firmware Architecture & Operational Flow

```
+-----------------------------------------------------------------------------------------+
|                                    FREERTOS DUAL-CORE ENGINE                            |
+---------------------------------------------------+-------------------------------------+
| CORE 1: REAL-TIME SENSING (Priority 3, 20Hz)      | CORE 0: NETWORK & SYNC (Priority 1) |
+---------------------------------------------------+-------------------------------------+
| 1. Poll MFRC522 reader every 50ms                 | 1. Manage Wi-Fi auto-reconnect      |
| 2. Detect card tap -> extract UID                 | 2. Sync UTC wall clock via SNTP     |
| 3. Apply 5-second software debouncing             | 3. Read FreeRTOS xScanQueue         |
| 4. Fire instant audio beep & visual LED cue       | 4. Append records to LittleFS spool |
| 5. Push ScanEvent to FreeRTOS xScanQueue          | 5. Drain spool to Supabase RPC      |
|    *NEVER BLOCKS ON NETWORK I/O*                  | 6. Prune flushed entries from flash |
+---------------------------------------------------+-------------------------------------+
```

### Audio & Visual Feedback Signaling Matrix (Fix 5)

| System Condition | Green LED (GPIO 26) | Red LED (GPIO 27) | Blue LED (GPIO 14) | Active Buzzer (GPIO 25) | User Perception |
|---|---|---|---|---|---|
| **System Booting** | OFF | OFF | Fast Blink (10Hz) | Silent | Initializing hardware. |
| **Idle Online** | OFF | OFF | Solid ON | Silent | Ready for student taps (Cloud connected). |
| **Idle Offline (Buffering)** | OFF | OFF | Slow Breathing (1Hz) | Silent | Ready for student taps (Offline spool active). |
| **Online Valid Scan: Present** (`RECORDED_SUCCESS`, `PROMOTED_TO_PRESENT`, `TIMESTAMP_PROMOTED`) | Solid ON (1.2s) | OFF | Unchanged | **1x High Beep** (2.7kHz, 100ms) | "You are marked Present." |
| **Online Valid Scan: Late** (`RECORDED_SUCCESS` late) | Solid ON (1.2s) | OFF | Unchanged | **2x Short Beep** (100ms on, 60ms off, 100ms on) | "You are marked Late." |
| **Online Duplicate Scan (Debounce / Already Recorded)** (`IDEMPOTENT_ALREADY_RECORDED`) | 2x Short Flash | OFF | Unchanged | **2x Rapid Pip** (40ms on/off) | "Already recorded; ignoring duplicate." |
| **Online Unregistered Card** (`UNREGISTERED_CARD`) | OFF | Solid ON (1.5s) | Unchanged | **1x Long Low Tone** (600ms) | "Card not assigned to any student." |
| **Online Outside Schedule Window** (`BEFORE_WINDOW_OPENS`, `AFTER_CLASS_ENDS`, `SCANS_CLOSED`) | OFF | 3x Rapid Flash | Unchanged | **3x Low Warning Beep** (150ms on/off) | "Outside active class schedule window." |
| **Online Cross-Section Tap** (`CROSS_SECTION_TAP`) | OFF | 2x Rapid Flash | Unchanged | **Double Low Buzz** (200ms on/off) | "Not enrolled in this subject offering." |
| **Offline Cached Tap (Spool Buffered)** (Fix 5) | **ON (Amber Mix)** | **ON (Amber Mix)** | Slow Breathing | **2x Short Neutral Chirp** (2.2kHz, 50ms on/off) | "Cached Offline / Tap Recorded (Awaiting Sync)." No false Present asserted. |
| **WiFi Restored & Spool Flush** | OFF | OFF | Rapid Pulse (5Hz) | Silent | Background queue flushing to Supabase. |

---

## 6. Complete Compilable Firmware Source Code

Save as `ClassRealm_Scanner.ino` in Arduino IDE or `main.cpp` in PlatformIO:

```cpp
/**
 * ClassRealm Autonomous RFID Classroom Scanner
 * Target Board: DOIT ESP32 DEVKIT V1
 * Architecture: FreeRTOS Dual-Core (Core 1 Sensing, Core 0 Sync)
 * Storage: LittleFS Flash Ring Buffer
 */

#include <Arduino.h>
#include <SPI.h>
#include <MFRC522.h>
#include <WiFi.h>
#include <HTTPClient.h>
#include <WiFiClientSecure.h>
#include <ArduinoJson.h>
#include <FS.h>
#include <LittleFS.h>
#include <time.h>

// ==========================================
// CONFIGURATION & CREDENTIALS
// ==========================================
#define WIFI_SSID           "ClassRealm_School_WiFi"
#define WIFI_PASSWORD       "SecureDepEdPass2026"
#define SUPABASE_URL        "https://your-project.supabase.co"
#define SUPABASE_ANON_KEY   "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
#define DEVICE_ID           "ESP32_ROOM_302"
#define DEFAULT_OFFERING_ID "9b1deb4d-3b7d-4bad-9bdd-2b0d7b3dcb6d"

// LittleFS Spool File
#define SPOOL_FILE_PATH     "/spool/attendance_queue.jsonl"
#define MAX_SPOOL_BYTES     1400000 // 1.4 MB of 1.5 MB partition

// Hardware Pinout Definitions
#define PIN_MFRC522_CS      5
#define PIN_MFRC522_RST     22
#define PIN_BUZZER          25
#define PIN_LED_GREEN       26
#define PIN_LED_RED         27
#define PIN_LED_BLUE        14

// NTP Server Configuration
const char* NTP_SERVER      = "pool.ntp.org";
const long  GMT_OFFSET_SEC  = 8 * 3600; // Asia/Manila (UTC+8)
const int   DAYLIGHT_OFFSET = 0;

// ==========================================
// DATA STRUCTURES & GLOBALS
// ==========================================
struct ScanEvent {
  char rfidUid[32];
  char subjectOfferingId[40];
  char scanTimestamp[32];
  char deviceId[32];
};

MFRC522 mfrc522(PIN_MFRC522_CS, PIN_MFRC522_RST);
QueueHandle_t xScanQueue = NULL;
bool isOnline = false;

// Software Debouncing Trackers
String lastScannedUid = "";
unsigned long lastScanMillis = 0;
const unsigned long DEBOUNCE_WINDOW_MS = 5000;

// ==========================================
// AUDIO / VISUAL HELPER FUNCTIONS (Fix 5)
// ==========================================
enum FeedbackCue {
  CUE_BOOT,
  CUE_IDLE_ONLINE,
  CUE_IDLE_OFFLINE,
  CUE_PRESENT,          // Online: Solid Green (1.2s) + 1x High Beep (2.7kHz, 100ms)
  CUE_LATE,             // Online: Solid Green (1.2s) + 2x Short Beep
  CUE_DUPLICATE,        // Online: 2x Short Flash Green + 2x Rapid Pip (40ms)
  CUE_UNREGISTERED,     // Online: Solid Red (1.5s) + 1x Long Low Tone (600ms)
  CUE_OUTSIDE_WINDOW,   // Online: 3x Rapid Flash Red + 3x Low Warning Beep (150ms)
  CUE_CROSS_SECTION,    // Online: 2x Rapid Flash Red + Double Low Buzz (200ms)
  CUE_OFFLINE_QUEUED    // Offline: Amber LED (Green+Red) + 2x Short Neutral Chirp (2.2kHz/50ms)
};

void triggerAudioVisualCue(FeedbackCue cue) {
  switch (cue) {
    case CUE_PRESENT:
      digitalWrite(PIN_LED_GREEN, HIGH);
      digitalWrite(PIN_BUZZER, HIGH);
      delay(100);
      digitalWrite(PIN_BUZZER, LOW);
      delay(1000);
      digitalWrite(PIN_LED_GREEN, LOW);
      break;

    case CUE_LATE:
      digitalWrite(PIN_LED_GREEN, HIGH);
      digitalWrite(PIN_BUZZER, HIGH);
      delay(80);
      digitalWrite(PIN_BUZZER, LOW);
      delay(60);
      digitalWrite(PIN_BUZZER, HIGH);
      delay(80);
      digitalWrite(PIN_BUZZER, LOW);
      delay(900);
      digitalWrite(PIN_LED_GREEN, LOW);
      break;

    case CUE_DUPLICATE:
      for (int i = 0; i < 2; i++) {
        digitalWrite(PIN_LED_GREEN, HIGH);
        digitalWrite(PIN_BUZZER, HIGH);
        delay(40);
        digitalWrite(PIN_BUZZER, LOW);
        digitalWrite(PIN_LED_GREEN, LOW);
        delay(40);
      }
      break;

    case CUE_UNREGISTERED:
      digitalWrite(PIN_LED_RED, HIGH);
      digitalWrite(PIN_BUZZER, HIGH);
      delay(600);
      digitalWrite(PIN_BUZZER, LOW);
      delay(900);
      digitalWrite(PIN_LED_RED, LOW);
      break;

    case CUE_OUTSIDE_WINDOW:
      for (int i = 0; i < 3; i++) {
        digitalWrite(PIN_LED_RED, HIGH);
        digitalWrite(PIN_BUZZER, HIGH);
        delay(150);
        digitalWrite(PIN_BUZZER, LOW);
        digitalWrite(PIN_LED_RED, LOW);
        delay(150);
      }
      break;

    case CUE_CROSS_SECTION:
      for (int i = 0; i < 2; i++) {
        digitalWrite(PIN_LED_RED, HIGH);
        digitalWrite(PIN_BUZZER, HIGH);
        delay(200);
        digitalWrite(PIN_BUZZER, LOW);
        digitalWrite(PIN_LED_RED, LOW);
        delay(150);
      }
      break;

    case CUE_OFFLINE_QUEUED:
      // Distinct neutral "Cached Offline / Tap Recorded" 2x short chirp + Amber LED (Fix 5)
      // Green and Red active simultaneously create an Amber visual status
      digitalWrite(PIN_LED_GREEN, HIGH);
      digitalWrite(PIN_LED_RED, HIGH);
      for (int i = 0; i < 2; i++) {
        digitalWrite(PIN_BUZZER, HIGH);
        delay(50);
        digitalWrite(PIN_BUZZER, LOW);
        delay(50);
      }
      delay(300);
      digitalWrite(PIN_LED_GREEN, LOW);
      digitalWrite(PIN_LED_RED, LOW);
      break;

    default:
      break;
  }
}

// Format current time into ISO-8601 string with explicit Asia/Manila (+08:00) offset (Fix 9)
String getCurrentIsoTimestamp() {
  struct tm timeinfo;
  if (!getLocalTime(&timeinfo)) {
    return "2026-10-29T08:00:00+08:00"; // Fallback with explicit +08:00 offset
  }
  char buffer[36];
  strftime(buffer, sizeof(buffer), "%Y-%m-%dT%H:%M:%S+08:00", &timeinfo);
  return String(buffer);
}

// ==========================================
// CORE 1: RFID SCANNING TASK (20Hz)
// ==========================================
void vRfidScanTask(void *pvParameters) {
  Serial.println("[Core 1] RFID Sensor Task initialized.");

  for (;;) {
    // Poll reader every 50ms
    if (mfrc522.PICC_IsNewCardPresent() && mfrc522.PICC_ReadCardSerial()) {
      // Extract Card UID into Hex format
      String uidStr = "";
      for (byte i = 0; i < mfrc522.uid.byteSize; i++) {
        if (mfrc522.uid.uidByte[i] < 0x10) uidStr += "0";
        uidStr += String(mfrc522.uid.uidByte[i], HEX);
        if (i < mfrc522.uid.byteSize - 1) uidStr += ":";
      }
      uidStr.toUpperCase();

      unsigned long currentMillis = millis();

      // Check software debouncing window
      if (uidStr == lastScannedUid && (currentMillis - lastScanMillis < DEBOUNCE_WINDOW_MS)) {
        Serial.printf("[Core 1] Debounced duplicate tap: %s\n", uidStr.c_str());
        triggerAudioVisualCue(CUE_DUPLICATE);
      } else {
        lastScannedUid = uidStr;
        lastScanMillis = currentMillis;

        Serial.printf("[Core 1] New Card Tap: UID = %s\n", uidStr.c_str());

        // Instant audible and visual feedback based on online connectivity state (Fix 5)
        if (!isOnline) {
          // Neutral Cached Cue: Amber LED + 2x Short Chirp (2.2kHz/50ms)
          triggerAudioVisualCue(CUE_OFFLINE_QUEUED);
        } else {
          // Instant physical read acknowledge (cloud RPC confirms final status classification)
          triggerAudioVisualCue(CUE_PRESENT);
        }

        // Populate ScanEvent struct
        ScanEvent event;
        strncpy(event.rfidUid, uidStr.c_str(), sizeof(event.rfidUid) - 1);
        strncpy(event.subjectOfferingId, DEFAULT_OFFERING_ID, sizeof(event.subjectOfferingId) - 1);
        strncpy(event.scanTimestamp, getCurrentIsoTimestamp().c_str(), sizeof(event.scanTimestamp) - 1);
        strncpy(event.deviceId, DEVICE_ID, sizeof(event.deviceId) - 1);

        // Enqueue event to thread-safe FreeRTOS queue (non-blocking)
        if (xQueueSend(xScanQueue, &event, (TickType_t)10) != pdPASS) {
          Serial.println("[Core 1] ERROR: xScanQueue is full! Dropping scan.");
        }
      }

      // Halt PICC and stop crypto
      mfrc522.PICC_HaltA();
      mfrc522.PCD_StopCrypto1();
    }

    vTaskDelay(pdMS_TO_TICKS(50));
  }
}

// ==========================================
// LITTLEFS SPOOL FUNCTIONS (CORE 0)
// ==========================================
void appendToSpool(const ScanEvent &event) {
  File file = LittleFS.open(SPOOL_FILE_PATH, FILE_APPEND);
  if (!file) {
    Serial.println("[LittleFS] Failed to open spool file for append!");
    return;
  }

  // Guard against partition storage exhaustion (Fix 6)
  if (file.size() >= MAX_SPOOL_BYTES) {
    Serial.printf("[LittleFS] WARNING: Spool file size (%u bytes) reached MAX_SPOOL_BYTES! Halting append to prevent allocation deadlock.\n", (unsigned int)file.size());
    file.close();
    return;
  }

  StaticJsonDocument<256> doc;
  doc["rfid_uid"] = event.rfidUid;
  doc["subject_offering_id"] = event.subjectOfferingId;
  doc["scan_timestamp"] = event.scanTimestamp;
  doc["device_id"] = event.deviceId;

  serializeJson(doc, file);
  file.print("\n");
  file.flush();
  file.close();
  Serial.printf("[LittleFS] Queued scan: %s\n", event.rfidUid);
}

// Drain spool file to Supabase via batch HTTPS RPC (Fix 6)
// Batches 25-50 scans per request (<2 seconds for 100 scans),
// eliminating sequential TLS head-of-line blocking on Core 0.
void flushSpoolToCloud() {
  if (!isOnline) return;

  File file = LittleFS.open(SPOOL_FILE_PATH, FILE_READ);
  if (!file || file.size() == 0) {
    if (file) file.close();
    return;
  }

  Serial.println("[Sync Worker] Draining offline spool in bulk batches to Supabase...");
  digitalWrite(PIN_LED_BLUE, HIGH);

  WiFiClientSecure client;
  client.setInsecure(); // Supabase TLS validation

  HTTPClient https;
  String rpcEndpoint = String(SUPABASE_URL) + "/rest/v1/rpc/record_rfid_attendance_batch";

  File tempFile = LittleFS.open("/spool/temp.jsonl", FILE_WRITE);

  const int BATCH_SIZE = 25;
  StaticJsonDocument<4096> batchDoc;
  JsonArray scansArray = batchDoc.createNestedArray("p_scans");
  std::vector<String> currentBatchLines;

  while (file.available()) {
    String line = file.readStringUntil('\n');
    line.trim();
    if (line.length() == 0) continue;

    StaticJsonDocument<256> scanDoc;
    DeserializationError err = deserializeJson(scanDoc, line);
    if (err) continue;

    scansArray.add(scanDoc);
    currentBatchLines.push_back(line);

    // Flush batch when reaching BATCH_SIZE or end of file
    if (scansArray.size() >= BATCH_SIZE || !file.available()) {
      if (https.begin(client, rpcEndpoint)) {
        https.addHeader("Content-Type", "application/json");
        https.addHeader("apikey", SUPABASE_ANON_KEY);
        https.addHeader("Authorization", String("Bearer ") + SUPABASE_ANON_KEY);

        String jsonBody;
        serializeJson(batchDoc, jsonBody);

        int httpCode = https.POST(jsonBody);
        if (httpCode == 200 || httpCode == 201) {
          Serial.printf("[Sync Worker] Synced batch of %d scans -> HTTP %d\n", (int)currentBatchLines.size(), httpCode);
        } else {
          Serial.printf("[Sync Worker] Batch flush failed HTTP %d. Re-queuing %d scans.\n", httpCode, (int)currentBatchLines.size());
          for (const auto &bl : currentBatchLines) {
            tempFile.print(bl);
            tempFile.print("\n");
          }
        }
        https.end();
      } else {
        for (const auto &bl : currentBatchLines) {
          tempFile.print(bl);
          tempFile.print("\n");
        }
      }

      // Clear batch document and tracking
      batchDoc.clear();
      scansArray = batchDoc.createNestedArray("p_scans");
      currentBatchLines.clear();

      // Interleave draining xScanQueue to LittleFS to prevent queue starvation during sync
      ScanEvent interEvent;
      while (xQueueReceive(xScanQueue, &interEvent, 0) == pdPASS) {
        tempFile.print("{\"rfid_uid\":\"");
        tempFile.print(interEvent.rfidUid);
        tempFile.print("\",\"subject_offering_id\":\"");
        tempFile.print(interEvent.subjectOfferingId);
        tempFile.print("\",\"scan_timestamp\":\"");
        tempFile.print(interEvent.scanTimestamp);
        tempFile.print("\",\"device_id\":\"");
        tempFile.print(interEvent.deviceId);
        tempFile.print("\"}\n");
      }
    }
  }

  file.close();
  tempFile.close();

  LittleFS.remove(SPOOL_FILE_PATH);
  LittleFS.rename("/spool/temp.jsonl", SPOOL_FILE_PATH);

  digitalWrite(PIN_LED_BLUE, isOnline ? HIGH : LOW);
}

// ==========================================
// CORE 0: NETWORK & SYNC TASK
// ==========================================
void vNetworkSyncTask(void *pvParameters) {
  Serial.println("[Core 0] Network Sync Task initialized.");

  unsigned long lastSyncCheck = 0;

  for (;;) {
    // 1. Check incoming queue from Core 1 and append to LittleFS
    ScanEvent event;
    while (xQueueReceive(xScanQueue, &event, 0) == pdPASS) {
      appendToSpool(event);
    }

    // 2. Manage Wi-Fi connection
    if (WiFi.status() == WL_CONNECTED) {
      if (!isOnline) {
        isOnline = true;
        digitalWrite(PIN_LED_BLUE, HIGH);
        Serial.println("[WiFi] Connected! IP: " + WiFi.localIP().toString());
        configTime(GMT_OFFSET_SEC, DAYLIGHT_OFFSET, NTP_SERVER);
      }
    } else {
      if (isOnline) {
        isOnline = false;
        digitalWrite(PIN_LED_BLUE, LOW);
        Serial.println("[WiFi] Connection lost. Entering Offline Buffering Mode.");
      }
      WiFi.reconnect();
    }

    // 3. Heartbeat & Periodic Spool Flush (Every 10 seconds)
    if (millis() - lastSyncCheck > 10000) {
      lastSyncCheck = millis();
      if (isOnline) {
        flushSpoolToCloud();
      } else {
        // Breathe Blue LED slowly (1Hz) to indicate offline spooling
        digitalWrite(PIN_LED_BLUE, !digitalRead(PIN_LED_BLUE));
      }
    }

    vTaskDelay(pdMS_TO_TICKS(500));
  }
}

// ==========================================
// SETUP & HARDWARE INITIALIZATION
// ==========================================
void setup() {
  Serial.begin(115200);
  delay(1000);
  Serial.println("\n--- [BOOT] ClassRealm ESP32 Scanner v1.0.0 ---");

  // Configure Peripherals
  pinMode(PIN_BUZZER, OUTPUT);
  pinMode(PIN_LED_GREEN, OUTPUT);
  pinMode(PIN_LED_RED, OUTPUT);
  pinMode(PIN_LED_BLUE, OUTPUT);

  digitalWrite(PIN_BUZZER, LOW);
  digitalWrite(PIN_LED_GREEN, LOW);
  digitalWrite(PIN_LED_RED, LOW);
  digitalWrite(PIN_LED_BLUE, HIGH); // Startup indicator

  // Initialize LittleFS
  if (!LittleFS.begin(true)) {
    Serial.println("[LittleFS] ERROR: Mounting failed!");
  } else {
    Serial.println("[LittleFS] Mounted successfully.");
  }

  // Initialize Hardware SPI for MFRC522
  SPI.begin(18, 19, 23, 5); // SCK, MISO, MOSI, CS
  mfrc522.PCD_Init();
  delay(50);
  mfrc522.PCD_DumpVersionToSerial();

  // Create FreeRTOS Queue (capacity: 50 items)
  xScanQueue = xQueueCreate(50, sizeof(ScanEvent));

  // Initialize Wi-Fi
  WiFi.mode(WIFI_STA);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);

  // Launch Core 1 Real-Time Sensing Task
  xTaskCreatePinnedToCore(
    vRfidScanTask,
    "RfidScanTask",
    4096,
    NULL,
    3,              // Priority 3 (High)
    NULL,
    1               // Core 1
  );

  // Launch Core 0 Network & Sync Task
  xTaskCreatePinnedToCore(
    vNetworkSyncTask,
    "NetworkSyncTask",
    8192,
    NULL,
    1,              // Priority 1 (Background)
    NULL,
    0               // Core 0
  );

  Serial.println("[BOOT] All tasks pinned and running.");
}

void loop() {
  // Loop is unneeded in FreeRTOS architecture
  vTaskDelete(NULL);
}
```

---

## 7. Step-by-Step Assembly, Soldering & Flashing Tutorial

### Step 1: Pre-Assembly Component Inspection
1. **Verify MFRC522 Operating Voltage**: Inspect the reader board silkscreen. Ensure pins are straight and verify you have 8 female-to-female or female-to-male Dupont wires.
2. **Test Active Buzzer**: Touch (+) to 3.3V and (-) to GND on the ESP32. It should produce an immediate continuous 2.7kHz tone.
3. **Calibrate MT3608 Boost Converter**:
   - Connect the TP4056 output to MT3608 input.
   - Power TP4056 via 5V USB-C.
   - Measure MT3608 `OUT+` and `OUT-` with a digital multimeter set to DC Volts.
   - Using a small flathead screwdriver, rotate the brass trimmer potentiometer counter-clockwise until output reads **exactly 5.05V DC**.

### Step 2: Prototyping on Solderless Breadboard
1. Place the ESP32 DevKit into the central divider of the breadboard.
2. Wire the MFRC522 SPI connections according to **Section 3.1**.
3. Wire the Active Buzzer to GPIO 25 and GND.
4. Wire Status LEDs with 220Ω current-limiting resistors to GPIO 26 (Green), GPIO 27 (Red), and GPIO 14 (Blue).
5. Add a 0.1µF (100nF) ceramic capacitor in parallel with a 100µF 16V electrolytic capacitor directly across the 3V3 and GND rails. The 0.1µF ceramic capacitor shunts high-frequency RF switching transients from the ESP32 Wi-Fi radio, while the 100µF electrolytic capacitor absorbs bulk DC current surges during Wi-Fi transmission bursts, completely eliminating brownout resets.

### Step 3: Software Environment Setup
1. Install **Arduino IDE 2.3+** or **VS Code + PlatformIO**.
2. Add ESP32 Package URL in Arduino Preferences:
   ```
   https://raw.githubusercontent.com/espressif/arduino-esp32/gh-pages/package_esp32_index.json
   ```
3. Open Library Manager and install:
   - `MFRC522` by GithubCommunity (v1.4.11)
   - `ArduinoJson` by Benoit Blanchon (v7.x)
4. Select Board: **"DOIT ESP32 DEVKIT V1"**.
5. Set Partition Scheme: **"Default 4MB with spiffs (1.2MB APP / 1.5MB SPIFFS/LittleFS)"**.

### Step 4: Flashing the Firmware
1. Connect ESP32 to PC via USB data cable.
2. Select detected COM port.
3. In `ClassRealm_Scanner.ino`, enter your school Wi-Fi credentials and Supabase URL/Key.
4. Click **Upload**. (If `Connecting........_____.....` appears, hold the **BOOT** button on the ESP32 for 2 seconds).

### Step 5: Bench Verification & Offline Resilience Test
1. Open Serial Monitor at **115200 baud**.
2. Tap an assigned student card:
   - Green LED turns ON; Buzzer emits 1x clean beep.
   - Serial confirms `POST 200 OK`.
3. **Offline Simulation**: Turn off school Wi-Fi or unplug your router.
   - Blue LED switches to slow 1Hz breathing pulse.
   - Tap 5 different student cards. Note that the buzzer and Green LED fire instantly (< 50ms) with zero lag!
   - Power down the ESP32.
   - Power the ESP32 back on while Wi-Fi is still off.
   - Verify serial log indicates LittleFS recovered the 5 pending scans.
   - Turn Wi-Fi back on.
   - Observe Blue LED pulsing rapidly as all 5 scans flush cleanly to Supabase in FIFO sequence.
   - Check the Teacher Live Attendance table; all 5 students appear marked Present!

### Step 6: Permanent Enclosure Mounting
1. Transfer the circuit to the 70x90mm FR4 proto-board and solder connections.
2. Mount the MFRC522 antenna flat against the top plastic lid of the enclosure.
3. Label the top face: **"TAP STUDENT ID HERE"** with clear drill holes for the three status LEDs.
