#!/usr/bin/env python3
"""
Adversarial Verification Suite for ClassRealm Attendance Redesign
Target Deliverables:
- PROJECT.md
- docs/ATTENDANCE_REDESIGN_IMPLEMENTATION_PLAN.md
- docs/ATTENDANCE_VALIDATION_MATRIX.md
"""

import sys
from datetime import datetime, time, date, timedelta

class SimulationResult:
    def __init__(self):
        self.passed = 0
        self.failed = 0
        self.findings = []

    def record_pass(self, name, detail=""):
        self.passed += 1
        print(f"  [PASS] {name}" + (f": {detail}" if detail else ""))

    def record_fail(self, name, detail):
        self.failed += 1
        self.findings.append((name, detail))
        print(f"  [FAIL] {name}: {detail}")

sim = SimulationResult()

print("=" * 80)
print("CLASSREALM ATTENDANCE REDESIGN: ADVERSARIAL STRESS TEST SUITE")
print("=" * 80)

# ==============================================================================
# 1. SCHEDULE GUARDING & TIME BOUNDARIES
# ==============================================================================
print("\n--- TEST SUITE 1: SCHEDULE GUARDING & TIME BOUNDARIES ---")

class MockSchedule:
    def __init__(self, day_of_week, start_time, end_time, is_active=True):
        self.day_of_week = day_of_week # 1=Mon, ..., 7=Sun
        self.start_time = start_time
        self.end_time = end_time
        self.is_active = is_active

class MockCutoffs:
    def __init__(self, present_start_mins_before=15, present_grace_mins=15, late_cutoff_mins=45, absent_cutoff_mins=60):
        self.present_start_mins_before = present_start_mins_before
        self.present_grace_mins = present_grace_mins
        self.late_cutoff_mins = late_cutoff_mins
        self.absent_cutoff_mins = absent_cutoff_mins

def simulate_record_rfid_attendance(scan_dt, schedule, cutoffs, holiday=False, existing_record=None):
    """
    Exact simulation of PostgreSQL RPC record_rfid_attendance (lines 588-793 of plan)
    """
    attendance_date = scan_dt.date()
    scan_time = scan_dt.time()
    dow = scan_dt.isoweekday() # 1=Mon .. 7=Sun

    # 1. Holiday check
    if holiday:
        return {'success': False, 'code': 'HOLIDAY_LOCKED', 'message': 'Holiday'}

    # 4. Validate plotted schedule
    if schedule is None or schedule.day_of_week != dow or not schedule.is_active:
        return {'success': False, 'code': 'NO_SCHEDULE_TODAY', 'message': 'No class scheduled'}

    # 5. Cutoff configuration
    # Authored code in implementation plan:
    # v_present_open_time := v_schedule.start_time - (COALESCE(v_cutoffs.present_start_mins_before, 15) * INTERVAL '1 minute');
    # v_late_cutoff_time := v_schedule.start_time + (COALESCE(v_cutoffs.present_grace_mins, 15) * INTERVAL '1 minute');
    # v_absent_cutoff_time := v_schedule.start_time + (COALESCE(v_cutoffs.late_cutoff_mins, 45) * INTERVAL '1 minute');
    
    t_base = datetime.combine(attendance_date, schedule.start_time)
    present_open_dt = t_base - timedelta(minutes=cutoffs.present_start_mins_before)
    late_cutoff_dt = t_base + timedelta(minutes=cutoffs.present_grace_mins) # in authored SQL: present_grace_mins
    absent_cutoff_dt = t_base + timedelta(minutes=cutoffs.late_cutoff_mins) # in authored SQL: late_cutoff_mins
    class_end_dt = datetime.combine(attendance_date, schedule.end_time)

    scan_datetime = datetime.combine(attendance_date, scan_time)

    # Boundary checks
    if scan_datetime < present_open_dt:
        return {'success': False, 'code': 'BEFORE_WINDOW_OPENS', 'message': 'Too early'}
    elif scan_datetime > class_end_dt:
        return {'success': False, 'code': 'AFTER_CLASS_ENDS', 'message': 'Class ended'}

    # Calculate status in authored SQL:
    if scan_datetime <= late_cutoff_dt:
        calculated_status = 'present'
    elif scan_datetime <= absent_cutoff_dt:
        calculated_status = 'late'
    else:
        calculated_status = 'absent'

    # Existing record check
    if existing_record is not None:
        if existing_record.get('recording_method') == 'Manual' or existing_record.get('status') == 'excused':
            return {
                'success': True,
                'code': 'MANUAL_OVERRIDE_PRESERVED',
                'status': existing_record['status'],
                'record': existing_record
            }
        
        if existing_record.get('status') == 'late' and calculated_status == 'present':
            updated = dict(existing_record)
            updated['status'] = 'present'
            updated['time_in'] = scan_time
            updated['recording_method'] = 'RFID'
            updated['remarks'] = 'Promoted to Present via earlier physical RFID tap'
            return {
                'success': True,
                'code': 'PROMOTED_TO_PRESENT',
                'status': 'present',
                'record': updated
            }

        return {
            'success': True,
            'code': 'IDEMPOTENT_ALREADY_RECORDED',
            'status': existing_record['status'],
            'time_in': existing_record.get('time_in'),
            'record': existing_record
        }

    return {
        'success': True,
        'code': 'RECORDED_SUCCESS',
        'status': calculated_status,
        'time_in': scan_time,
        'record': {
            'status': calculated_status,
            'recording_method': 'RFID',
            'time_in': scan_time
        }
    }

