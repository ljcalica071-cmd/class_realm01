# Attendance Validation & Edge-Case Matrix
**ClassRealm — Senior High School Management Platform**  
**Document Code:** `CR-ATT-VALMAT-2026-V1`  
**Target Milestone:** Comprehensive Attendance Edge-Case & Error Audit (R7)  
**Date:** October 29, 2026  
**Status:** Approved Technical Standard  

---

## 1. Strict UI Error Presentation Standard

ClassRealm enforces an uncompromising standard for user-facing error presentation. Unfriendly technical error dumps, database constraint codes (e.g. `23505`), unformatted Dart exceptions, and floating transient notifications degrade educational focus and produce administrative confusion.

### The Zero-SnackBar & Dual-Channel UI Rule
```
+-----------------------------------------------------------------------------------------+
|                               UI ERROR PRESENTATION STANDARD                            |
+---------------------------------------------------+-------------------------------------+
| 1. INLINE INPUT VALIDATION                        | 2. CENTERED MODAL DIALOGS           |
| (For Form Fields, Thresholds & Text Inputs)       | (For Scanner, Conflict & System)    |
+---------------------------------------------------+-------------------------------------+
| - 1.5px solid red border: Color(0xFFDC2626)       | - Dialog title in Inter Bold 18px   |
| - 12px helper text directly under input field     | - Sanitized English explanation     |
| - Clears immediately when user changes value      | - Explicit user recovery action     |
| - NO floating toasts, NO bottom SnackBars         | - NO raw exception strings ($e)     |
+---------------------------------------------------+-------------------------------------+
|                                STRICTLY PROHIBITED:                                     |
|  - ScaffoldMessenger.of(context).showSnackBar()                                         |
|  - Floating toasts, top/bottom alert banners                                            |
|  - Raw PostgreSQL codes, stack traces, or technical error strings                       |
+-----------------------------------------------------------------------------------------+
```

---

## 2. Comprehensive Validation & Edge-Case Matrix

