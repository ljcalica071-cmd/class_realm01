# Attendance Feature: RFID Assignment & History Analytics Plan

This document outlines the implementation plan for the final stages of the Attendance Feature, specifically focusing on **RFID Assignment/Setup** and **Attendance History & Analytics**.

## Part 1: RFID Assignment Setup (Teacher Flow)

### 1. Database Modification (Supabase)
Currently, `student_profiles` only tracks LRN. We need to associate a unique RFID card string to each student.
- **Action:** Add `rfid_uid` column to the `student_profiles` table.
- **Constraints:** `VARCHAR`, `UNIQUE`, `NULLABLE` (so students without cards are just null).

### 2. UI/UX Flow for Assigning RFIDs
Since you requested the setup to be accessible and easy within the Attendance feature itself, we will integrate it into the existing `teacher_attendance_tab.dart`.

- **The Button:** Add a button labeled **"Assign RFID Cards"** next to the View Switcher (Take Attendance / History & Analytics).
- **The Mode (Assignment Mode):**
  1. When clicked, the roster list switches to "Assignment Mode".
  2. The teacher clicks on a specific student's name in the list (e.g., Ljay Calica).
  3. A modal pops up: *"Please tap the RFID card on the scanner for Ljay Calica..."*
  4. The existing `KeyboardListener` captures the scanned input.
  5. The system saves the `rfid_uid` to the database and links it to Ljay Calica.
  6. The modal closes, and a green RFID icon appears next to Ljay's name to indicate a card is successfully linked.
- **Why this works:** It is lightning-fast. The teacher can just click name -> tap card -> click name -> tap card, assigning 40 students in less than 2 minutes.

### 3. Taking Attendance via RFID (Schedule Guarding)
- **Schedule Check Rule:** Before taking attendance (either Manual or RFID), the system MUST check `teacher_schedule` for the selected `subject_offering_id`.
  - If the selected date **DOES NOT MATCH** any plotted schedule day (e.g., it is Tuesday, but the class is only Mon-Wed-Fri), the Attendance Workspace gets locked.
  - The UI will display a warning: *"No scheduled class for this subject on [Date]. Attendance cannot be recorded."*
  - The `KeyboardListener` will ignore all RFID scans, and the "Auto-Absent" button will be disabled to prevent false absences on rest days.
- When it is a valid scheduled day, the scanner listens globally.
- When an RFID is scanned, the system checks `rfid_uid` or `lrn` in the roster.
- If it matches, the student is marked **Present**, and a success notification pops up.

---

## Part 2: Attendance History & Analytics

The `AttendanceHistoryAnalyticsView` is currently an empty placeholder when the teacher clicks the "History & Analytics" toggle. We will build it into a comprehensive reporting tool.

### 1. Key Metrics (Overview Cards)
At the top of the analytics view, we will display Shimmer-loaded KPI cards:
- **Average Daily Attendance (ADA):** Overall percentage of present students in the selected date range.
- **Total Absences:** Count of absent marks.
- **Total Lates:** Count of late marks.

### 2. Date Range Controls
- A date picker to allow the teacher to filter analytics by:
  - This Week
  - This Month
  - Custom Date Range

### 3. Student Breakdown Table
A data table listing all students in the selected class section with their cumulative statistics:
| Student Name | Present | Absent | Late | Excused | Attendance % |
| :--- | :---: | :---: | :---: | :---: | :---: |
| Ljay Calica | 15 | 2 | 1 | 0 | 88% |
| Naruto Uzumaki | 18 | 0 | 0 | 0 | 100% |

- **Action:** Clicking on a student row will pop up a detailed mini-calendar showing exactly WHICH days they were absent or late.

### 4. DepEd Form Export (Future-proofing)
- A **"Download SF2 (CSV)"** button. School Form 2 is the official DepEd daily attendance report. Exporting this will save the teacher hours of manual writing at the end of the month.

---

## Summary of Tasks to Execute
- [ ] Execute SQL Migration to add `rfid_uid` to `student_profiles`.
- [ ] Add "Assign RFIDs" UI Mode and Modal in `teacher_attendance_tab.dart`.
- [ ] Implement backend function to update `rfid_uid`.
- [ ] Implement **Schedule Guard Logic** (Lock attendance features if the chosen date is not in the subject's schedule).
- [ ] Update `KeyboardListener` to match against both LRN and `rfid_uid`.
- [ ] Build UI for `AttendanceHistoryAnalyticsView`.
- [ ] Write aggregate queries in `SupabaseAttendanceRepository` to fetch history stats.