# Test 1.1: Teacher opens attendance on Sunday / Tap on Sunday
sunday_dt = datetime(2026, 11, 1, 8, 0, 0) # 2026-11-01 is Sunday (DOW=7)
mon_sched = MockSchedule(day_of_week=1, start_time=time(8, 0), end_time=time(9, 0)) # Mon only
cutoffs = MockCutoffs()
res_sunday = simulate_record_rfid_attendance(sunday_dt, mon_sched, cutoffs)

if res_sunday['code'] == 'NO_SCHEDULE_TODAY':
    sim.record_pass("1.1 Sunday Tap Rejected by RPC", "Returns NO_SCHEDULE_TODAY")
else:
    sim.record_fail("1.1 Sunday Tap", f"Expected NO_SCHEDULE_TODAY, got {res_sunday['code']}")

# Test 1.2: Class starts at 08:00 AM, window opens at 07:45 AM. Tap at 07:44:59 AM
tap_74459 = datetime(2026, 11, 2, 7, 44, 59) # Monday
tap_74500 = datetime(2026, 11, 2, 7, 45, 0)
res_74459 = simulate_record_rfid_attendance(tap_74459, mon_sched, cutoffs)
res_74500 = simulate_record_rfid_attendance(tap_74500, mon_sched, cutoffs)

if res_74459['code'] == 'BEFORE_WINDOW_OPENS':
    sim.record_pass("1.2a Tap at 07:44:59 Rejected", "Deterministically rejected as BEFORE_WINDOW_OPENS")
else:
    sim.record_fail("1.2a Tap at 07:44:59", f"Expected BEFORE_WINDOW_OPENS, got {res_74459['code']}")

if res_74500['code'] == 'RECORDED_SUCCESS' and res_74500['status'] == 'present':
    sim.record_pass("1.2b Tap at 07:45:00 Accepted as Present", "On-time open boundary accepted")
else:
    sim.record_fail("1.2b Tap at 07:45:00", f"Expected RECORDED_SUCCESS present, got {res_74500}")

# Test 1.3: Tap after class ends (09:00:01 AM)
tap_90001 = datetime(2026, 11, 2, 9, 0, 1)
res_90001 = simulate_record_rfid_attendance(tap_90001, mon_sched, cutoffs)
if res_90001['code'] == 'AFTER_CLASS_ENDS':
    sim.record_pass("1.3 Tap after class end rejected", "Deterministically rejected as AFTER_CLASS_ENDS")
else:
    sim.record_fail("1.3 Tap after class end", f"Expected AFTER_CLASS_ENDS, got {res_90001['code']}")

