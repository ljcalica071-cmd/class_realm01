# Adversarial Challenge & Verification Report: Schedule & Offline Sync
**Reviewer:** Teamwork Challenger (`challenger_plan_1`)  
**Target Milestone:** Attendance Feature Redesign Implementation Plan  
**Target Deliverables:**
- `PROJECT.md`
- `docs/ATTENDANCE_REDESIGN_IMPLEMENTATION_PLAN.md`
- `docs/ATTENDANCE_VALIDATION_MATRIX.md`  
**Verdict:** **REQUEST_CHANGES**

---

## 1. Observation

Direct observations and quotes from the authored specification deliverables:

### Observation 1.1: 3-Way Conflict Engine Ignores Earlier Physical Tap for Already-Present Records
In `docs/ATTENDANCE_REDESIGN_IMPLEMENTATION_PLAN.md`, lines 727–756 (`public.record_rfid_attendance`):
```sql
        -- RULE 2: STATUS MONOTONICITY & EARLIEST PHYSICAL TAP PROMOTION
        -- If currently marked Late, but an earlier on-time scan arrives, promote to Present.
        IF v_existing.status = 'late' AND v_calculated_status = 'present' THEN
            UPDATE public.attendance_records
            SET status = 'present',
                recording_method = 'RFID',
                time_in = v_scan_time,
                device_id = p_device_id,
                remarks = 'Promoted to Present via earlier physical RFID tap',
                updated_at = now()
            WHERE id = v_existing.id;

            RETURN jsonb_build_object(
                'success', true,
                'code', 'PROMOTED_TO_PRESENT',
                'status', 'present',
                'student_name', v_student_name,
                'message', 'Attendance promoted to Present based on earlier tap.'
            );
        END IF;

        -- RULE 3: IDEMPOTENT NO-OP (DO NOT OVERWRITE OR DOWNGRADE)
        RETURN jsonb_build_object(
            'success', true,
            'code', 'IDEMPOTENT_ALREADY_RECORDED',
            'status', v_existing.status,
            'student_name', v_student_name,
            'time_in', to_char(v_existing.time_in, 'HH12:MI AM'),
            'message', 'Student attendance was already recorded.'
        );
```
When `v_existing.status = 'present'` (e.g. marked at 08:05 AM via Mobile NFC or roll call), and an offline ESP32 scan arrives with an earlier timestamp (07:55 AM), line 729 evaluates to `FALSE`. Execution falls through to line 749 (`IDEMPOTENT_ALREADY_RECORDED`), leaving `v_existing.time_in` at `08:05:00` and discarding the earlier physical tap timestamp `07:55:00`.

### Observation 1.2: Delayed Offline Taps Cannot Overwrite or Promote System Auto-Absent Marks
In `docs/ATTENDANCE_REDESIGN_IMPLEMENTATION_PLAN.md`, lines 715–730:
If a classroom ESP32 device remains offline past 23:59 Asia/Manila, the daily cron `fn_trigger_daily_auto_absent()` inserts an attendance record with:
`status = 'absent'`, `recording_method = 'System'`.
When the ESP32 reconnects the next morning and drains buffered on-time scans from yesterday:
1. `IF v_existing.recording_method = 'Manual' OR v_existing.status = 'excused'` -> `FALSE` (since method is `'System'`).
2. `IF v_existing.status = 'late' AND v_calculated_status = 'present'` -> `FALSE` (since `v_existing.status` is `'absent'`).
3. Execution hits Rule 3 (`IDEMPOTENT_ALREADY_RECORDED`). The on-time taps are rejected as no-ops, and all students remain marked `absent` permanently.

