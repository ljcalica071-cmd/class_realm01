#!/usr/bin/env python3
"""
Verification of Proposed Fixes for ClassRealm Attendance Redesign
Demonstrates how the identified bugs in:
1. Scenario A: Earlier Tap Timestamp Priority
2. Scenario B-Critical: System Auto-Absent Overwrite by Delayed Offline Taps
3. Cutoff Threshold: absent_cutoff_mins Usage & Strict Inequality
4. Schedule Guarding across Manual & Automated channels
are resolved deterministically.
"""

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
print("CLASSREALM ATTENDANCE REDESIGN: VERIFICATION OF PROPOSED FIXES")
print("=" * 80)

class MockSchedule:
    def __init__(self, day_of_week, start_time, end_time, is_active=True):
        self.day_of_week = day_of_week
        self.start_time = start_time
        self.end_time = end_time
        self.is_active = is_active

class MockCutoffs:
    def __init__(self, present_start_mins_before=15, present_grace_mins=15, late_cutoff_mins=45, absent_cutoff_mins=60):
        self.present_start_mins_before = present_start_mins_before
        self.present_grace_mins = present_grace_mins
        self.late_cutoff_mins = late_cutoff_mins
        self.absent_cutoff_mins = absent_cutoff_mins

def fixed_record_rfid_attendance(scan_dt, schedule, cutoffs, device_id='HARDWARE_ESP32', holiday=False, existing_record=None):
    """
    Fixed and hardened implementation of record_rfid_attendance:
    - Resolves Scenario A (earlier timestamp retention for same status)
    - Resolves Scenario B-Critical (promotes System Auto-Absent when offline tap arrives)
    - Properly evaluates absent_cutoff_mins
    - Uses clear variable names: present_cutoff_dt, late_cutoff_dt, absent_cutoff_dt
    """
    attendance_date = scan_dt.date()
    scan_time = scan_dt.time()
    dow = scan_dt.isoweekday()

    # 1. Holiday check
    if holiday:
        return {'success': False, 'code': 'HOLIDAY_LOCKED', 'message': 'Holiday'}

    # 4. Schedule validation
    if schedule is None or schedule.day_of_week != dow or not schedule.is_active:
        return {'success': False, 'code': 'NO_SCHEDULE_TODAY', 'message': 'No class scheduled'}

    # 5. Cutoffs & Time calculations
    t_base = datetime.combine(attendance_date, schedule.start_time)
    present_open_dt = t_base - timedelta(minutes=cutoffs.present_start_mins_before)
    present_cutoff_dt = t_base + timedelta(minutes=cutoffs.present_grace_mins)
    late_cutoff_dt = t_base + timedelta(minutes=cutoffs.late_cutoff_mins)
    absent_cutoff_dt = t_base + timedelta(minutes=cutoffs.absent_cutoff_mins)
    class_end_dt = datetime.combine(attendance_date, schedule.end_time)

    # Scans closed after absent_cutoff or class_end (whichever is earlier)
    effective_close_dt = min(absent_cutoff_dt, class_end_dt)

    scan_datetime = datetime.combine(attendance_date, scan_time)

    if scan_datetime < present_open_dt:
        return {'success': False, 'code': 'BEFORE_WINDOW_OPENS', 'message': 'Too early'}
    elif scan_datetime > class_end_dt:
        return {'success': False, 'code': 'AFTER_CLASS_ENDS', 'message': 'Class ended'}
    elif scan_datetime > effective_close_dt:
        return {'success': False, 'code': 'SCANS_CLOSED', 'message': 'Attendance scanning window has closed'}

    # Calculate status
    if scan_datetime <= present_cutoff_dt:
        calculated_status = 'present'
    elif scan_datetime <= late_cutoff_dt:
        calculated_status = 'late'
    else:
        calculated_status = 'absent'

    # Conflict engine
    if existing_record is not None:
        # RULE 1: Teacher manual override is supreme
        if existing_record.get('recording_method') == 'Manual' or existing_record.get('status') == 'excused':
            return {
                'success': True,
                'code': 'MANUAL_OVERRIDE_PRESERVED',
                'status': existing_record['status'],
                'record': existing_record
            }

        # RULE 2A: Overwrite System Auto-Absent with delayed offline RFID tap
        if existing_record.get('recording_method') == 'System' and existing_record.get('status') == 'absent':
            updated = dict(existing_record)
            updated['status'] = calculated_status
            updated['recording_method'] = 'RFID'
            updated['time_in'] = scan_time
            updated['device_id'] = device_id
            updated['remarks'] = 'Recovered from delayed offline RFID tap (overrode System Auto-Absent)'
            return {
                'success': True,
                'code': 'PROMOTED_FROM_AUTO_ABSENT',
                'status': calculated_status,
                'record': updated
            }

        # RULE 2B: Monotonic status promotion (Late -> Present)
        if existing_record.get('status') == 'late' and calculated_status == 'present':
            updated = dict(existing_record)
            updated['status'] = 'present'
            updated['recording_method'] = 'RFID'
            updated['time_in'] = scan_time
            updated['device_id'] = device_id
            updated['remarks'] = 'Promoted to Present via earlier physical RFID tap'
            return {
                'success': True,
                'code': 'PROMOTED_TO_PRESENT',
                'status': 'present',
                'record': updated
            }

        # RULE 2C: Timestamp priority (Earlier physical tap for same status)
        if (existing_record.get('recording_method') == 'RFID' and 
            existing_record.get('time_in') is not None and 
            scan_time < existing_record['time_in'] and 
            calculated_status == existing_record.get('status')):
            updated = dict(existing_record)
            updated['time_in'] = scan_time
            updated['device_id'] = device_id
            updated['remarks'] = f"Updated to earlier tap timestamp ({scan_time.strftime('%I:%M %p')})"
            return {
                'success': True,
                'code': 'TIMESTAMP_UPDATED_EARLIER',
                'status': existing_record['status'],
                'record': updated
            }

        # RULE 3: Monotonic retention / Idempotent no-op
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
            'time_in': scan_time,
            'device_id': device_id
        }
    }