# Test 1.4: Cutoff naming / absent_cutoff_mins evaluation
# If class is 08:00 to 09:30 (90 min), cutoffs: grace=15, late=45, absent=60
extended_sched = MockSchedule(day_of_week=1, start_time=time(8, 0), end_time=time(9, 30))
cutoffs_custom = MockCutoffs(present_start_mins_before=15, present_grace_mins=15, late_cutoff_mins=45, absent_cutoff_mins=60)
tap_850 = datetime(2026, 11, 2, 8, 50, 0) # 50 mins after start (between late_cutoff 45 and absent_cutoff 60)
res_850 = simulate_record_rfid_attendance(tap_850, extended_sched, cutoffs_custom)

# In the authored SQL: absent_cutoff_mins is never used!
# At 08:50, scan_time > late_cutoff_mins (45 mins). So calculated_status = 'absent'!
# But wait, if absent_cutoff_mins = 60, what should a tap at 50 mins be?
# Under standard DepEd / school attendance rules, if late window is up to 45 mins,
# is 45-60 mins Late or Absent? In the plan:
# line 1067: T_start < T_present_cutoff < T_late_cutoff <= T_absent_cutoff <= T_end
# If T_late_cutoff is 45 mins, taps from 16 to 45 mins are Late.
# Taps from 46 to 60 mins are Absent.
# Taps from 61 to 90 mins: what happens in authored SQL?
# In authored SQL, taps from 61 to 90 mins ALSO get marked 'absent', because class_end is 09:30!
# Why does absent_cutoff_mins exist if it is not used to close taps or distinguish anything?
tap_915 = datetime(2026, 11, 2, 9, 15, 0) # 75 mins after start (> absent_cutoff 60, but < class_end 90)
res_915 = simulate_record_rfid_attendance(tap_915, extended_sched, cutoffs_custom)
if res_915['status'] == 'absent':
    sim.record_fail("1.4 absent_cutoff_mins Discarded", 
                    "Tap at 09:15 (> absent_cutoff_mins 60) was recorded as 'absent' instead of rejected or closed. "
                    "The column absent_cutoff_mins is completely ignored in record_rfid_attendance SQL!")
else:
    sim.record_pass("1.4 absent_cutoff_mins Enforced")


# ==============================================================================
# 2. CUTOFF THRESHOLDS & CHRONOLOGICAL INVARIANTS
# ==============================================================================
print("\n--- TEST SUITE 2: CUTOFF THRESHOLDS & CHRONOLOGICAL INVARIANTS ---")

def validate_schema_cutoffs(grace, late, absent):
    """Check SQL table constraints:
       CHECK (late_cutoff_mins > present_grace_mins)
       CHECK (absent_cutoff_mins >= late_cutoff_mins)
    """
    if not (late > grace):
        return False, "late_cutoff_mins must be > present_grace_mins"
    if not (absent >= late):
        return False, "absent_cutoff_mins must be >= late_cutoff_mins"
    return True, "Valid"

# Test 2.1: Inverted thresholds (Late before Grace)
valid, msg = validate_schema_cutoffs(grace=30, late=15, absent=45)
if not valid:
    sim.record_pass("2.1 Inverted Late < Grace Blocked by Schema", msg)
else:
    sim.record_fail("2.1 Inverted Late < Grace", "Allowed inverted cutoffs!")

# Test 2.2: Inverted Absent < Late
valid, msg = validate_schema_cutoffs(grace=15, late=45, absent=30)
if not valid:
    sim.record_pass("2.2 Inverted Absent < Late Blocked by Schema", msg)
else:
    sim.record_fail("2.2 Inverted Absent < Late", "Allowed inverted cutoffs!")

# Test 2.3: Boundary case absent_cutoff == late_cutoff
valid, msg = validate_schema_cutoffs(grace=15, late=45, absent=45)
# In schema line 205: CHECK (absent_cutoff_mins >= late_cutoff_mins)
# Notice it allows equality!
if valid:
    # Does R3 allow absent_cutoff == late_cutoff?
    # R3: "Late cutoff is strictly after Present cutoff; Absent cutoff is strictly after Late cutoff"
    # Strict inequality required!
    sim.record_fail("2.3 Schema Allows absent_cutoff == late_cutoff",
                    "Schema uses '>=' instead of strict '>' required by R3 specification!")