### Observation 1.3: `absent_cutoff_mins` Is Unused in RPC and Threshold Naming Is Shifted
In `docs/ATTENDANCE_REDESIGN_IMPLEMENTATION_PLAN.md`:
In Table definition `attendance_cutoffs` (lines 198–205):
```sql
    present_start_mins_before integer NOT NULL DEFAULT 15 
      CHECK (present_start_mins_before >= 0 AND present_start_mins_before <= 60),
    present_grace_mins integer NOT NULL DEFAULT 15 
      CHECK (present_grace_mins >= 0 AND present_grace_mins <= 120),
    late_cutoff_mins integer NOT NULL DEFAULT 45 
      CHECK (late_cutoff_mins > present_grace_mins),
    absent_cutoff_mins integer NOT NULL DEFAULT 60 
      CHECK (absent_cutoff_mins >= late_cutoff_mins),
```
In `public.record_rfid_attendance` (lines 680–706):
```sql
    v_present_open_time := v_schedule.start_time - (COALESCE(v_cutoffs.present_start_mins_before, 15) * INTERVAL '1 minute');
    v_late_cutoff_time := v_schedule.start_time + (COALESCE(v_cutoffs.present_grace_mins, 15) * INTERVAL '1 minute');
    v_absent_cutoff_time := v_schedule.start_time + (COALESCE(v_cutoffs.late_cutoff_mins, 45) * INTERVAL '1 minute');

    -- Boundary checks
    IF v_scan_time < v_present_open_time THEN ...
    ELSIF v_scan_time > v_schedule.end_time THEN ...
    END IF;

    -- Calculate Status
    IF v_scan_time <= v_late_cutoff_time THEN
        v_calculated_status := 'present';
    ELSIF v_scan_time <= v_absent_cutoff_time THEN
        v_calculated_status := 'late';
    ELSE
        v_calculated_status := 'absent';
    END IF;
```
`v_cutoffs.absent_cutoff_mins` is never read anywhere in `record_rfid_attendance`. The variable for the Present cutoff is named `v_late_cutoff_time`, while the variable for Late cutoff is named `v_absent_cutoff_time`. Scans after `late_cutoff_mins` up to `v_schedule.end_time` are marked `absent`.

### Observation 1.4: Schema Check Allows Equality Between Absent and Late Cutoffs
In `docs/ATTENDANCE_REDESIGN_IMPLEMENTATION_PLAN.md` line 205:
```sql
    absent_cutoff_mins integer NOT NULL DEFAULT 60 
      CHECK (absent_cutoff_mins >= late_cutoff_mins)
```
The constraint uses `>=` instead of strict `>`. In contrast, Requirement R3 (lines 24 and 69 of `ORIGINAL_REQUEST.md`) states:
*"Late cutoff is strictly after Present cutoff; Absent cutoff is strictly after Late cutoff and within class hours; no inverted or overlapping thresholds."*

### Observation 1.5: Empirical Verification Test Output
Running `python .agents\teamwork\challenger_plan_1\verify_adversarial_scenarios.py` produced:
```
================================================================================
VERIFICATION SUMMARY: 12 PASSED, 5 FAILED
================================================================================
- [BUG/DEFECT] 1.4 absent_cutoff_mins Discarded: Tap at 09:15 (> absent_cutoff_mins 60) was recorded as 'absent' instead of rejected or closed. The column absent_cutoff_mins is completely ignored in record_rfid_attendance SQL!
- [BUG/DEFECT] 2.3 Schema Allows absent_cutoff == late_cutoff: Schema uses '>=' instead of strict '>' required by R3 specification!
- [BUG/DEFECT] 2.4 Default absent_cutoff_mins Exceeds Class Duration: Default absent_cutoff_mins (60m) exceeds 45m class duration! Schema has no cross-table constraint or trigger validating against teacher_schedule duration.
- [BUG/DEFECT] 3.1 Scenario A: Earlier Tap Timestamp Lost: Existing was Present at 08:05 AM. ESP32 sync at 07:55 AM was treated as IDEMPOTENT NO-OP! Record time_in remains 08:05:00 instead of promoting timestamp to 07:55:00!
- [BUG/DEFECT] 3.2b System Auto-Absent NOT Promoted by Offline Tap: CRITICAL BUG: When student was marked absent by System 23:59 cron, a delayed on-time ESP32 tap from yesterday resulted in 'IDEMPOTENT_ALREADY_RECORDED'! Status remains 'absent' because Rule 2 only promotes if status == 'late'!
```