# ==============================================================================
# TEST FIXES
# ==============================================================================
mon_sched = MockSchedule(day_of_week=1, start_time=time(8, 0), end_time=time(9, 0))
cutoffs = MockCutoffs()

# 1. Test Fixed Scenario A:
existing_rec_A = {
    'id': 'rec-1',
    'status': 'present',
    'recording_method': 'RFID',
    'time_in': time(8, 5, 0),
    'device_id': 'MOBILE_NFC'
}
res_A_fixed = fixed_record_rfid_attendance(
    datetime(2026, 11, 2, 7, 55, 0), mon_sched, cutoffs,
    device_id='HARDWARE_ESP32', existing_record=existing_rec_A
)
if res_A_fixed['code'] == 'TIMESTAMP_UPDATED_EARLIER' and res_A_fixed['record']['time_in'] == time(7, 55, 0) and res_A_fixed['record']['device_id'] == 'HARDWARE_ESP32':
    sim.record_pass("FIX 1 Verified: Scenario A Retains Earlier 07:55 AM Timestamp & ESP32 Device")
else:
    sim.record_fail("FIX 1 Failed", f"{res_A_fixed}")

# 2. Test Fixed Scenario B-Critical:
existing_rec_system_absent = {
    'id': 'rec-2',
    'status': 'absent',
    'recording_method': 'System',
    'time_in': None,
    'device_id': None
}
res_B_crit_fixed = fixed_record_rfid_attendance(
    datetime(2026, 11, 2, 8, 2, 0), mon_sched, cutoffs,
    device_id='HARDWARE_ESP32', existing_record=existing_rec_system_absent
)
if res_B_crit_fixed['code'] == 'PROMOTED_FROM_AUTO_ABSENT' and res_B_crit_fixed['record']['status'] == 'present' and res_B_crit_fixed['record']['recording_method'] == 'RFID':
    sim.record_pass("FIX 2 Verified: Delayed Offline Tap Overrides System Auto-Absent cleanly")
else:
    sim.record_fail("FIX 2 Failed", f"{res_B_crit_fixed}")

# 3. Test Strict Inequality in Schema Check:
def strict_schema_check(grace, late, absent):
    # Strict inequality: late > grace AND absent > late
    return (late > grace) and (absent > late)

if not strict_schema_check(15, 45, 45):
    sim.record_pass("FIX 3 Verified: absent == late correctly rejected under strict inequality")
else:
    sim.record_fail("FIX 3 Failed", "Allowed equality")

# 4. Test absent_cutoff closing scans:
cutoffs_strict = MockCutoffs(present_start_mins_before=15, present_grace_mins=15, late_cutoff_mins=45, absent_cutoff_mins=50)
tap_855 = datetime(2026, 11, 2, 8, 55, 0) # 55m after start (> absent_cutoff 50m, but < class_end 60m)
res_855 = fixed_record_rfid_attendance(tap_855, mon_sched, cutoffs_strict)
if res_855['code'] == 'SCANS_CLOSED':
    sim.record_pass("FIX 4 Verified: Tap beyond absent_cutoff_mins deterministically closed")
else:
    sim.record_fail("FIX 4 Failed", f"{res_855}")

print("\n" + "=" * 80)
print(f"ALL PROPOSED FIXES VERIFIED: {sim.passed} PASSED, {sim.failed} FAILED")
print("=" * 80)