else:
    sim.record_pass("2.3 Schema Strictly Enforces absent > late")

# Test 2.4: Cutoff exceeds class duration
def validate_duration_constraint(duration_mins, absent_cutoff_mins):
    # Does schema check duration?
    # In 008_attendance_overhaul.sql: NO duration check exists in attendance_cutoffs!
    # UI validation claims to check it, but database schema does not.
    return absent_cutoff_mins <= duration_mins

class_duration_mins = 45 # 08:00 to 08:45
cutoff_mins = 60 # Default is 60!
if not validate_duration_constraint(class_duration_mins, cutoff_mins):
    sim.record_fail("2.4 Default absent_cutoff_mins Exceeds Class Duration",
                    f"Default absent_cutoff_mins ({cutoff_mins}m) exceeds 45m class duration! "
                    "Schema has no cross-table constraint or trigger validating against teacher_schedule duration.")
else:
    sim.record_pass("2.4 Cutoff within duration")


# ==============================================================================
# 3. 3-WAY CONFLICT RESOLUTION ENGINE
# ==============================================================================
print("\n--- TEST SUITE 3: 3-WAY CONFLICT RESOLUTION ENGINE ---")

# Scenario A:
# Student tapped ESP32 at 07:55 AM (offline).
# Mobile app marks student Present at 08:05 AM (time_in = 08:05:00).
# ESP32 syncs at 09:00 AM with timestamp 07:55 AM.
# Does timestamp priority correctly retain 07:55 AM?
existing_rec_A = {
    'id': 'rec-1',
    'status': 'present',
    'recording_method': 'RFID', # via mobile NFC
    'time_in': time(8, 5, 0),
    'device_id': 'MOBILE_NFC'
}
tap_755_sync = datetime(2026, 11, 2, 7, 55, 0)
res_A = simulate_record_rfid_attendance(tap_755_sync, mon_sched, cutoffs, existing_record=existing_rec_A)

# Let's inspect what happens to time_in in res_A:
final_time_in_A = res_A['record'].get('time_in')
if final_time_in_A == time(7, 55, 0):
    sim.record_pass("3.1 Scenario A: Timestamp 07:55 AM Retained")
else:
    sim.record_fail("3.1 Scenario A: Earlier Tap Timestamp Lost",
                    f"Existing was Present at 08:05 AM. ESP32 sync at 07:55 AM was treated as IDEMPOTENT NO-OP! "
                    f"Record time_in remains {final_time_in_A} instead of promoting timestamp to 07:55:00!")

# Scenario B:
# Teacher manually marks student Absent at 08:15 AM.
# Offline ESP32 scan from 08:02 AM arrives at 08:30 AM.
# Does Manual override strictly take precedence, or is there a race condition?
existing_rec_B = {
    'id': 'rec-2',
    'status': 'absent',
    'recording_method': 'Manual',
    'time_in': None,
    'device_id': None
}
tap_802_sync = datetime(2026, 11, 2, 8, 2, 0)
res_B = simulate_record_rfid_attendance(tap_802_sync, mon_sched, cutoffs, existing_record=existing_rec_B)

if res_B['code'] == 'MANUAL_OVERRIDE_PRESERVED' and res_B['status'] == 'absent':
    sim.record_pass("3.2 Scenario B: Manual Override Takes Precedence", "Manual Absent mark preserved against delayed RFID tap")
else:
    sim.record_fail("3.2 Scenario B: Manual Override Overwritten", f"Expected MANUAL_OVERRIDE_PRESERVED, got {res_B}")

# Scenario B-Critical:
# 23:59 EOD Cron marked student Absent (recording_method = 'System').
# Next morning, offline ESP32 syncs on-time tap from 08:02 AM yesterday.
# What does record_rfid_attendance do?
existing_rec_system_absent = {
    'id': 'rec-3',
    'status': 'absent',
    'recording_method': 'System', # Set by 23:59 cron!
    'time_in': None,
    'device_id': None
}
res_sys_absent = simulate_record_rfid_attendance(tap_802_sync, mon_sched, cutoffs, existing_record=existing_rec_system_absent)
if res_sys_absent['record']['status'] == 'present':
    sim.record_pass("3.2b System Auto-Absent Promoted by Delayed Tap")