| # | Domain / Category | Trigger / Edge-Case Scenario | System Defense & Detection Logic | UI Presentation Channel | Exact User-Facing Title | Exact User-Facing Message Copy | Action Buttons & Call to Action | Status / Data Integrity Effect |
|---|---|---|---|---|---|---|---|---|
| **E1** | **RFID Assignment** | Teacher types or scans invalid UID (less than 4 hex characters or non-hex string: e.g. `12Z`, `ABC`). | Regex validation pattern: `^[0-9A-Fa-f:]{4,32}$`. Triggered upon focus loss or form submission. | **Inline Input Error** (Red border `#DC2626` directly under UID field) | *N/A (Inline)* | *"Please enter a valid RFID card UID (minimum 4 hexadecimal characters)."* | Submit button remains disabled until valid. | Database write blocked. No record created. |
| **E2** | **RFID Assignment** | Teacher taps card already assigned to another student in the school. | Database lookup finds `student_profiles.rfid_uid = scannedUid` where `student_id != currentStudentId`. | **Modal Dialog** (`AppModals.showConfirmationDialog`) | *"RFID Card Already Assigned"* | *"This card is currently linked to **[Existing Student Name]** (Grade [G] - [Section]). Do you want to transfer and assign this card to **[Target Student Name]**?"* | `[ Cancel ]` (Neutral Outline)<br>`[ Transfer & Assign ]` (Orange Accent `#D97706`) | On cancel: Abort. On confirm: Atomic RPC transfers card and clears previous link. |
| **E3** | **RFID Assignment** | Teacher replaces an existing student's linked card with a new card. | Detected when target student already has a non-null `rfid_uid` and new UID is scanned. | **Modal Dialog** (`AppModals.showConfirmationDialog`) | *"Replace Existing Card?"* | *"**[Student Name]** is already linked to Card `[Old UID]`. Are you sure you want to replace it with Card `[New UID]`?"* | `[ Keep Current Card ]`<br>`[ Replace Card ]` (`#487898`) | Previous card unlinked; new card associated. |
| **E4** | **RFID Assignment** | Mobile phone NFC sensor is turned off or disabled in system settings. | `NfcManager.instance.isAvailable()` evaluates to `false`. | **Modal Alert** (`AppModals.showErrorDialog`) | *"NFC Sensor Turned Off"* | *"NFC is currently turned off or unsupported on this device. Please turn on NFC in your phone settings to scan student cards."* | `[ Open Phone Settings ]`<br>`[ Use USB Scanner Instead ]` | Scanner session halted cleanly without crash. |
| **E5** | **RFID Assignment** | Card read failure or scanner timeout during assignment. | NFC session fails to read ISO 14443-A UID within 15 seconds. | **Modal Alert** (`AppModals.showErrorDialog`) | *"Card Read Timed Out"* | *"Could not read the card. Please hold the card flat against the back of your phone and tap Try Again."* | `[ Try Again ]`<br>`[ Cancel ]` | Session resets to scanning state. |
| **E6** | **Schedule Guard** | Scanning on non-scheduled day (e.g. Tuesday for Mon-Wed-Fri class). | Check `teacher_schedule` for `subject_offering_id` where `day_of_week = today.weekday`. Zero rows returned. | **Modal Alert** (`AppModals.showErrorDialog`) + Visual Lock Badge | *"No Class Scheduled Today"* | *"Attendance cannot be recorded. There is no scheduled class session for **[Subject Name]** on **[Day Name]**."* | `[ Dismiss ]` | Attendance workspace locked; scanner disabled. |
| **E7** | **Schedule Guard** | Scanning on recognized school holiday or academic suspension. | Check `school_holidays` table for `holiday_date = today` and `is_active = true`. | **Modal Alert** (`AppModals.showErrorDialog`) + Visual Holiday Status Pill / Header Badge | *"School Holiday"* | *"Today is **[Holiday Name]**. Regular classes and attendance recording are suspended."* | `[ Dismiss ]` | Scans blocked; 23:59 Auto-Absent suppressed. |
| **E8** | **Schedule Guard** | Student taps card before attendance window opens (>15 mins before start). | Scan time $t < T_{\text{start}} - \text{present\_start\_mins}$. | **Modal Alert** (`AppModals.showErrorDialog`) (Mobile) / Online: 3x Low Warning Beep + 3x Red Flash; Offline: Neutral Amber 2x Chirp (ESP32) | *"Attendance Not Yet Open"* | *"Too early to scan. The attendance window for **[Subject Name]** opens at **[Window Open Time]** (Class starts at [Start Time])."* | `[ Understood ]` | Tap rejected; no database record created. |
| **E9** | **Schedule Guard** | Student taps card after class session has ended or after absent cutoff. | Scan time $t > T_{\text{absent\_cutoff}}$ or $t > T_{\text{end}}$. | **Modal Alert** (`AppModals.showErrorDialog`) (Mobile) / Online: 3x Low Warning Beep + 3x Red Flash; Offline: Neutral Amber 2x Chirp (ESP32) | *"Class Session Ended"* | *"Attendance recording is closed. The class session for **[Subject Name]** ended at **[End Time]**."* | `[ Dismiss ]` | Tap rejected; student marked Absent by EOD job. |
| **E10**| **Live Attendance**| Unregistered card tapped on live classroom scanner. | Card UID not found in `student_profiles.rfid_uid`. | **Modal Dialog** (`AppModals.showConfirmationDialog`) (Mobile) / Online: Long Low Tone (600ms) + Red LED; Offline: Neutral Amber 2x Chirp (ESP32) | *"Unregistered RFID Card"* | *"Card UID `[UID]` is not registered to any student in the school system. Would you like to assign this card now?"* | `[ Ignore ]`<br>`[ Assign to Student ]` (Opens Assignment Modal) | Attendance not recorded. Prompts teacher to register card. |
| **E11**| **Live Attendance**| Student from a different section or grade taps the classroom reader. | Student UID found in `student_profiles`, but student has no active enrollment in `subject_offering_id`. | **Modal Alert** (`AppModals.showErrorDialog`) (Mobile) / Online: Double Low Buzz + Red LED; Offline: Neutral Amber 2x Chirp (ESP32) | *"Wrong Class Section"* | *"**[Student Name]** is enrolled in **[Other Section]**, not in this class. Attendance was not recorded."* | `[ Dismiss ]` | Scan rejected. Prevents cross-class pollution. |
| **E12**| **Live Attendance**| Duplicate card taps by same student within same class session. | Existing record exists in database or local state for `(student_id, offering_id, date)`. | **Silent Idempotent Ignore** (Table row pulses green; 2x rapid audio pip) | *N/A (No intrusive modal)* | *N/A (Tooltip: "Already recorded at [Time]")* | None (Seamless classroom flow) | Timestamp preserved; status NOT overwritten; no downgrade. |
| **E13**| **Live Attendance**| Rapid card chatter (student holds card on reader causing multiple reads). | Software debouncing window: ignores identical UID within 5000ms. | **Silent Ignore** | *N/A* | *N/A* | None | Hardware reader ignores rapid repeat triggers. |
| **E14**| **Offline Conflict**| Delayed offline scan arrives after teacher manually marked student. | Incoming sync record has `source = 'rfid'`, existing database record has `recording_method = 'Manual'` or `status = 'excused'`. | **Silent Server-Side Conflict Resolution** | *N/A* | *N/A (Logged to system audit trail)* | None | **Teacher Manual Override Prevents Overwrite**. Existing record retained 100% immutable. |
| **E15**| **Offline Conflict**| Delayed offline on-time scan (07:55 AM) arrives after mobile late mark (08:08 AM). | Incoming scan has earlier timestamp $t < T_{\text{late}}$ while current status is `late`. | **Silent Monotonic Promotion** + Realtime Table Pulse | *N/A* | *N/A (Realtime table row updates to Present)* | None | **Earliest Physical Tap Promotes (Late -> Present)**. Status upgraded to `present`; audit remark logged. |
| **E15b**| **Offline Conflict**| Delayed offline on-time scan (07:55 AM) arrives for student already marked Present (08:05 AM). | Incoming scan has earlier timestamp $t_{\text{scan}} < t_{\text{existing}}$ while current status is already `present`. | **Silent Timestamp Promotion** + Realtime Audit Update | *N/A* | *N/A (Audit trail: Timestamp updated)* | None | **Timestamp Priority (Fix 1)**. Retains `present`, updates `time_in = '07:55:00'`, `device_id = 'HARDWARE_ESP32'`, returns `TIMESTAMP_PROMOTED`. |
| **E16**| **Offline Conflict**| Delayed offline late scan (08:15 AM) arrives after mobile on-time mark (07:58 AM). | Incoming scan has later timestamp while current status is `present`. | **Silent Monotonic Retention** | *N/A* | *N/A* | None | **Status Monotonicity**. Downgrade rejected. Student remains `present`. |
| **E16b**| **Offline Conflict**| Delayed offline tap from yesterday arrives for student auto-marked Absent by 23:59 EOD cron. | Existing record has `status = 'absent' AND recording_method = 'System'`. | **Silent Auto-Absent Recovery** + Realtime Table Update | *N/A* | *N/A (Recovered from spool)* | None | **System Auto-Absent Promotion (Fix 2)**. Promotes record to `present` or `late` with physical timestamp; `recording_method = 'RFID'`. |
| **E17**| **Batch Save** | Wi-Fi network drops while teacher is saving attendance changes. | Network request fails or throws `SocketException`. | **Modal Alert** (`AppModals.showErrorDialog`) + Auto-Queuing | *"Saved Locally (Offline)"* | *"Unable to connect to the cloud server. Your attendance marks have been saved safely to your device and will sync automatically once reconnected."* | `[ Continue Working ]` | Changes committed to Drift SQLite; queued in `OfflineSyncQueue`. |
| **E18**| **EOD Auto-Absent** | 23:59 Cron job executes on active scheduled class day. | Stored procedure `fn_trigger_daily_auto_absent()` identifies unscanned students in enrolled offerings. | **Automated Server-Side Execution** | *N/A* | *N/A* | None | Inserts `status = 'absent'`, `recording_method = 'System'`, `remarks = 'Auto-Absent (Unscanned at EOD)'`. |
| **E19**| **EOD Auto-Absent** | 23:59 Cron runs on weekend or non-scheduled day. | Stored procedure evaluates `EXTRACT(ISODOW FROM date)`; finds no active schedules. | **Automated Server-Side Execution** | *N/A* | *N/A* | None | **Zero rows inserted**. Clean skip. |
| **E20**| **EOD Auto-Absent** | 23:59 Cron encounters student already marked Present, Late, or Excused. | `NOT EXISTS (SELECT 1 FROM attendance_records ...)` condition in stored procedure. | **Automated Server-Side Execution** | *N/A* | *N/A* | None | Existing marks **100% preserved**. Never overwritten. |

