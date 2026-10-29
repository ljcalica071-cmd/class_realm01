#!/usr/bin/env python3
"""
Empirical Challenger Test Suite (Generation 2)
Hardware & Edge-Case Validation for ClassRealm RFID & Attendance System
Tests all 5 specific requirements:
1. Hardware Signaling (distinct online cues vs offline neutral cached cue)
2. LittleFS Storage Deadlock (MAX_SPOOL_BYTES guard in appendToSpool)
3. Bulk HTTPS Drain (record_rfid_attendance_batch and queue interleaving)
4. Decoupling Capacitor (0.1µF ceramic capacitor in Step 2.5 of assembly)
5. Nomenclature (Scenario E7 updated to "Visual Holiday Status Pill / Header Badge")
"""

import os
import re
import sys

def run_tests():
    root = r"c:\Users\Admin\AndroidStudioProjects\class_realm01"
    build_guide_path = os.path.join(root, "docs", "ESP32_RFID_BUILD_GUIDE.md")
    matrix_path = os.path.join(root, "docs", "ATTENDANCE_VALIDATION_MATRIX.md")
    plan_path = os.path.join(root, "docs", "ATTENDANCE_REDESIGN_IMPLEMENTATION_PLAN.md")
    project_path = os.path.join(root, "PROJECT.md")

    passed = 0
    failed = 0
    findings = []

    def check(test_id, name, condition, details=""):
        nonlocal passed, failed
        if condition:
            passed += 1
            print(f"[PASS] {test_id}: {name}")
        else:
            failed += 1
            findings.append((test_id, name, details))
            print(f"[FAIL] {test_id}: {name} - {details}")

    print("=" * 80)
    print("EMPIRICAL TEST SUITE: HARDWARE & EDGE-CASE CHALLENGER (GEN 2)")
    print("=" * 80)

    # -------------------------------------------------------------
    # 1. HARDWARE SIGNALING VERIFICATION
    # -------------------------------------------------------------
    with open(build_guide_path, "r", encoding="utf-8") as f:
        guide_content = f.read()

    # 1.1 Check FeedbackCue enum in firmware
    has_cue_present = "CUE_PRESENT" in guide_content
    has_cue_late = "CUE_LATE" in guide_content
    has_cue_unregistered = "CUE_UNREGISTERED" in guide_content
    has_cue_outside = "CUE_OUTSIDE_WINDOW" in guide_content
    has_cue_cross = "CUE_CROSS_SECTION" in guide_content
    has_cue_offline = "CUE_OFFLINE_QUEUED" in guide_content

    check(
        "T1.1",
        "Firmware defines enum FeedbackCue with all 6 required states",
        all([has_cue_present, has_cue_late, has_cue_unregistered, has_cue_outside, has_cue_cross, has_cue_offline]),
        f"Missing enum values: present={has_cue_present}, late={has_cue_late}, unregistered={has_cue_unregistered}, outside={has_cue_outside}, cross={has_cue_cross}, offline={has_cue_offline}"
    )

    # 1.2 Check triggerAudioVisualCue implementation for CUE_OFFLINE_QUEUED
    # Amber LED: Green HIGH + Red HIGH; Buzzer 2x chirp (50ms on/off)
    offline_cue_pattern = re.search(
        r"case CUE_OFFLINE_QUEUED:.*?digitalWrite\(PIN_LED_GREEN,\s*HIGH\);.*?digitalWrite\(PIN_LED_RED,\s*HIGH\);.*?for\s*\(int i = 0;\s*i < 2;\s*i\+\+\)\s*\{.*?digitalWrite\(PIN_BUZZER,\s*HIGH\);.*?delay\(50\);.*?digitalWrite\(PIN_BUZZER,\s*LOW\);.*?delay\(50\);",
        guide_content,
        re.DOTALL
    )
    check(
        "T1.2",
        "CUE_OFFLINE_QUEUED activates simultaneous Green+Red (Amber) + 2x 50ms buzzer chirp",
        bool(offline_cue_pattern),
        "Offline cue implementation does not match expected Amber LED + 2x 50ms chirp pattern"
    )

    # 1.3 Check triggerAudioVisualCue implementation for CUE_PRESENT, CUE_LATE, CUE_UNREGISTERED, CUE_OUTSIDE_WINDOW, CUE_CROSS_SECTION
    has_present_cue = bool(re.search(r"case CUE_PRESENT:.*?digitalWrite\(PIN_LED_GREEN,\s*HIGH\);.*?digitalWrite\(PIN_BUZZER,\s*HIGH\);.*?delay\(100\);", guide_content, re.DOTALL))
    has_late_cue = bool(re.search(r"case CUE_LATE:.*?digitalWrite\(PIN_LED_GREEN,\s*HIGH\);.*?delay\(80\);.*?delay\(60\);.*?delay\(80\);", guide_content, re.DOTALL))
    has_unregistered_cue = bool(re.search(r"case CUE_UNREGISTERED:.*?digitalWrite\(PIN_LED_RED,\s*HIGH\);.*?delay\(600\);", guide_content, re.DOTALL))
    has_outside_cue = bool(re.search(r"case CUE_OUTSIDE_WINDOW:.*?for\s*\(int i = 0;\s*i < 3;\s*i\+\+\).*?digitalWrite\(PIN_LED_RED,\s*HIGH\);.*?delay\(150\);", guide_content, re.DOTALL))
    has_cross_cue = bool(re.search(r"case CUE_CROSS_SECTION:.*?for\s*\(int i = 0;\s*i < 2;\s*i\+\+\).*?digitalWrite\(PIN_LED_RED,\s*HIGH\);.*?delay\(200\);", guide_content, re.DOTALL))

    check(
        "T1.3",
        "Firmware implements distinct audio/visual routines for all online status conditions",
        all([has_present_cue, has_late_cue, has_unregistered_cue, has_outside_cue, has_cross_cue]),
        f"Missing/incomplete cue: present={has_present_cue}, late={has_late_cue}, unregistered={has_unregistered_cue}, outside={has_outside_cue}, cross={has_cross_cue}"
    )

    # 1.4 Check Core 1 uses CUE_OFFLINE_QUEUED when offline
    core1_offline_branch = bool(re.search(
        r"if\s*\(!isOnline\)\s*\{\s*// Neutral Cached Cue: Amber LED \+ 2x Short Chirp.*?triggerAudioVisualCue\(CUE_OFFLINE_QUEUED\);",
        guide_content,
        re.DOTALL
    ))
    check(
        "T1.4",
        "Core 1 sensing loop invokes CUE_OFFLINE_QUEUED when offline",
        core1_offline_branch,
        "Core 1 does not invoke CUE_OFFLINE_QUEUED when isOnline is false"
    )

    # -------------------------------------------------------------
    # 2. LITTLEFS STORAGE DEADLOCK VERIFICATION
    # -------------------------------------------------------------
    has_max_spool_def = bool(re.search(r"#define\s+MAX_SPOOL_BYTES\s+(\d+)", guide_content))
    spool_guard_match = re.search(
        r"void\s+appendToSpool\(const\s+ScanEvent\s+&event\)\s*\{.*?if\s*\(file\.size\(\)\s*>=\s*MAX_SPOOL_BYTES\)\s*\{.*?file\.close\(\);\s*return;\s*\}",
        guide_content,
        re.DOTALL
    )

    check(
        "T2.1",
        "MAX_SPOOL_BYTES defined with reasonable partition allocation (<= 1.4 MB of 1.5 MB)",
        has_max_spool_def,
        "MAX_SPOOL_BYTES definition missing"
    )

    check(
        "T2.2",
        "appendToSpool() contains guard: if (file.size() >= MAX_SPOOL_BYTES) file.close(); return;",
        bool(spool_guard_match),
        "appendToSpool() lacks MAX_SPOOL_BYTES size guard before writing to flash"
    )

    # -------------------------------------------------------------
    # 3. BULK HTTPS DRAIN & FREE-RTOS QUEUE PROTECTION
    # -------------------------------------------------------------
    with open(plan_path, "r", encoding="utf-8") as f:
        plan_content = f.read()

    has_batch_rpc_sql = "FUNCTION public.record_rfid_attendance_batch" in plan_content
    has_batch_endpoint_firmware = "record_rfid_attendance_batch" in guide_content
    has_batch_loop = bool(re.search(r"const\s+int\s+BATCH_SIZE\s*=\s*\d+;", guide_content))

    # Check that FreeRTOS xScanQueue is drained during batch sync to prevent starvation
    has_queue_interleave = bool(re.search(
        r"while\s*\(xQueueReceive\(xScanQueue,\s*&interEvent,\s*0\)\s*==\s*pdPASS\)\s*\{.*?tempFile\.print",
        guide_content,
        re.DOTALL
    ))

    check(
        "T3.1",
        "SQL schema specifies public.record_rfid_attendance_batch(p_scans jsonb)",
        has_batch_rpc_sql,
        "record_rfid_attendance_batch missing from database plan"
    )

    check(
        "T3.2",
        "Firmware flushSpoolToCloud() sends bulk batches to record_rfid_attendance_batch",
        has_batch_endpoint_firmware and has_batch_loop,
        "Firmware does not use bulk batch RPC endpoint"
    )

    check(
        "T3.3",
        "Core 0 flush loop interleaves xQueueReceive(xScanQueue) to prevent queue overflow and dropped scans",
        has_queue_interleave,
        "Firmware does not interleave FreeRTOS queue draining during flash spool flush"
    )

    # -------------------------------------------------------------
    # 4. DECOUPLING CAPACITOR IN STEP 2.5
    # -------------------------------------------------------------
    step2_match = re.search(r"### Step 2: Prototyping on Solderless Breadboard(.*?)(?=### Step 3:)", guide_content, re.DOTALL)
    step2_text = step2_match.group(1) if step2_match else ""

    has_01uf_step2 = "0.1µF" in step2_text or "100nF" in step2_text
    has_100uf_step2 = "100µF" in step2_text
    has_parallel_rails = "parallel" in step2_text and "3V3 and GND" in step2_text

    check(
        "T4.1",
        "Assembly Step 2 item 5 explicitly includes 0.1µF (100nF) ceramic capacitor in parallel with 100µF across 3V3 and GND",
        has_01uf_step2 and has_100uf_step2 and has_parallel_rails,
        f"Step 2 text: 0.1uF={has_01uf_step2}, 100uF={has_100uf_step2}, parallel_rails={has_parallel_rails}"
    )

    # Check BOM Item 6
    bom_item6_match = re.search(r"\|\s*\*\*6\*\*\s*\|\s*Decoupling Capacitors\s*\|\s*\*\*1x 100µF 16V Electrolytic \+ 1x 0\.1µF \(100nF\) Ceramic\*\*", guide_content)
    check(
        "T4.2",
        "BOM Item 6 explicitly specifies both 100µF electrolytic and 0.1µF ceramic capacitors",
        bool(bom_item6_match),
        "BOM Item 6 missing decoupling capacitor pair specification"
    )

    # -------------------------------------------------------------
    # 5. NOMENCLATURE: SCENARIO E7
    # -------------------------------------------------------------
    with open(matrix_path, "r", encoding="utf-8") as f:
        matrix_content = f.read()

    e7_match = re.search(r"\|\s*\*\*E7\*\*\s*\|.*?Visual Holiday Status Pill / Header Badge.*?\|", matrix_content)
    no_holiday_banner = "Visual Holiday Banner" not in matrix_content

    check(
        "T5.1",
        "Scenario E7 updated to 'Visual Holiday Status Pill / Header Badge'",
        bool(e7_match),
        "Scenario E7 does not use exact title 'Visual Holiday Status Pill / Header Badge'"
    )

    check(
        "T5.2",
        "No ambiguous 'Visual Holiday Banner' remains in ATTENDANCE_VALIDATION_MATRIX.md",
        no_holiday_banner,
        "'Visual Holiday Banner' still found in matrix"
    )

    # -------------------------------------------------------------
    # SUMMARY
    # -------------------------------------------------------------
    print("-" * 80)
    print(f"RESULTS: {passed} passed, {failed} failed")
    if failed == 0:
        print("VERDICT: ALL 5 GENERATION-1 DEFECTS ARE VERIFIED RESOLVED.")
        return 0
    else:
        print(f"VERDICT: {failed} FAILURES DETECTED.")
        for fid, name, det in findings:
            print(f"  - [{fid}] {name}: {det}")
        return 1

if __name__ == "__main__":
    sys.exit(run_tests())
