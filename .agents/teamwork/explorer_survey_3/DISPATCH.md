## 2026-10-29T08:58:44Z
**From**: ec7be328-03fe-4f87-8a31-6d9437e7a1a8 (parent)
**Priority**: MESSAGE_PRIORITY_HIGH
**Content**:
You are teamwork_explorer assigned to Survey Phase (Hardware & Offline Synchronization Architecture).
Your Working Directory is: c:\Users\Admin\AndroidStudioProjects\class_realm01\.agents\teamwork\explorer_survey_3
Original Request path: c:\Users\Admin\AndroidStudioProjects\class_realm01\.agents\teamwork\ORIGINAL_REQUEST.md

MANDATORY INSTRUCTIONS:
1. You MUST read c:\Users\Admin\AndroidStudioProjects\class_realm01\.agents\teamwork\ORIGINAL_REQUEST.md first before anything else.
2. Objective: Investigate and architect:
   - Existing Flutter dependencies for NFC (e.g. nfc_manager), offline caching/storage (e.g. shared_preferences, sqflite, hive, or connectivity_plus).
   - Dual-path offline attendance capture pipeline:
     a) Primary standalone hardware device: ESP32 RFID scanner that functions autonomously when offline/laptop closed, buffers scans in non-volatile storage (NVS / SPIFFS / LittleFS), and syncs to Supabase on reconnection.
     b) Fallback mobile app NFC: Teacher mobile scanning student RFID cards via phone NFC, caching locally when offline, and auto-syncing when back online.
   - Comprehensive ESP32 Hardware Build Guide & Tutorial:
     - Bill of Materials (BOM) with specifications: ESP32 DevKit V1 (30 or 38 pin), RFID Reader (MFRC522 SPI vs PN532 I2C/SPI), Active Buzzer, Dual/Tricolor Status LEDs (or separate Green/Red/Blue LEDs), Resistors, Power/Battery management circuit (18650 Li-ion + TP4056 + boost converter or 5V USB-C power bank).
     - Exact pinout wiring diagrams / tables for SPI and I2C configurations.
     - Firmware operational flow (Arduino / ESP-IDF / FreeRTOS architecture, state machine, WiFi auto-reconnect, NVS queue buffering, HTTP/REST/Supabase client, buzzer/LED feedback patterns).
   - Synchronization & Conflict Resolution:
     - Conflict-free offline sync protocol between ESP32 queue, Mobile offline queue, and teacher manual roster edits.
     - Idempotency guarantees, timestamp ordering, determinism, deduplication, and schedule validation rules.
3. Scope boundaries: You are READ-ONLY. Do NOT modify any files in the codebase. Write only within your working directory: c:\Users\Admin\AndroidStudioProjects\class_realm01\.agents\teamwork\explorer_survey_3\
4. Output requirements:
   - Maintain progress.md as your heartbeat.
   - Write your comprehensive survey and architecture report to `handoff.md` in your working directory.
   - Include complete circuit wiring pinout tables, firmware state machine diagrams, step-by-step build & flashing tutorial, offline sync queue schema, and conflict resolution rules.
5. Completion criteria: Complete handoff.md with verified details and send a completion message with the path to handoff.md to your parent via send_message.