---

## 3. UI Modal Flows & Dialog Wireframes

### Flow 1: Duplicate Card Conflict Resolution (Scenario E2)
```
+-------------------------------------------------------------+
|  [!] RFID Card Already Assigned                       [ X ] |
+-------------------------------------------------------------+
|                                                             |
|  Card UID: 04:A2:3B:5C:8D:1E:80                             |
|                                                             |
|  This card is currently linked to:                          |
|  * Student: Dela Cruz, Juan P.                              |
|  * LRN:     109283746501                                    |
|  * Section: Grade 11 - STEM A                               |
|                                                             |
|  Do you want to transfer and assign this card to:           |
|  * Target:  Alcantara, Marcus D. (Grade 12 - HUMSS B)       |
|                                                             |
|  +-----------------------+     +--------------------------+ |
|  |        Cancel         |     |    Transfer & Assign     | |
|  +-----------------------+     +--------------------------+ |
+-------------------------------------------------------------+
```

### Flow 2: Unregistered Card Tapped on Reader (Scenario E10)
```
+-------------------------------------------------------------+
|  [?] Unregistered RFID Card                           [ X ] |
+-------------------------------------------------------------+
|                                                             |
|  Card UID: 04:FF:12:89:BC:44:A1                             |
|                                                             |
|  This card is not registered to any student in the school   |
|  database.                                                  |
|                                                             |
|  Would you like to assign this card to a student now?       |
|                                                             |
|  +-----------------------+     +--------------------------+ |
|  |        Ignore         |     |    Assign to Student     | |
|  +-----------------------+     +--------------------------+ |
+-------------------------------------------------------------+
```