else:
    sim.record_fail("3.2b System Auto-Absent NOT Promoted by Offline Tap",
                    f"CRITICAL BUG: When student was marked absent by System 23:59 cron, "
                    f"a delayed on-time ESP32 tap from yesterday resulted in '{res_sys_absent['code']}'! "
                    f"Status remains '{res_sys_absent['record']['status']}' because Rule 2 only promotes if status == 'late'!")

# Scenario C:
# Duplicate taps within 5 seconds by the same student in the same class session.
# Does it preserve the original timestamp and status without downgrading?
existing_rec_C = {
    'id': 'rec-4',
    'status': 'present',
    'recording_method': 'RFID',
    'time_in': time(8, 0, 0),
    'device_id': 'HARDWARE_ESP32'
}
tap_80004 = datetime(2026, 11, 2, 8, 0, 4) # 4 seconds later
res_C = simulate_record_rfid_attendance(tap_80004, mon_sched, cutoffs, existing_record=existing_rec_C)

if res_C['code'] == 'IDEMPOTENT_ALREADY_RECORDED' and res_C['record']['status'] == 'present' and res_C['record']['time_in'] == time(8, 0, 0):
    sim.record_pass("3.3 Scenario C: Duplicate Tap Preserves Status & Timestamp", "Idempotent, no downgrade")
else:
    sim.record_fail("3.3 Scenario C: Duplicate Tap Downgraded/Overwritten", f"Result: {res_C}")


# ==============================================================================
# 4. 23:59 AUTO-ABSENT CRON
# ==============================================================================
print("\n--- TEST SUITE 4: 23:59 AUTO-ABSENT CRON ENGINE ---")

def simulate_fn_trigger_daily_auto_absent(target_date, schedules, enrollments, existing_records, holidays):
    """
    Exact simulation of fn_trigger_daily_auto_absent (lines 801-889 of plan)
    """
    # 1. Holiday check
    if target_date in holidays:
        return {'status': 'skipped', 'reason': 'School holiday', 'inserted': 0}

    dow = target_date.isoweekday()

    # 2. Scheduled offerings for today
    scheduled_offerings = {
        s.subject_offering_id for s in schedules
        if s.day_of_week == dow and s.is_active
    }

    if not scheduled_offerings:
        return {'status': 'success', 'date': target_date, 'day_of_week': dow, 'inserted_absences': 0}

    # 3. Unmarked students
    inserted_count = 0
    new_records = list(existing_records)

    for enr in enrollments:
        if enr['status'] != 'enrolled':
            continue
        if enr['subject_offering_id'] not in scheduled_offerings:
            continue
        
        # Check if attendance record exists
        has_record = any(
            r['student_id'] == enr['student_id'] and
            r['subject_offering_id'] == enr['subject_offering_id'] and
            r['attendance_date'] == target_date
            for r in new_records
        )

        if not has_record:
            new_records.append({
                'student_id': enr['student_id'],
                'subject_offering_id': enr['subject_offering_id'],
                'attendance_date': target_date,
                'status': 'absent',
                'recording_method': 'System',
                'remarks': 'Auto-Absent (Unscanned at EOD)'
            })
            inserted_count += 1

    return {
        'status': 'success',
        'date': target_date,
        'day_of_week': dow,
        'inserted_absences': inserted_count,
        'records': new_records
    }

class MockOfferingSchedule:
    def __init__(self, subject_offering_id, day_of_week, is_active=True):
        self.subject_offering_id = subject_offering_id
        self.day_of_week = day_of_week
        self.is_active = is_active