---

## 2. Logic Chain

1. **Scenario A Timestamp Invariance Failure**:
   - The requirement in R4 / Section 7.3 states: *"Earliest Physical Tap Promotes... The earlier timestamp (07:55 AM) promotes the record to Present."*
   - In Scenario A, both taps occurred within the Present grace window (07:55 AM on door ESP32, 08:05 AM on mobile NFC roll-call).
   - Because `v_existing.status` was already `'present'`, Rule 2 in `record_rfid_attendance` was bypassed, treating the sync as a no-op under Rule 3.
   - Consequently, the record kept `time_in = 08:05:00` and `device_id = MOBILE_NFC`. The audit trail of the student's actual earlier physical arrival was permanently lost.

2. **System Auto-Absent Brick/Lockout**:
   - In any rural or classroom deployment where power or Wi-Fi drops for more than 16 hours (e.g. over an evening), the EOD cron at 23:59 marks all students Absent with `recording_method = 'System'`.
   - The ESP32 safely buffered the scans in LittleFS (holding >6,800 records).
   - However, upon reconnection the following day, `record_rfid_attendance` evaluated `v_existing.status = 'absent'`. Because `v_existing.status != 'late'`, Rule 2 did not trigger, and the stored procedure returned `IDEMPOTENT_ALREADY_RECORDED`.
   - As an empirical result, offline resilience failed completely across day boundaries.

3. **Cutoff Model Discrepancy**:
   - The architectural design in Section 6.2 models four sequential timestamps:
     $$T_{\text{open}} \le T_{\text{start}} < T_{\text{present\_cutoff}} < T_{\text{late\_cutoff}} \le T_{\text{absent\_cutoff}} \le T_{\text{end}}$$
   - However, in `record_rfid_attendance`, `v_cutoffs.absent_cutoff_mins` was omitted entirely.
   - The variable names in SQL were offset: `v_late_cutoff_time` represented the end of Present, and `v_absent_cutoff_time` represented the end of Late.
   - Furthermore, the table schema used `CHECK (absent_cutoff_mins >= late_cutoff_mins)`, permitting identical values where late and absent thresholds collapse into a single point in time.

4. **Class Duration Boundary**:
   - A standard DepEd class period may be 40 to 50 minutes.
   - The default value for `absent_cutoff_mins` is 60 minutes.
   - If a class is 45 minutes (e.g. 08:00 AM to 08:45 AM), the default cutoff is outside the class session. While `v_scan_time > v_schedule.end_time` terminates scans at 08:45 AM, the cutoff model in the database is inconsistent with the schedule duration unless guarded by cross-validation.

---

## 3. Caveats

1. **Hardware FreeRTOS Debounce**:
   - On the physical ESP32 scanner, software debouncing within 5,000ms (`DEBOUNCE_WINDOW_MS = 5000`) successfully prevents rapid multi-reads at the sensor level, as verified in `docs/ESP32_RFID_BUILD_GUIDE.md`.
2. **23:59 Cron Stored Procedure**:
   - The cron logic in `fn_trigger_daily_auto_absent()` was verified to be robust: it cleanly skips holidays, skips non-scheduled days, preserves existing marks, and is completely idempotent across duplicate executions.
3. **Schedule Guarding**:
   - Boundary checks for `BEFORE_WINDOW_OPENS` (e.g. 07:44:59 AM) and `AFTER_CLASS_ENDS` (e.g. 09:00:01 AM) are deterministic and operate as intended.

---

## 4. Conclusion & Required Changes

The architectural plan is thorough and well-structured, but contains critical logical flaws in the conflict resolution engine and cutoff constraint modeling.

### Required Changes:

