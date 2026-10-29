## 2026-10-29T09:11:11Z
You are teamwork_worker assigned to author the Comprehensive Attendance Feature Redesign & Implementation Plan deliverable.
Your Working Directory is: c:\Users\Admin\AndroidStudioProjects\class_realm01\.agents\teamwork\worker_plan_1
Original Request path: c:\Users\Admin\AndroidStudioProjects\class_realm01\.agents\teamwork\ORIGINAL_REQUEST.md

MANDATORY INTEGRITY WARNING:
DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A teamwork_auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.

MANDATORY INSTRUCTIONS:
1. You MUST read c:\Users\Admin\AndroidStudioProjects\class_realm01\.agents\teamwork\ORIGINAL_REQUEST.md first before starting work.
2. Read the comprehensive survey handoffs from the 3 Explorers:
   - Explorer 1 (Backend/Database/Schedules/RLS): c:\Users\Admin\AndroidStudioProjects\class_realm01\.agents\teamwork\explorer_survey_1\handoff.md
   - Explorer 2 (Frontend/UI-UX/Theming/Error Audit): c:\Users\Admin\AndroidStudioProjects\class_realm01\.agents\teamwork\explorer_survey_2\handoff.md
   - Explorer 3 (ESP32 Hardware/NFC Mobile/Offline Sync): c:\Users\Admin\AndroidStudioProjects\class_realm01\.agents\teamwork\explorer_survey_3\handoff.md

3. Scope Boundaries:
   - DO NOT modify application source code in `lib/` or `test/`.
   - Your assigned exclusive files to write are:
     a) `c:\Users\Admin\AndroidStudioProjects\class_realm01\PROJECT.md`
     b) `c:\Users\Admin\AndroidStudioProjects\class_realm01\docs\ATTENDANCE_REDESIGN_IMPLEMENTATION_PLAN.md`
     c) `c:\Users\Admin\AndroidStudioProjects\class_realm01\docs\ESP32_RFID_BUILD_GUIDE.md`
     d) `c:\Users\Admin\AndroidStudioProjects\class_realm01\docs\ATTENDANCE_VALIDATION_MATRIX.md`

4. Requirements to Address Completely:
   - R1: Master Architecture & Implementation Plan:
     Data models (Supabase SQL migrations, Drift local tables, Dart entities), API/RPC contracts, offline sync protocols, hardware build architecture, responsive screen specifications, phased rollout tasks, testing strategies.
   - R2: Teacher RFID Assignment & Recording Method Indicator:
     Unique card assignment with conflict detection, assignment modal supporting keyboard/USB wedge and phone NFC taps, attendance logs explicit indicator for 'RFID' vs 'Manual' vs 'System'.
   - R3: Schedule-Connected Auto-Status, Cutoff Validation & 11:59 PM Auto-Absent:
     Block scans outside active class window or on non-scheduled days. Chronological cutoff validation (Present start <= start; Late cutoff > Present; Absent cutoff > Late and within class duration). Daily 23:59 Asia/Manila automated job (Supabase Edge Function + pg_cron) marking unscanned enrolled students as Absent without overwriting existing marks or creating marks on holidays/non-scheduled days.
   - R4: Dual-Path Offline Capture & ESP32 Hardware Guide:
     Standalone ESP32 reader with LittleFS spooling (>6,800 scans) and FreeRTOS dual-core task segregation; mobile phone fallback via `nfc_manager` and Drift SQLite queue; complete step-by-step ESP32 hardware build guide (BOM, electrical specs, battery/power circuit with TP4056 + MT3608 + 18650, pinouts for DevKit 30/38 pin, MFRC522 SPI, PN532 I2C, buzzer, LEDs, firmware state machine, flashing guide).
   - R5: Roster Table UI/UX Redesign & 60-30-10 Theming:
     Compact data table (44px row height), alphabetical ordering, removal of circular avatars/badges, gender category tabs (All, Male, Female with grouped view by default), persistent top header "Save Attendance" action.
   - R6: Multi-Platform Attendance History & Analytics:
     Teacher view (KPIs, warnings for >=3 absences, trends, date range filters), Student view (view-only personal history strictly scoped via RLS to own records, polished empty state), Parent view (view-only child history strictly scoped via RLS to linked child records, polished empty state).
   - R7: Strict UI Error Presentation & Comprehensive Validation Matrix:
     Strict UI error rule: ZERO raw, technical, or database error messages. Strictly Inline Input Errors (red border + helper text directly under field) or Modal Dialogs (for scanner/conflict/hardware alerts). STRICTLY PROHIBIT SnackBars, floating toasts, and top/bottom banners. Exhaustive edge-case validation matrix covering RFID assignment, schedule guarding, live attendance (unregistered card, cross-section tap, duplicate tap idempotency, offline sync vs manual teacher override conflict resolution), and 11:59 PM auto-absent.

5. Output & Completion Criteria:
   - Write all 4 documents with meticulous detail, complete code blocks, circuit diagrams, and schema scripts.
   - Run verification checks (e.g. check that docs exist, are well-formatted, and contain no prohibited patterns).
   - Write `handoff.md` in your working directory documenting what was created and verified.
   - Send completion message to parent via send_message.