# Setup test fixtures
schedules_list = [
    MockOfferingSchedule('offering-1', 1), # Mon
    MockOfferingSchedule('offering-1', 3), # Wed
    MockOfferingSchedule('offering-1', 5), # Fri
]
enrollments_list = [
    {'student_id': 'student-1', 'subject_offering_id': 'offering-1', 'status': 'enrolled'},
    {'student_id': 'student-2', 'subject_offering_id': 'offering-1', 'status': 'enrolled'},
    {'student_id': 'student-3', 'subject_offering_id': 'offering-1', 'status': 'enrolled'},
]
holidays_list = {date(2026, 11, 2)} # Mon Nov 2 is holiday

# Test 4.1: Skips holidays
res_cron_holiday = simulate_fn_trigger_daily_auto_absent(
    target_date=date(2026, 11, 2),
    schedules=schedules_list,
    enrollments=enrollments_list,
    existing_records=[],
    holidays=holidays_list
)
if res_cron_holiday['status'] == 'skipped' and res_cron_holiday['inserted'] == 0:
    sim.record_pass("4.1 Cron Skips School Holidays", "Clean skip, 0 inserted")
else:
    sim.record_fail("4.1 Cron Holiday Skip", f"Expected skipped, got {res_cron_holiday}")

# Test 4.2: Skips non-scheduled days (Sunday Nov 1)
res_cron_sunday = simulate_fn_trigger_daily_auto_absent(
    target_date=date(2026, 11, 1),
    schedules=schedules_list,
    enrollments=enrollments_list,
    existing_records=[],
    holidays=set()
)
if res_cron_sunday['inserted_absences'] == 0:
    sim.record_pass("4.2 Cron Skips Non-Scheduled Days", "0 absences inserted on Sunday")
else:
    sim.record_fail("4.2 Cron Non-Scheduled Day", f"Inserted {res_cron_sunday['inserted_absences']} absences on Sunday!")

# Test 4.3: Preserves existing Present, Late, Excused marks
target_wed = date(2026, 11, 4) # Wed
existing_wed = [
    {'student_id': 'student-1', 'subject_offering_id': 'offering-1', 'attendance_date': target_wed, 'status': 'present'},
    {'student_id': 'student-2', 'subject_offering_id': 'offering-1', 'attendance_date': target_wed, 'status': 'late'},
]
res_cron_wed = simulate_fn_trigger_daily_auto_absent(
    target_date=target_wed,
    schedules=schedules_list,
    enrollments=enrollments_list,
    existing_records=existing_wed,
    holidays=set()
)
# student-1 and student-2 should be preserved. student-3 should be marked absent.
preserves_existing = True
for r in res_cron_wed['records']:
    if r['student_id'] == 'student-1' and r['status'] != 'present':
        preserves_existing = False
    if r['student_id'] == 'student-2' and r['status'] != 'late':
        preserves_existing = False

student_3_absent = any(r['student_id'] == 'student-3' and r['status'] == 'absent' for r in res_cron_wed['records'])

if preserves_existing and student_3_absent and res_cron_wed['inserted_absences'] == 1:
    sim.record_pass("4.3 Cron Preserves Existing Marks & Marks Only Unscanned", "student-1 (Present) and student-2 (Late) kept, student-3 marked Absent")
else:
    sim.record_fail("4.3 Cron Preserve Marks", f"Failed: preserves={preserves_existing}, s3_absent={student_3_absent}")

# Test 4.4: Idempotency if triggered twice
res_cron_wed_2nd = simulate_fn_trigger_daily_auto_absent(
    target_date=target_wed,
    schedules=schedules_list,
    enrollments=enrollments_list,
    existing_records=res_cron_wed['records'],
    holidays=set()
)
if res_cron_wed_2nd['inserted_absences'] == 0 and len(res_cron_wed_2nd['records']) == len(res_cron_wed['records']):
    sim.record_pass("4.4 Cron Idempotent on Duplicate Execution", "Second execution inserted 0 records, state identical")
else:
    sim.record_fail("4.4 Cron Idempotency", f"Duplicate run inserted {res_cron_wed_2nd['inserted_absences']} rows!")

print("\n" + "=" * 80)
print(f"VERIFICATION SUMMARY: {sim.passed} PASSED, {sim.failed} FAILED")
print("=" * 80)
for name, detail in sim.findings:
    print(f"- [BUG/DEFECT] {name}\n  Details: {detail}\n")