### Flow 3: Wrong Class Section Tap (Scenario E11)
```
+-------------------------------------------------------------+
|  [X] Wrong Class Section                              [ X ] |
+-------------------------------------------------------------+
|                                                             |
|  Student Detected: Santos, Maria Clara                      |
|  LRN: 108374659201                                          |
|                                                             |
|  This student is enrolled in Grade 11 - ABM 1.              |
|  Current active class session is Grade 12 - STEM A.         |
|                                                             |
|  Attendance was NOT recorded for this class.                |
|                                                             |
|  +--------------------------------------------------------+ |
|  |                        Dismiss                         | |
|  +--------------------------------------------------------+ |
+-------------------------------------------------------------+
```

### Flow 4: Offline Local Save Alert (Scenario E17)
```
+-------------------------------------------------------------+
|  [i] Saved Locally (Offline)                          [ X ] |
+-------------------------------------------------------------+
|                                                             |
|  Unable to connect to the cloud server at this time.        |
|                                                             |
|  Your attendance marks have been saved safely to your       |
|  device's local storage.                                    |
|                                                             |
|  The system will automatically synchronize these records    |
|  with the cloud as soon as internet connectivity returns.   |
|                                                             |
|  +--------------------------------------------------------+ |
|  |                   Continue Working                     | |
|  +--------------------------------------------------------+ |
+-------------------------------------------------------------+
```

---

## 4. State Transition & Recovery Diagrams

### 4.1 Card Tap State Machine
```
                      [ Physical Card Tap ]
                                |
                                v
                   [ Debounce Check (< 5s)? ]
                     /                    \
                  (YES)                   (NO)
                   /                        \
           [ Ignore Pip ]            [ Query Profile ]
                                      /             \
                             (Not Found)          (Found)
                                 /                   \
                     [ Unregistered Modal ]    [ Enrolled in Section? ]
                     (Option to Assign)           /                 \
                                               (NO)                (YES)
                                                /                     \
                                    [ Wrong Section Modal ]   [ Schedule Active? ]
                                                               /                 \
                                                            (NO)                (YES)
                                                             /                     \
                                                [ Locked Modal ]           [ Evaluate Cutoff ]
                                                                            - Present (< Grace)
                                                                            - Late (< Cutoff)
                                                                            - Absent (> Cutoff)
                                                                                   |
                                                                                   v
                                                                       [ Apply 3-Way Conflict ]
                                                                       - Teacher override wins
                                                                       - Monotonicity enforced
                                                                       - Idempotent update
```

### 4.2 23:59 EOD Auto-Absent Execution Flow
```
                     [ Daily Trigger: 23:59 Asia/Manila ]
                                      |
                                      v
                          [ Is School Holiday? ]
                           /                  \
                        (YES)                 (NO)
                         /                      \
                 [ ABORT: Log Skip ]     [ Query Active Timetable ]
                                                |
                                                v
                                  [ Any Class Scheduled Today? ]
                                   /                          \
                                (NO)                         (YES)
                                 /                              \
                         [ ABORT: Log Skip ]         [ Find Unmarked Students ]
                                                                |
                                                                v
                                                     [ Has Existing Mark? ]
                                                      /                  \
                                                   (YES)                 (NO)
                                                    /                      \
                                             [ Preserve Mark ]     [ Insert System Absent ]
                                                                   [ Method: 'System'     ]
                                                                   [ Remark: 'Auto-Absent']
```

---

## 5. Verification Checklist for Developers

- [ ] All form text inputs validate format and display **inline 12px error text with red border (`#DC2626`)**.
- [ ] No occurrences of `ScaffoldMessenger.of(context).showSnackBar()` remain in attendance or student management views.
- [ ] Tapping an unregistered card opens the `Unregistered RFID Card` confirmation dialog with a path to assign.
- [ ] Tapping a card from another section displays the `Wrong Class Section` modal identifying the student and their section.
- [ ] Rapid multiple taps by the same student are debounced within 5 seconds and ignored without re-triggering network mutations.
- [ ] Offline scans from ESP32 or mobile app never overwrite manual teacher overrides.
- [ ] 23:59 Auto-Absent job skips weekends, non-scheduled days, and school holidays registered in `school_holidays`.
