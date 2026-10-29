## 2026-10-29T09:34:24Z
You are teamwork_worker assigned as Plan Hardening Worker (Iteration 2).
Your Working Directory is: c:\Users\Admin\AndroidStudioProjects\class_realm01\.agents\teamwork\worker_plan_2
Original Request path: c:\Users\Admin\AndroidStudioProjects\class_realm01\.agents\teamwork\ORIGINAL_REQUEST.md

MANDATORY INTEGRITY WARNING:
DO NOT CHEAT. All implementations must be genuine. DO NOT hardcode test results, create dummy/facade implementations, or circumvent the intended task. A teamwork_auditor will independently verify your work. Integrity violations WILL be detected and your work WILL be rejected.

MANDATORY INSTRUCTIONS:
1. You MUST read c:\Users\Admin\AndroidStudioProjects\class_realm01\.agents\teamwork\ORIGINAL_REQUEST.md first before starting work.
2. Read the handoff reports from:
   - Challenger 1: c:\Users\Admin\AndroidStudioProjects\class_realm01\.agents\teamwork\challenger_plan_1\handoff.md
   - Challenger 2: c:\Users\Admin\AndroidStudioProjects\class_realm01\.agents\teamwork\challenger_plan_2\handoff.md
   - Reviewer 1 (gen2): c:\Users\Admin\AndroidStudioProjects\class_realm01\.agents\teamwork\reviewer_plan_1_gen2\handoff.md

3. Target files to update and harden:
   a) `c:\Users\Admin\AndroidStudioProjects\class_realm01\docs\ATTENDANCE_REDESIGN_IMPLEMENTATION_PLAN.md`
   b) `c:\Users\Admin\AndroidStudioProjects\class_realm01\docs\ESP32_RFID_BUILD_GUIDE.md`
   c) `c:\Users\Admin\AndroidStudioProjects\class_realm01\docs\ATTENDANCE_VALIDATION_MATRIX.md`
   d) `c:\Users\Admin\AndroidStudioProjects\class_realm01\PROJECT.md`

4. Concrete Hardening Requirements:
   - Fix 1 (Challenger 1 - Timestamp Priority): In `record_rfid_attendance`, when existing record is `present` and an earlier on-time tap arrives (`v_scan_time < v_existing.time_in`), update `v_existing.time_in = v_scan_time` and `remarks = 'Timestamp updated to earlier physical tap'`, returning status `TIMESTAMP_PROMOTED`.
   - Fix 2 (Challenger 1 - System Auto-Absent Promotion): In `record_rfid_attendance`, allow delayed offline taps to overwrite/promote records where `v_existing.status = 'absent' AND v_existing.recording_method = 'System'`. When an on-time or late tap from yesterday arrives from ESP32 spool, promote it to `present` or `late` with the physical tap timestamp. (Strictly keep manual teacher edits `recording_method = 'Manual'` or `status = 'excused'` immutable).
   - Fix 3 (Challenger 1 - Cutoff Logic & Naming): Correct variable naming in `record_rfid_attendance` to use `v_present_grace_cutoff`, `v_late_cutoff`, and `v_absent_cutoff`. Read `v_cutoffs.absent_cutoff_mins`. Reject taps arriving after `v_absent_cutoff` as outside cutoff window.
   - Fix 4 (Challenger 1 - Schema Constraints): In `008_attendance_overhaul.sql`, update `CHECK (absent_cutoff_mins > late_cutoff_mins)` to use strict `>`. Add database validation trigger preventing cutoff values from exceeding class duration.
   - Fix 5 (Challenger 2 - Hardware Signaling): Update `docs/ESP32_RFID_BUILD_GUIDE.md` and firmware:
     * When online: ESP32 receives atomic RPC response code and triggers matching cues (Present = Green/High Beep; Late = Green/2x Beep; Unregistered = Red/Long Low Tone; Outside Window = Red/3x Low Warning; Cross-section = Red/Double Low Buzz).
     * When offline: ESP32 triggers a distinct neutral "Cached Offline / Tap Recorded" 2x short chirp (2.2kHz/50ms) + Amber LED, so students and teachers know it was spooled without falsely asserting Present on an unregistered card.
   - Fix 6 (Challenger 2 - LittleFS & Batch Sync): Add `file.size() >= MAX_SPOOL_BYTES` guard in `appendToSpool()`. Specify `record_rfid_attendance_batch(p_scans jsonb)` in PostgreSQL and ESP32 firmware to drain offline queues in bulk (<2 seconds for 100 scans), eliminating sequential TLS head-of-line blocking on Core 0.
   - Fix 7 (Challenger 2 - Decoupling Capacitor): In Section 7 Step 2.5 of `docs/ESP32_RFID_BUILD_GUIDE.md`, explicitly instruct soldering the 0.1µF ceramic capacitor in parallel with the 100µF electrolytic capacitor across 3V3 and GND rails.
   - Fix 8 (Challenger 2 - Nomenclature): In `docs/ATTENDANCE_VALIDATION_MATRIX.md` Scenario E7, change "Visual Holiday Banner" to "Visual Holiday Status Pill / Header Badge".
   - Fix 9 (Reviewer 1 - Timezone): Explicitly format ESP32 ISO8601 timestamps with Asia/Manila (+08:00) offset.

5. Verification & Completion:
   - Run `flutter test test/models/attendance_workspace_models_test.dart` to verify no regressions.
   - Verify that NO source code files in `lib/` or `test/` are touched.
   - Write `handoff.md` in your working directory documenting all changes made.
   - Send completion message to parent via send_message.