1. **Fix `record_rfid_attendance` Conflict Engine (Rule 2)**:
   Update the stored procedure to:
   - Promote records where `recording_method = 'System' AND status = 'absent'` to `v_calculated_status` upon receiving delayed offline RFID taps.
   - Update `time_in` and `device_id` if an incoming scan has the same status but an earlier `scan_time < existing.time_in`.

   ```sql
   -- RULE 2A: OVERWRITE SYSTEM AUTO-ABSENT WITH DELAYED OFFLINE RFID TAP
   IF v_existing.recording_method = 'System' AND v_existing.status = 'absent' THEN
       UPDATE public.attendance_records
       SET status = v_calculated_status,
           recording_method = 'RFID',
           time_in = v_scan_time,
           device_id = p_device_id,
           remarks = 'Recovered from delayed offline RFID tap (overrode System Auto-Absent)',
           updated_at = now()
       WHERE id = v_existing.id;
       RETURN jsonb_build_object('success', true, 'code', 'PROMOTED_FROM_AUTO_ABSENT', 'status', v_calculated_status);
   END IF;

   -- RULE 2B: STATUS MONOTONICITY (LATE -> PRESENT)
   IF v_existing.status = 'late' AND v_calculated_status = 'present' THEN
       UPDATE public.attendance_records
       SET status = 'present',
           recording_method = 'RFID',
           time_in = v_scan_time,
           device_id = p_device_id,
           remarks = 'Promoted to Present via earlier physical RFID tap',
           updated_at = now()
       WHERE id = v_existing.id;
       RETURN jsonb_build_object('success', true, 'code', 'PROMOTED_TO_PRESENT', 'status', 'present');
   END IF;

   -- RULE 2C: TIMESTAMP PRIORITY FOR MATCHING STATUS
   IF v_existing.recording_method = 'RFID' 
      AND v_existing.time_in IS NOT NULL 
      AND v_scan_time < v_existing.time_in 
      AND v_calculated_status = v_existing.status THEN
       UPDATE public.attendance_records
       SET time_in = v_scan_time,
           device_id = p_device_id,
           remarks = 'Updated to earlier physical tap timestamp',
           updated_at = now()
       WHERE id = v_existing.id;
       RETURN jsonb_build_object('success', true, 'code', 'TIMESTAMP_UPDATED_EARLIER', 'status', v_existing.status);
   END IF;
   ```

2. **Fix Cutoff Variable Names & Enforce `absent_cutoff_mins`**:
   In `record_rfid_attendance`:
   - Rename `v_late_cutoff_time` to `v_present_cutoff_time` ($T_{\text{start}} + \text{present\_grace\_mins}$).
   - Rename `v_absent_cutoff_time` to `v_late_cutoff_time` ($T_{\text{start}} + \text{late\_cutoff\_mins}$).
   - Define `v_absent_cutoff_time` as $T_{\text{start}} + \text{absent\_cutoff\_mins}$.
   - Add boundary check: Scans occurring after `v_absent_cutoff_time` should return `SCANS_CLOSED`.

3. **Enforce Strict Chronological Inequality in Schema**:
   In `008_attendance_overhaul.sql` line 205:
   Change `CHECK (absent_cutoff_mins >= late_cutoff_mins)` to:
   ```sql
   CHECK (absent_cutoff_mins > late_cutoff_mins)
   ```

4. **Add Cross-Table Class Duration Validation**:
   In `008_attendance_overhaul.sql`, add a PostgreSQL validation trigger or function ensuring that when cutoffs are saved for a `schedule_id`, `absent_cutoff_mins` does not exceed `(end_time - start_time)`.

---

## 5. Verification Method

To independently reproduce the findings and verify the proposed fixes:

1. **Reproduce Failure Modes**:
   Execute the empirical test script in PowerShell:
   ```powershell
   python .agents\teamwork\challenger_plan_1\verify_adversarial_scenarios.py
   ```
   *Expected outcome*: 12 tests pass, 5 tests fail (Scenarios A, System Auto-Absent lockout, `absent_cutoff_mins` discarded, relaxed `>=` schema constraint, and class duration overflow).

2. **Verify Proposed Fixes**:
   Execute the verification suite for proposed fixes:
   ```powershell
   python .agents\teamwork\challenger_plan_1\verify_adversarial_fixes.py
   ```
   *Expected outcome*: 4 out of 4 tests pass with zero failures.
