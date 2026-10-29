# Attendance Feature Redesign & Implementation Architecture Plan
**ClassRealm — Senior High School Management Platform**  
**Document Code:** `CR-ATT-PLAN-2026-V1`  
**Target Milestone:** Comprehensive Attendance Feature Overhaul (R1–R7)  
**Date:** October 29, 2026  
**Status:** Approved Architectural Specification  

---

## Table of Contents
1. [Executive Summary & Architectural Invariants](#1-executive-summary--architectural-invariants)
2. [End-to-End System Architecture](#2-end-to-end-system-architecture)
3. [Database & Data Model Specifications](#3-database--data-model-specifications)
   - 3.1 [Supabase PostgreSQL Schema Migration (008_attendance_overhaul.sql)](#31-supabase-postgresql-schema-migration-008_attendance_overhauld)
   - 3.2 [Local SQLite Persistence (Drift Tables)](#32-local-sqlite-persistence-drift-tables)
   - 3.3 [Dart Domain Entities & Value Objects](#33-dart-domain-entities--value-objects)
4. [API Contracts, Stored Procedures & Edge Functions](#4-api-contracts-stored-procedures--edge-functions)
   - 4.1 [Atomic Postgres RPC: `record_rfid_attendance`](#41-atomic-postgres-rpc-record_rfid_attendance)
   - 4.2 [EOD 23:59 Auto-Absent Engine (`fn_trigger_daily_auto_absent`)](#42-eod-2359-auto-absent-engine-fn_trigger_daily_auto_absent)
   - 4.3 [Supabase Edge Function: `daily-auto-absent`](#43-supabase-edge-function-daily-auto-absent)
   - 4.4 [Flutter Repository Contract (`SupabaseAttendanceRepository`)](#44-flutter-repository-contract-supabaseattendancerepository)
5. [Teacher RFID Card Assignment Engine (R2)](#5-teacher-rfid-card-assignment-engine-r2)
   - 5.1 [Card Assignment Workflow & UX](#51-card-assignment-workflow--ux)
   - 5.2 [Dual-Input Assignment Modal Specification](#52-dual-input-assignment-modal-specification)
   - 5.3 [Conflict Guarding & Reassignment Protocol](#53-conflict-guarding--reassignment-protocol)
   - 5.4 [Audit Trail & Recording Method Indicator](#54-audit-trail--recording-method-indicator)
6. [Schedule-Connected Auto-Status & Cutoff Validation (R3)](#6-schedule-connected-auto-status--cutoff-validation-r3)
   - 6.1 [Schedule Guarding Logic](#61-schedule-guarding-logic)
   - 6.2 [Mathematical Cutoff Invariant & Validation Rules](#62-mathematical-cutoff-invariant--validation-rules)
   - 6.3 [Automated 23:59 Asia/Manila Auto-Absent Rules](#63-automated-2359-asiamanila-auto-absent-rules)
7. [Dual-Path Offline Attendance Pipeline (R4)](#7-dual-path-offline-attendance-pipeline-r4)
   - 7.1 [Standalone ESP32 Hardware Reader](#71-standalone-esp32-hardware-reader)
   - 7.2 [Mobile Phone NFC Fallback (`nfc_manager`)](#72-mobile-phone-nfc-fallback-nfc_manager)
   - 7.3 [3-Way Deterministic Conflict Resolution Engine](#73-3-way-deterministic-conflict-resolution-engine)
   - 7.4 [Idempotency Key & Sync Protocol](#74-idempotency-key--sync-protocol)
8. [Roster Table UI/UX Redesign (R5)](#8-roster-table-uiux-redesign-r5)
   - 8.1 [60-30-10 Color Architecture & Design Tokens](#81-60-30-10-color-architecture--design-tokens)
   - 8.2 [Unified Compact Data Table (44px Row Height)](#82-unified-compact-data-table-44px-row-height)
   - 8.3 [DepEd Gender Category Tabs & Sorting](#83-deped-gender-category-tabs--sorting)
   - 8.4 [Persistent Top Action Header](#84-persistent-top-action-header)
9. [Multi-Platform Attendance History & Analytics (R6)](#9-multi-platform-attendance-history--analytics-r6)
   - 9.1 [Teacher Web/Mobile Analytics & Early Warning](#91-teacher-webmobile-analytics--early-warning)
   - 9.2 [Student App View-Only Screen & RLS Policy](#92-student-app-view-only-screen--rls-policy)
   - 9.3 [Parent App View-Only Screen & Linked Child RLS](#93-parent-app-view-only-screen--linked-child-rls)
   - 9.4 [Polished Empty State Specification](#94-polished-empty-state-specification)
10. [Strict Error Presentation Guidelines (R7)](#10-strict-error-presentation-guidelines-r7)
11. [Phased Implementation Roadmap & Testing Strategies](#11-phased-implementation-roadmap--testing-strategies)

---

## 1. Executive Summary & Architectural Invariants

The ClassRealm Attendance Feature Redesign provides an enterprise-grade, high-reliability attendance tracking ecosystem. It addresses existing operational bottlenecks:
1. **Physical Card Tracking**: Bridges student identity to ISO 14443-A (13.56 MHz) RFID/NFC cards with duplicate conflict detection.
2. **Autonomous Offline Reliability**: Operates seamlessly in physical classrooms when teacher laptops are closed, Wi-Fi drops, or outdoor classes occur via autonomous ESP32 hardware and mobile phone NFC fallback.
3. **Institutional Compliance**: Enforces plotted Department of Education (DepEd) class schedules, eliminating rogue marks on unscheduled days or school holidays.
4. **Data Monotonicity & Teacher Authority**: Employs mathematically deterministic conflict resolution ensuring that delayed hardware synchronization never downgrades verified on-time attendance, and administrative manual overrides are unconditionally preserved.
5. **Strict UI/UX Ergonomics**: Replaces slow boxed cards with a compact 44px data table, relocates the "Save" action to the sticky top header, and strictly eliminates intrusive SnackBars/toasts in favor of inline input validation and modal alerts.

---

## 2. End-to-End System Architecture

```
                                  +---------------------------------------+
                                  |         Physical RFID / NFC Card      |
                                  |     (13.56 MHz ISO 14443-A UID)       |
                                  +-------------------+-------------------+
                                                      |
                         +----------------------------+----------------------------+
                         |                                                         |
                         v                                                         v
         [PATH A: STANDALONE HARDWARE]                             [PATH B: MOBILE NFC FALLBACK]
+-------------------------------------------------+       +-----------------------------------------------+
|  ESP32 Autonomous Attendance Scanner            |       |  Teacher Mobile App (Flutter)                 |
|  - FreeRTOS Core 1: 20Hz Polling & Debounce     |       |  - nfc_manager ISO14443-A Scanner Session     |
|  - Active Buzzer (2.7kHz) + Visual LEDs         |       |  - Immediate Haptic / Sound Feedback          |
|  - LittleFS Non-Volatile Spool (>6,800 records) |       |  - Local Drift SQLite Cache (LocalAttendance) |
|  - FreeRTOS Core 0: WiFi + HTTPS Sync Worker    |       |  - Drift OfflineSyncQueue Enqueue             |
+------------------------+------------------------+       +-----------------------+-----------------------+
                         |                                                        |
                         | (Direct HTTPS PostgREST / RPC)                         | (SyncCoordinator Drift Queue)
                         v                                                        v
+---------------------------------------------------------------------------------------------------------+
|                                  SUPABASE CLOUD POSTGRESQL BACKEND                                      |
|                                                                                                         |
|  1. Public Tables:                                                                                      |
|     - student_profiles (rfid_uid UNIQUE)             - attendance_records (method, time_in, device_id) |
|     - teacher_schedule (start_time, end_time, DOW)   - attendance_cutoffs (present, late, absent)      |
|     - school_holidays (holiday_date UNIQUE)          - rfid_devices (device_uid, room, teacher)         |
|                                                                                                         |
|  2. Atomic Stored Procedures & Triggers:                                                                |
|     - record_rfid_attendance(uid, offering_id, ts)  -> 3-Way Conflict Engine & Monotonicity Check       |
|     - fn_trigger_daily_auto_absent()                -> 23:59 EOD Cron (skips holidays & unscheduled)    |
|                                                                                                         |
|  3. Row Level Security (RLS) Isolation:                                                                 |
|     - Student: student_id = auth_uid (view-only personal history)                                       |
|     - Parent:  student_id IN (parent_student_links for parent_id = auth_uid) (view-only child history)  |
|     - Teacher: teacher_id = auth_uid (full class management)                                            |
|                                                                                                         |
|  4. Realtime Broadcast Channel:                                                                         |
|     - broadcast: 'attendance_roster:{offering_id}'  -> Instant live table row pulse in Teacher UI       |
+---------------------------------------------------------------------------------------------------------+
                                                      |
                         +----------------------------+----------------------------+
                         |                                                         |
                         v                                                         v
          [TEACHER WEB / MOBILE DASHBOARD]                         [STUDENT & PARENT PORTALS]
  - 44px Compact Unified Data Table                         - View-Only Attendance History & Analytics
  - DepEd Gender Segmented Tabs (All / Male / Female)       - Explicit 'RFID' vs 'Manual' Method Badges
  - Persistent Top Action Header (Save Attendance)          - Polished AppEmptyState Component
  - Dual-Input RFID Assignment Modal                        - Zero Database Error Leaks (Inline / Modal)
```

---

## 3. Database & Data Model Specifications

### 3.1 Supabase PostgreSQL Schema Migration (`008_attendance_overhaul.sql`)

```sql
-- ============================================================
-- CLASSREALM: ATTENDANCE REDESIGN & OVERHAUL MIGRATION
-- Migration File: supabase/migrations/008_attendance_overhaul.sql
-- Covers Requirements: R1, R2, R3, R4, R6
-- ============================================================

BEGIN;

-- 1. ADD RFID UID COLUMN TO STUDENT PROFILES (R2)
ALTER TABLE public.student_profiles 
  ADD COLUMN IF NOT EXISTS rfid_uid varchar(64) NULL;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'uq_student_profiles_rfid_uid'
  ) THEN
    ALTER TABLE public.student_profiles
      ADD CONSTRAINT uq_student_profiles_rfid_uid UNIQUE (rfid_uid);
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_student_profiles_rfid_uid
  ON public.student_profiles (rfid_uid)
  WHERE rfid_uid IS NOT NULL;

-- 2. ENHANCE ATTENDANCE RECORDS TABLE (R2, R3, R4)
ALTER TABLE public.attendance_records
  ADD COLUMN IF NOT EXISTS recording_method varchar(10) NOT NULL DEFAULT 'Manual',
  ADD COLUMN IF NOT EXISTS time_in time without time zone NULL,
  ADD COLUMN IF NOT EXISTS time_out time without time zone NULL,
  ADD COLUMN IF NOT EXISTS device_id varchar(64) NULL,
  ADD COLUMN IF NOT EXISTS updated_at timestamptz NOT NULL DEFAULT now();

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'attendance_records_recording_method_check'
  ) THEN
    ALTER TABLE public.attendance_records
      ADD CONSTRAINT attendance_records_recording_method_check
      CHECK (recording_method IN ('Manual', 'RFID', 'System'));
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_attendance_records_method
  ON public.attendance_records (recording_method);

CREATE INDEX IF NOT EXISTS idx_attendance_records_student_date
  ON public.attendance_records (student_id, attendance_date);

CREATE INDEX IF NOT EXISTS idx_attendance_records_offering_date
  ON public.attendance_records (subject_offering_id, attendance_date);

-- 3. SCHOOL HOLIDAYS & ACADEMIC EXCEPTIONS TABLE (R3)
CREATE TABLE IF NOT EXISTS public.school_holidays (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    holiday_date date NOT NULL,
    holiday_name varchar(100) NOT NULL,
    is_active boolean NOT NULL DEFAULT true,
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT school_holidays_pkey PRIMARY KEY (id),
    CONSTRAINT school_holidays_holiday_date_key UNIQUE (holiday_date)
);

CREATE INDEX IF NOT EXISTS idx_school_holidays_date
  ON public.school_holidays (holiday_date)
  WHERE is_active = true;

-- 4. ATTENDANCE CUTOFF THRESHOLDS TABLE (R3)
CREATE TABLE IF NOT EXISTS public.attendance_cutoffs (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    subject_offering_id uuid NOT NULL,
    schedule_id uuid NULL,
    
    -- Minutes relative to plotted class start_time
    present_start_mins_before integer NOT NULL DEFAULT 15 
      CHECK (present_start_mins_before >= 0 AND present_start_mins_before <= 60),
    present_grace_mins integer NOT NULL DEFAULT 15 
      CHECK (present_grace_mins >= 0 AND present_grace_mins <= 120),
    late_cutoff_mins integer NOT NULL DEFAULT 45 
      CHECK (late_cutoff_mins > present_grace_mins),
    absent_cutoff_mins integer NOT NULL DEFAULT 60 
      CHECK (absent_cutoff_mins > late_cutoff_mins),

    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT attendance_cutoffs_pkey PRIMARY KEY (id),
    CONSTRAINT attendance_cutoffs_subject_offering_id_fkey 
        FOREIGN KEY (subject_offering_id) REFERENCES public.subject_offerings(id) ON DELETE CASCADE,
    CONSTRAINT attendance_cutoffs_schedule_id_fkey 
        FOREIGN KEY (schedule_id) REFERENCES public.teacher_schedule(id) ON DELETE CASCADE,
    CONSTRAINT attendance_cutoffs_unique_offering_schedule 
        UNIQUE (subject_offering_id, schedule_id)
);

-- Validation Trigger: Ensure absent_cutoff_mins does not exceed class duration
CREATE OR REPLACE FUNCTION public.fn_validate_attendance_cutoffs()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    v_sched record;
    v_class_duration_mins integer;
BEGIN
    IF NEW.schedule_id IS NOT NULL THEN
        SELECT * INTO v_sched
        FROM public.teacher_schedule
        WHERE id = NEW.schedule_id;

        IF v_sched IS NOT NULL THEN
            v_class_duration_mins := EXTRACT(EPOCH FROM (v_sched.end_time - v_sched.start_time)) / 60;
            IF NEW.absent_cutoff_mins > v_class_duration_mins THEN
                RAISE EXCEPTION 'absent_cutoff_mins (%) exceeds class duration (% mins) for schedule %',
                    NEW.absent_cutoff_mins, v_class_duration_mins, NEW.schedule_id;
            END IF;
        END IF;
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_validate_attendance_cutoffs ON public.attendance_cutoffs;
CREATE TRIGGER trg_validate_attendance_cutoffs
BEFORE INSERT OR UPDATE ON public.attendance_cutoffs
FOR EACH ROW
EXECUTE FUNCTION public.fn_validate_attendance_cutoffs();

-- 5. REGISTERED HARDWARE & MOBILE DEVICES REGISTRY (R4)
CREATE TABLE IF NOT EXISTS public.rfid_devices (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    device_uid varchar(64) NOT NULL UNIQUE,
    device_name varchar(100) NOT NULL,
    assigned_teacher_id varchar(30) REFERENCES public.teacher_profiles(teacher_id) ON DELETE SET NULL,
    assigned_room varchar(50) NULL,
    last_sync_at timestamptz NULL,
    is_active boolean NOT NULL DEFAULT true,
    created_at timestamptz NOT NULL DEFAULT now(),
    CONSTRAINT rfid_devices_pkey PRIMARY KEY (id)
);

-- 6. ENABLE ROW LEVEL SECURITY & DEFINE ACCESS POLICIES (R6)
ALTER TABLE public.attendance_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.student_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.parent_student_links ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.teacher_schedule ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.attendance_cutoffs ENABLE ROW LEVEL SECURITY;

-- Helper function to resolve authenticated Firebase UID in Supabase Postgres
CREATE OR REPLACE FUNCTION public.current_auth_uid()
RETURNS varchar(30) AS $$
BEGIN
  RETURN COALESCE(
    NULLIF(current_setting('request.jwt.claim.sub', true), ''),
    (NULLIF(current_setting('request.jwt.claims', true), '')::jsonb ->> 'sub'),
    (NULLIF(current_setting('request.jwt.claims', true), '')::jsonb ->> 'user_id')
  )::varchar(30);
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

-- Policy A: Students view ONLY their own attendance
DROP POLICY IF EXISTS "student_view_own_attendance" ON public.attendance_records;
CREATE POLICY "student_view_own_attendance"
ON public.attendance_records
FOR SELECT
TO authenticated, anon
USING (
  student_id = public.current_auth_uid()
);

-- Policy B: Parents view ONLY linked child attendance
DROP POLICY IF EXISTS "parent_view_child_attendance" ON public.attendance_records;
CREATE POLICY "parent_view_child_attendance"
ON public.attendance_records
FOR SELECT
TO authenticated, anon
USING (
  EXISTS (
    SELECT 1 FROM public.parent_student_links psl
    WHERE psl.parent_id = public.current_auth_uid()
      AND psl.student_id = attendance_records.student_id
  )
);

-- Policy C: Teachers manage attendance for assigned subject offerings
DROP POLICY IF EXISTS "teacher_manage_own_attendance" ON public.attendance_records;
CREATE POLICY "teacher_manage_own_attendance"
ON public.attendance_records
FOR ALL
TO authenticated, anon
USING (
  EXISTS (
    SELECT 1 FROM public.subject_offerings so
    WHERE so.id = attendance_records.subject_offering_id
      AND so.teacher_id = public.current_auth_uid()
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.subject_offerings so
    WHERE so.id = attendance_records.subject_offering_id
      AND so.teacher_id = public.current_auth_uid()
  )
);

-- Policy D: Admins have unrestricted institutional access
DROP POLICY IF EXISTS "admin_all_attendance" ON public.attendance_records;
CREATE POLICY "admin_all_attendance"
ON public.attendance_records
FOR ALL
TO authenticated, anon
USING (
  EXISTS (
    SELECT 1 FROM public.users u
    WHERE u.id = public.current_auth_uid()
      AND u.role = 'admin'
  )
);

COMMIT;
```

---

### 3.2 Local SQLite Persistence (Drift Tables)

File location: `lib/data/datasources/local/tables.dart` (Increments `schemaVersion = 2` in `AppDatabase`):

```dart
import 'package:drift/drift.dart';

/// Local offline cache for student directory and RFID bindings
class LocalStudents extends Table {
  TextColumn get studentId => text()();
  TextColumn get lrn => text().nullable()();
  TextColumn get rfidUid => text().nullable()(); // NEW: Local RFID card binding
  TextColumn get firstName => text()();
  TextColumn get middleName => text().nullable()();
  TextColumn get lastName => text()();
  TextColumn get gender => text()(); // 'male', 'female', 'other'
  TextColumn get departmentOrSection => text().nullable()();

  @override
  Set<Column> get primaryKey => {studentId};
}

/// Local offline cache for attendance records with hardware provenance
class LocalAttendanceRecords extends Table {
  TextColumn get id => text()(); // UUID or composite: studentId_offeringId_date
  TextColumn get studentId => text()();
  TextColumn get subjectOfferingId => text()();
  TextColumn get attendanceDate => text()(); // 'YYYY-MM-DD'
  TextColumn get status => text()(); // 'present', 'absent', 'late', 'excused'
  TextColumn get recordingMethod => text().withDefault(const Constant('Manual'))(); // 'Manual', 'RFID', 'System'
  TextColumn get timeIn => text().nullable()(); // 'HH:MM:SS'
  TextColumn get timeOut => text().nullable()();
  TextColumn get deviceId => text().nullable()(); // 'ESP32_ROOM101', 'MOBILE_NFC'
  TextColumn get remarks => text().nullable()();
  TextColumn get recordedBy => text().nullable()();
  TextColumn get syncStatus => text().withDefault(const Constant('synced'))(); // 'synced', 'pending'

  @override
  Set<Column> get primaryKey => {id};
}

/// Local offline cutoff parameters per subject offering
class LocalAttendanceCutoffs extends Table {
  TextColumn get id => text()();
  TextColumn get subjectOfferingId => text()();
  TextColumn get scheduleId => text().nullable()();
  IntColumn get presentStartMinsBefore => integer().withDefault(const Constant(15))();
  IntColumn get presentGraceMins => integer().withDefault(const Constant(15))();
  IntColumn get lateCutoffMins => integer().withDefault(const Constant(45))();
  IntColumn get absentCutoffMins => integer().withDefault(const Constant(60))();

  @override
  Set<Column> get primaryKey => {id};
}

/// Resilient write-ahead sync queue for offline mutations
class OfflineSyncQueue extends Table {
  TextColumn get id => text()(); // Unique idempotency key
  TextColumn get action => text()(); // 'record_rfid_attendance', 'batch_save'
  TextColumn get targetTable => text()(); // 'attendance_records'
  TextColumn get payloadJson => text()(); // Serialized mutation payload
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  IntColumn get retryCount => integer().withDefault(const Constant(0))();
  TextColumn get status => text().withDefault(const Constant('pending'))(); // 'pending', 'processing', 'failed'
  TextColumn get errorMessage => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
```

---

### 3.3 Dart Domain Entities & Value Objects

File location: `lib/models/attendance_workspace_models.dart`:

```dart
import 'package:flutter/foundation.dart';

/// Provenance recording method for auditability (R2)
enum AttendanceSource {
  manual,
  rfid,
  system;

  static AttendanceSource parse(String? value) {
    if (value == null) return AttendanceSource.manual;
    switch (value.trim().toLowerCase()) {
      case 'manual':
        return AttendanceSource.manual;
      case 'rfid':
        return AttendanceSource.rfid;
      case 'system':
        return AttendanceSource.system;
      default:
        return AttendanceSource.manual;
    }
  }

  String toJson() {
    switch (this) {
      case AttendanceSource.manual:
        return 'Manual';
      case AttendanceSource.rfid:
        return 'RFID';
      case AttendanceSource.system:
        return 'System';
    }
  }

  String get label {
    switch (this) {
      case AttendanceSource.manual:
        return 'Manual';
      case AttendanceSource.rfid:
        return 'RFID Scan';
      case AttendanceSource.system:
        return 'Auto (System)';
    }
  }
}

/// Standardized Attendance Status
enum AttendanceStatus {
  present,
  late,
  absent,
  excused;

  static AttendanceStatus parse(String? value) {
    if (value == null) return AttendanceStatus.absent;
    switch (value.trim().toLowerCase()) {
      case 'present':
        return AttendanceStatus.present;
      case 'late':
        return AttendanceStatus.late;
      case 'absent':
        return AttendanceStatus.absent;
      case 'excused':
        return AttendanceStatus.excused;
      default:
        return AttendanceStatus.absent;
    }
  }
}

/// Comprehensive attendance workspace record model
@immutable
class AttendanceWorkspaceRecord {
  final String? id;
  final String studentId;
  final String subjectOfferingId;
  final DateTime attendanceDate;
  final AttendanceStatus status;
  final AttendanceSource source;
  final String? remarks;
  final String? recordedBy;
  final String? timeIn; // e.g. "07:42:15"
  final String? timeOut;
  final String? deviceId; // e.g. "ESP32_ROOM_302"
  final DateTime? createdAt;
  final String? modifiedBy;

  const AttendanceWorkspaceRecord({
    this.id,
    required this.studentId,
    required this.subjectOfferingId,
    required this.attendanceDate,
    required this.status,
    required this.source,
    this.remarks,
    this.recordedBy,
    this.timeIn,
    this.timeOut,
    this.deviceId,
    this.createdAt,
    this.modifiedBy,
  });

  factory AttendanceWorkspaceRecord.fromJson(Map<String, dynamic> json) {
    return AttendanceWorkspaceRecord(
      id: json['id']?.toString(),
      studentId: json['student_id']?.toString() ?? '',
      subjectOfferingId: json['subject_offering_id']?.toString() ?? '',
      attendanceDate: DateTime.parse(json['attendance_date'].toString()),
      status: AttendanceStatus.parse(json['status']?.toString()),
      source: AttendanceSource.parse(
        json['recording_method']?.toString() ?? json['source']?.toString(),
      ),
      remarks: json['remarks']?.toString(),
      recordedBy: json['recorded_by']?.toString(),
      timeIn: json['time_in']?.toString(),
      timeOut: json['time_out']?.toString(),
      deviceId: json['device_id']?.toString(),
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'].toString()) : null,
      modifiedBy: json['modified_by']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    if (id != null) 'id': id,
    'student_id': studentId,
    'subject_offering_id': subjectOfferingId,
    'attendance_date': "${attendanceDate.year.toString().padLeft(4, '0')}-${attendanceDate.month.toString().padLeft(2, '0')}-${attendanceDate.day.toString().padLeft(2, '0')}",
    'status': status.name,
    'recording_method': source.toJson(),
    if (remarks != null) 'remarks': remarks,
    if (recordedBy != null) 'recorded_by': recordedBy,
    if (timeIn != null) 'time_in': timeIn,
    if (timeOut != null) 'time_out': timeOut,
    if (deviceId != null) 'device_id': deviceId,
  };
}

/// Roster student representation with linked RFID identifier (R2, R5)
@immutable
class AttendanceRosterStudent {
  final String studentId;
  final String? lrn;
  final String? rfidUid; // Unique physical card identifier
  final String firstName;
  final String? middleName;
  final String lastName;
  final String gender;

  const AttendanceRosterStudent({
    required this.studentId,
    this.lrn,
    this.rfidUid,
    required this.firstName,
    this.middleName,
    required this.lastName,
    required this.gender,
  });

  bool get hasRfidAssigned => rfidUid != null && rfidUid!.trim().isNotEmpty;

  String get fullNameFormatted => '$lastName, $firstName${middleName != null && middleName!.isNotEmpty ? ' ${middleName![0]}.' : ''}';

  factory AttendanceRosterStudent.fromJson(Map<String, dynamic> json) {
    return AttendanceRosterStudent(
      studentId: json['student_id']?.toString() ?? '',
      lrn: json['lrn']?.toString(),
      rfidUid: json['rfid_uid']?.toString(),
      firstName: json['first_name']?.toString() ?? '',
      middleName: json['middle_name']?.toString(),
      lastName: json['last_name']?.toString() ?? '',
      gender: (json['gender']?.toString() ?? 'unspecified').toLowerCase(),
    );
  }

  Map<String, dynamic> toJson() => {
    'student_id': studentId,
    'lrn': lrn,
    'rfid_uid': rfidUid,
    'first_name': firstName,
    'middle_name': middleName,
    'last_name': lastName,
    'gender': gender,
  };
}
```

---

## 4. API Contracts, Stored Procedures & Edge Functions

### 4.1 Atomic Postgres RPC: `record_rfid_attendance`

This procedure is invoked directly by ESP32 devices and the Flutter mobile sync engine:

```sql
CREATE OR REPLACE FUNCTION public.record_rfid_attendance(
    p_rfid_uid varchar(64),
    p_subject_offering_id uuid,
    p_scan_timestamp timestamptz,
    p_device_id varchar(64) DEFAULT 'HARDWARE_ESP32'
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_student_id varchar(30);
    v_student_name text;
    v_attendance_date date := (p_scan_timestamp AT TIME ZONE 'Asia/Manila')::date;
    v_scan_time time := (p_scan_timestamp AT TIME ZONE 'Asia/Manila')::time;
    v_dow smallint := EXTRACT(ISODOW FROM v_attendance_date)::smallint;
    v_schedule record;
    v_cutoffs record;
    v_existing record;
    v_calculated_status varchar(10);
    v_is_holiday boolean;
    v_present_open_time time;
    v_present_grace_cutoff time;
    v_late_cutoff time;
    v_absent_cutoff time;
BEGIN
    -- 1. HOLIDAY CHECK (R3)
    SELECT EXISTS (
        SELECT 1 FROM public.school_holidays 
        WHERE holiday_date = v_attendance_date AND is_active = true
    ) INTO v_is_holiday;

    IF v_is_holiday THEN
        RETURN jsonb_build_object(
            'success', false,
            'code', 'HOLIDAY_LOCKED',
            'message', 'Today is a recognized school holiday. Attendance scans are disabled.'
        );
    END IF;

    -- 2. IDENTIFY STUDENT BY RFID UID (R2)
    SELECT student_id, first_name || ' ' || last_name
    INTO v_student_id, v_student_name
    FROM public.student_profiles
    WHERE UPPER(TRIM(rfid_uid)) = UPPER(TRIM(p_rfid_uid));

    IF v_student_id IS NULL THEN
        RETURN jsonb_build_object(
            'success', false,
            'code', 'UNREGISTERED_CARD',
            'message', 'This card UID is not registered to any student.',
            'rfid_uid', p_rfid_uid
        );
    END IF;

    -- 3. VERIFY SECTION ENROLLMENT (R3)
    IF NOT EXISTS (
        SELECT 1 FROM public.student_enrollments
        WHERE student_id = v_student_id
          AND subject_offering_id = p_subject_offering_id
          AND status = 'enrolled'
    ) THEN
        RETURN jsonb_build_object(
            'success', false,
            'code', 'CROSS_SECTION_TAP',
            'message', 'Student ' || v_student_name || ' is not enrolled in this subject offering.',
            'student_name', v_student_name
        );
    END IF;

    -- 4. VALIDATE PLOTTED SCHEDULE (R3)
    SELECT * INTO v_schedule
    FROM public.teacher_schedule
    WHERE subject_offering_id = p_subject_offering_id
      AND day_of_week = v_dow
      AND is_active = true
    LIMIT 1;

    IF v_schedule IS NULL THEN
        RETURN jsonb_build_object(
            'success', false,
            'code', 'NO_SCHEDULE_TODAY',
            'message', 'No class scheduled for this subject today.'
        );
    END IF;

    -- 5. LOAD CUTOFF CONFIGURATION (Fix 3: v_present_grace_cutoff, v_late_cutoff, v_absent_cutoff)
    SELECT * INTO v_cutoffs
    FROM public.attendance_cutoffs
    WHERE subject_offering_id = p_subject_offering_id
    LIMIT 1;

    -- Default cutoffs if not customized by teacher
    v_present_open_time := v_schedule.start_time - (COALESCE(v_cutoffs.present_start_mins_before, 15) * INTERVAL '1 minute');
    v_present_grace_cutoff := v_schedule.start_time + (COALESCE(v_cutoffs.present_grace_mins, 15) * INTERVAL '1 minute');
    v_late_cutoff := v_schedule.start_time + (COALESCE(v_cutoffs.late_cutoff_mins, 45) * INTERVAL '1 minute');
    v_absent_cutoff := v_schedule.start_time + (COALESCE(v_cutoffs.absent_cutoff_mins, 60) * INTERVAL '1 minute');

    -- Boundary checks
    IF v_scan_time < v_present_open_time THEN
        RETURN jsonb_build_object(
            'success', false,
            'code', 'BEFORE_WINDOW_OPENS',
            'message', 'Too early to scan. Attendance window opens at ' || to_char(v_present_open_time, 'HH12:MI AM')
        );
    ELSIF v_scan_time > v_schedule.end_time THEN
        RETURN jsonb_build_object(
            'success', false,
            'code', 'AFTER_CLASS_ENDS',
            'message', 'Class ended at ' || to_char(v_schedule.end_time, 'HH12:MI AM') || '. Scans are closed.'
        );
    ELSIF v_scan_time > v_absent_cutoff THEN
        RETURN jsonb_build_object(
            'success', false,
            'code', 'SCANS_CLOSED',
            'message', 'Attendance cutoff window passed at ' || to_char(v_absent_cutoff, 'HH12:MI AM') || '. Scans are closed.'
        );
    END IF;

    -- Calculate Status
    IF v_scan_time <= v_present_grace_cutoff THEN
        v_calculated_status := 'present';
    ELSIF v_scan_time <= v_late_cutoff THEN
        v_calculated_status := 'late';
    ELSE
        v_calculated_status := 'absent';
    END IF;

    -- 6. INSPECT EXISTING RECORD & APPLY 3-WAY CONFLICT RULES (R4, Fix 1, Fix 2)
    SELECT * INTO v_existing
    FROM public.attendance_records
    WHERE student_id = v_student_id
      AND subject_offering_id = p_subject_offering_id
      AND attendance_date = v_attendance_date;

    IF v_existing IS NOT NULL THEN
        -- RULE 1: TEACHER MANUAL OVERRIDE PREVENTS OVERWRITE (Administrative Authority)
        -- Strictly keep manual teacher edits and excused status immutable
        IF v_existing.recording_method = 'Manual' OR v_existing.status = 'excused' THEN
            RETURN jsonb_build_object(
                'success', true,
                'code', 'MANUAL_OVERRIDE_PRESERVED',
                'status', v_existing.status,
                'student_name', v_student_name,
                'message', 'Existing manual teacher mark preserved.'
            );
        END IF;

        -- RULE 2A: SYSTEM AUTO-ABSENT OVERWRITE/PROMOTION VIA DELAYED OFFLINE TAP (Fix 2)
        -- If student was marked absent by the 23:59 EOD System cron, a delayed on-time/late tap from ESP32 spool promotes it
        IF v_existing.recording_method = 'System' AND v_existing.status = 'absent' THEN
            UPDATE public.attendance_records
            SET status = v_calculated_status,
                recording_method = 'RFID',
                time_in = v_scan_time,
                device_id = p_device_id,
                remarks = 'Promoted from System Auto-Absent via delayed offline RFID tap',
                updated_at = now()
            WHERE id = v_existing.id;

            RETURN jsonb_build_object(
                'success', true,
                'code', 'PROMOTED_FROM_AUTO_ABSENT',
                'status', v_calculated_status,
                'student_name', v_student_name,
                'time_in', to_char(v_scan_time, 'HH12:MI AM'),
                'message', 'Attendance recovered and promoted from Auto-Absent.'
            );
        END IF;

        -- RULE 2B: STATUS MONOTONICITY (LATE -> PRESENT PROMOTION)
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
                'time_in', to_char(v_scan_time, 'HH12:MI AM'),
                'message', 'Attendance promoted to Present based on earlier tap.'
            );
        END IF;

        -- RULE 2C: TIMESTAMP PRIORITY FOR MATCHING STATUS (EARLIER PHYSICAL TAP WINS) (Fix 1)
        -- When existing record is present and an earlier on-time tap arrives (v_scan_time < v_existing.time_in)
        IF v_existing.status = 'present' AND v_calculated_status = 'present' 
           AND v_existing.time_in IS NOT NULL AND v_scan_time < v_existing.time_in THEN
            UPDATE public.attendance_records
            SET time_in = v_scan_time,
                device_id = p_device_id,
                remarks = 'Timestamp updated to earlier physical tap',
                updated_at = now()
            WHERE id = v_existing.id;

            RETURN jsonb_build_object(
                'success', true,
                'code', 'TIMESTAMP_PROMOTED',
                'status', 'present',
                'student_name', v_student_name,
                'time_in', to_char(v_scan_time, 'HH12:MI AM'),
                'message', 'Timestamp updated to earlier physical tap.'
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
    END IF;

    -- 7. INSERT NEW ATTENDANCE RECORD
    INSERT INTO public.attendance_records (
        student_id,
        subject_offering_id,
        attendance_date,
        status,
        recording_method,
        time_in,
        device_id,
        remarks,
        created_at,
        updated_at
    ) VALUES (
        v_student_id,
        p_subject_offering_id,
        v_attendance_date,
        v_calculated_status,
        'RFID',
        v_scan_time,
        p_device_id,
        'Recorded via ' || p_device_id,
        now(),
        now()
    );

    RETURN jsonb_build_object(
        'success', true,
        'code', 'RECORDED_SUCCESS',
        'status', v_calculated_status,
        'student_name', v_student_name,
        'time_in', to_char(v_scan_time, 'HH12:MI AM'),
        'message', 'Attendance successfully recorded as ' || INITCAP(v_calculated_status)
    );
END;
$$;

-- 4.1B BATCH RFID ATTENDANCE RPC (Fix 6: Rapid Spool Drain for ESP32 & Mobile Sync)
-- Drains up to 50 offline scans in a single HTTP request (<2s total round trip)
CREATE OR REPLACE FUNCTION public.record_rfid_attendance_batch(
    p_scans jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_item jsonb;
    v_res jsonb;
    v_results jsonb := '[]'::jsonb;
    v_success_count integer := 0;
    v_fail_count integer := 0;
BEGIN
    FOR v_item IN SELECT * FROM jsonb_array_elements(p_scans)
    LOOP
        v_res := public.record_rfid_attendance(
            p_rfid_uid => (v_item->>'rfid_uid')::varchar,
            p_subject_offering_id => (v_item->>'subject_offering_id')::uuid,
            p_scan_timestamp => (v_item->>'scan_timestamp')::timestamptz,
            p_device_id => COALESCE((v_item->>'device_id')::varchar, 'HARDWARE_ESP32')
        );

        v_results := v_results || jsonb_build_object(
            'rfid_uid', v_item->>'rfid_uid',
            'code', v_res->>'code',
            'status', v_res->>'status',
            'success', (v_res->>'success')::boolean
        );

        IF (v_res->>'success')::boolean IS TRUE THEN
            v_success_count := v_success_count + 1;
        ELSE
            v_fail_count := v_fail_count + 1;
        END IF;
    END LOOP;

    RETURN jsonb_build_object(
        'total', jsonb_array_length(p_scans),
        'success_count', v_success_count,
        'fail_count', v_fail_count,
        'results', v_results
    );
END;
$$;
```

---

### 4.2 EOD 23:59 Auto-Absent Engine (`fn_trigger_daily_auto_absent`)

```sql
CREATE OR REPLACE FUNCTION public.fn_trigger_daily_auto_absent(
    p_target_date date DEFAULT (now() AT TIME ZONE 'Asia/Manila')::date
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_dow smallint;
    v_is_holiday boolean;
    v_inserted_count integer := 0;
BEGIN
    -- 1. Check if date is a holiday (R3)
    SELECT EXISTS (
        SELECT 1 FROM public.school_holidays 
        WHERE holiday_date = p_target_date AND is_active = true
    ) INTO v_is_holiday;

    IF v_is_holiday THEN
        RETURN jsonb_build_object(
            'status', 'skipped',
            'reason', 'School holiday',
            'date', p_target_date,
            'inserted', 0
        );
    END IF;

    v_dow := EXTRACT(ISODOW FROM p_target_date)::smallint;

    -- 2. Identify all subject offerings plotted for today's day of week
    WITH scheduled_offerings AS (
        SELECT DISTINCT ts.subject_offering_id
        FROM public.teacher_schedule ts
        JOIN public.subject_offerings so ON so.id = ts.subject_offering_id
        WHERE ts.day_of_week = v_dow
          AND ts.is_active = true
          AND so.is_archived = false
    ),
    -- 3. Identify enrolled students lacking an attendance mark for today
    unmarked_students AS (
        SELECT 
            se.student_id,
            se.subject_offering_id,
            p_target_date AS attendance_date
        FROM public.student_enrollments se
        JOIN scheduled_offerings so ON so.subject_offering_id = se.subject_offering_id
        WHERE se.status = 'enrolled'
          AND NOT EXISTS (
              SELECT 1 FROM public.attendance_records ar
              WHERE ar.student_id = se.student_id
                AND ar.subject_offering_id = se.subject_offering_id
                AND ar.attendance_date = p_target_date
          )
    ),
    -- 4. Insert Auto-Absent records without overwriting
    inserted_rows AS (
        INSERT INTO public.attendance_records (
            student_id,
            subject_offering_id,
            attendance_date,
            status,
            recording_method,
            remarks,
            created_at,
            updated_at
        )
        SELECT 
            student_id,
            subject_offering_id,
            attendance_date,
            'absent',
            'System',
            'Auto-Absent (Unscanned at EOD)',
            now(),
            now()
        FROM unmarked_students
        ON CONFLICT (student_id, subject_offering_id, attendance_date) DO NOTHING
        RETURNING id
    )
    SELECT COUNT(*) FROM inserted_rows INTO v_inserted_count;

    RETURN jsonb_build_object(
        'status', 'success',
        'date', p_target_date,
        'day_of_week', v_dow,
        'inserted_absences', v_inserted_count
    );
END;
$$;
```

---

### 4.3 Supabase Edge Function: `daily-auto-absent`

Location: `supabase/functions/daily-auto-absent/index.ts`:

```typescript
import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

serve(async (req) => {
  // Enforce service-role authorization
  const authHeader = req.headers.get("Authorization");
  const expectedSecret = Deno.env.get("CRON_SERVICE_SECRET") ?? Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  
  if (!authHeader || !authHeader.includes(expectedSecret ?? "")) {
    return new Response(JSON.stringify({ error: "Unauthorized access" }), {
      status: 401,
      headers: { "Content-Type": "application/json" },
    });
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  const supabase = createClient(supabaseUrl, serviceRoleKey);

  // Invoke atomic stored procedure
  const { data, error } = await supabase.rpc("fn_trigger_daily_auto_absent");

  if (error) {
    return new Response(JSON.stringify({ success: false, error: error.message }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }

  return new Response(JSON.stringify({ success: true, result: data }), {
    status: 200,
    headers: { "Content-Type": "application/json" },
  });
});
```

---

### 4.4 Flutter Repository Contract (`SupabaseAttendanceRepository`)

Additions to `lib/data/repositories/supabase_attendance_repository.dart`:

```dart
abstract class AttendanceRepositoryContract {
  /// Assign physical RFID card UID to student with conflict validation
  Future<void> assignStudentRfid({
    required String studentId,
    required String rfidUid,
    bool forceReassign = false,
  });

  /// Submit a single hardware/mobile RFID scan to atomic RPC
  Future<Map<String, dynamic>> recordRfidScan({
    required String rfidUid,
    required String subjectOfferingId,
    required DateTime scanTimestamp,
    String deviceId = 'MOBILE_NFC',
  });

  /// Save teacher batch changes with explicit source tracking
  Future<void> saveAttendanceBatch({
    required String subjectOfferingId,
    required DateTime attendanceDate,
    required List<AttendanceWorkspaceRecord> records,
  });

  /// Fetch section history KPIs and warnings (>= 3 absences)
  Future<AttendanceAnalyticsSummary> getSectionAttendanceAnalytics({
    required String subjectOfferingId,
    required DateTime startDate,
    required DateTime endDate,
  });
}
```

---

## 5. Teacher RFID Card Assignment Engine (R2)

### 5.1 Card Assignment Workflow & UX

The teacher can assign physical cards directly from two high-traffic surfaces:
1. **Teacher Roster Table (`attendance_roster_table.dart`)**: In the `RFID Card` column, unassigned students display an `[+ Link Card]` button. Assigned students display their masked UID tag (e.g. `04:A2:3B:5C`) with a tap-to-edit action.
2. **Student Directory (`teacher_student_management_tab.dart`)**: Beside the Edit and Archive icons for each student row, a dedicated `CreditCard` icon button opens the modal.

### 5.2 Dual-Input Assignment Modal Specification

File location: `lib/shared/widgets/modals/rfid_assignment_modal.dart`

```
+-------------------------------------------------------------+
|  [Icon: CreditCard]  Assign RFID Card                  [ X ] |
|  Link a physical card to: Alcantara, Marcus (LRN: 10928374)  |
+-------------------------------------------------------------+
|   [ Tab 1: USB / Keyboard Scanner ]   [ Tab 2: Phone NFC ]   |
|                                                             |
|   +-----------------------------------------------------+   |
|   |  Tap card on reader or enter UID...                 |   |
|   |  [ 04:A2:3B:5C:8D:1E:80                           ] |   |
|   +-----------------------------------------------------+   |
|   * Please enter a valid card UID (minimum 4 hex chars).   |   |
|     (Inline error appears here in red if format is invalid) |
|                                                             |
|   Status: Waiting for card scan... [Animated Pulse Graphic] |
|                                                             |
|   [ Cancel ]                             [ Save Assignment ]|
+-------------------------------------------------------------+
```

1. **Tab 1: USB / Keyboard Wedge Scanner**:
   - Focuses a dedicated text field with an invisible `FocusNode`.
   - Listens for rapid keystrokes ending with `Enter` (Carriage Return).
   - Automatically sanitizes characters: removes colons, spaces, trims, and converts to uppercase hexadecimal.
   - Allows manual typing fallback for damaged barcode labels.
2. **Tab 2: Phone NFC Tap**:
   - Available on Android and iOS devices supporting NFC.
   - Initiates `MobileNfcAttendanceService` scanner session.
   - Prompts teacher: *"Hold student card against the back of your phone."*
   - Plays haptic confirmation (`HapticFeedback.mediumImpact()`) upon successful read and populates UID.

### 5.3 Conflict Guarding & Reassignment Protocol

Before committing to `student_profiles`:
1. Check if `rfid_uid` is already assigned to a different student:
   ```sql
   SELECT student_id, first_name || ' ' || last_name, lrn 
   FROM public.student_profiles 
   WHERE rfid_uid = UPPER(TRIM(p_rfid_uid));
   ```
2. If conflict detected:
   - **DO NOT throw an unhandled database error**.
   - Open `AppModals.showConfirmationDialog`:
     - **Title**: *"Card Reassignment Required"*
     - **Body**: *"Card UID `[UID]` is currently assigned to **[Existing Student Name]** (LRN: [LRN]). Do you wish to transfer this card to **[Target Student Name]**?"*
     - **Action Buttons**: `Cancel` (Neutral) vs `Transfer & Assign` (Orange Accent).
3. If confirmed, execute atomic reassignment transaction clearing the old student's `rfid_uid` and assigning it to the new student.

### 5.4 Audit Trail & Recording Method Indicator

Every record across all tables, history views, and logs displays an explicit provenance badge:
- **`RFID`**: Rendered with `AppTheme.catTeal` (`#0D9488`), icon `LucideIcons.radio`.
- **`Manual`**: Rendered with `AppTheme.catSlate` (`#475569`), icon `LucideIcons.edit3`.
- **`System`**: Rendered with `AppTheme.catBlue` (`#2563EB`), icon `LucideIcons.cpu`.

---

## 6. Schedule-Connected Auto-Status & Cutoff Validation (R3)

### 6.1 Schedule Guarding Logic

Whenever a teacher navigates to the attendance tab or an RFID scan arrives:
1. Extract target day of week: `targetDate.weekday` (1=Mon ... 7=Sun).
2. Query active `teacher_schedule` for `subject_offering_id` matching `day_of_week`.
3. If no matching schedule exists:
   - **Lock Attendance Workspace**: The roster displays a clean banner: *"No class scheduled for [Subject] on [Date]. Attendance is locked."*
   - **Disable RFID Scanners**: Background keystroke listeners and NFC sessions ignore all incoming taps.
   - **Disable Batch Mark Buttons**: "Mark All Present" and "Auto-Absent" are disabled to prevent accidental modifications on rest days.

### 6.2 Mathematical Cutoff Invariant & Validation Rules

For any scheduled class with start time $T_{\text{start}}$ and end time $T_{\text{end}}$:

$$\text{Scan Window Open} = T_{\text{start}} - T_{\text{present\_start\_mins}}$$
$$\text{Present Cutoff} = T_{\text{start}} + T_{\text{present\_grace\_mins}}$$
$$\text{Late Cutoff} = T_{\text{start}} + T_{\text{late\_cutoff\_mins}}$$
$$\text{Absent Cutoff} = T_{\text{start}} + T_{\text{absent\_cutoff\_mins}}$$

#### Chronological Invariant Requirement
$$T_{\text{open}} \le T_{\text{start}} < T_{\text{present\_cutoff}} < T_{\text{late\_cutoff}} < T_{\text{absent\_cutoff}} \le T_{\text{end}}$$

- **UI Validation in Cutoff Settings Dialog**:
  - `Present Grace Period` must be $\ge 0$ and $< \text{Late Cutoff}$.
  - `Late Cutoff` must be $> \text{Present Grace Period}$ and $< \text{Absent Cutoff}$.
  - `Absent Cutoff` must be $> \text{Late Cutoff}$ and $\le \text{Class Duration}$ ($T_{\text{end}} - T_{\text{start}}$).
  - Overlapping, equal, or inverted thresholds immediately display an **inline red validation message** beneath the slider/input field: *"Absent threshold must be strictly after Late cutoff and within class duration."*

---

## 7. Dual-Path Offline Attendance Pipeline (R4)

### 7.1 Standalone ESP32 Hardware Reader
- Operates autonomously with zero dependency on the teacher's laptop.
- FreeRTOS dual-core task segregation:
  - **Core 1**: High-priority RFID sensing (20Hz), software debouncing (5-second dead time per student), immediate audio/visual feedback cues (< 50ms).
  - **Core 0**: Wi-Fi station connectivity, NTP clock synchronization, LittleFS append-only ring buffer (`/spool/attendance_queue.jsonl`), draining batches of 25–50 scans via `record_rfid_attendance_batch` HTTPS POST to Supabase when network is available (<2 seconds for 100 scans).
- LittleFS holds $>6,800$ offline scans with power-fail resilience and `MAX_SPOOL_BYTES` allocation guard.
- *(Complete BOM, circuit schematics, pinout tables, and firmware are detailed in `docs/ESP32_RFID_BUILD_GUIDE.md`)*.

### 7.2 Mobile Phone NFC Fallback (`nfc_manager`)
- Implemented in Teacher Mobile App (`lib/core/services/mobile_nfc_service.dart`).
- Uses smartphone's built-in NFC transceiver.
- Evaluates student status locally against cached Drift SQLite `LocalAttendanceCutoffs`.
- Stores scan in Drift `LocalAttendanceRecords` and queues sync packet in `OfflineSyncQueue`.
- `SyncCoordinator` monitors `connectivity_plus` and drains queued scans automatically on network reconnection.

### 7.3 3-Way Deterministic Conflict Resolution Engine

| Incoming Scan Source | Existing Database Record | Resolution Outcome | Database Action | Justification |
|---|---|---|---|---|
| **ESP32 (Offline Queue)** | *None (Unmarked)* | **ESP32 Wins** | Insert `status = incoming`, `source = 'RFID'`, `time_in = incoming.ts`. | First recorded tap. |
| **ESP32 (Offline Queue, 07:54 AM)** | **Late (from Mobile NFC, 08:08 AM)** | **Earliest Tap Wins (Late -> Present)** | **Promote `status` to 'present'**, update `time_in = '07:54:00'`. | Fairness Rule: Student tapped on-time at door scanner; mobile scan was taken later during roll-call. |
| **ESP32 (Offline Queue, 07:55 AM)** | **Present (from Mobile NFC, 08:05 AM)** | **Timestamp Priority (Fix 1)** | **Retain `status = 'present'`, update `time_in = '07:55:00'`, `device_id = 'HARDWARE_ESP32'**, remarks = `'Timestamp updated to earlier physical tap'`. Return `TIMESTAMP_PROMOTED`. | Audit Priority: Both verified Present, earlier physical tap timestamp preserves precise student arrival time. |
| **ESP32 (Offline Queue, 08:12 AM)** | **Present (from Mobile NFC, 07:58 AM)** | **Monotonicity Rule** | **Retain `status = 'present'`**, reject downgrade. | Monotonicity: Automated scans cannot downgrade verified present status. |
| **ESP32 (Offline Queue, yesterday)** | **Absent (from 23:59 EOD System Cron)** | **System Auto-Absent Promotion (Fix 2)** | **Promote `status` to 'present' or 'late'**, update `recording_method = 'RFID'`, `time_in = incoming.ts`, remarks = `'Promoted from System Auto-Absent via delayed offline RFID tap'`. Return `PROMOTED_FROM_AUTO_ABSENT`. | Offline Recovery: Hardware buffered taps before network restored across midnight. System auto-absent is recovered, while teacher manual overrides remain immutable. |
| **ESP32 (Offline Queue)** | **Excused / Present (Teacher Manual Edit)** | **Teacher Override Wins** | **RETAIN existing record**, do not overwrite. | Authority Rule: Teacher discretion supersedes automated hardware taps. Manual marks and Excused marks are strictly immutable. |
| **Teacher Manual Edit** | **Any status from RFID** | **Teacher Wins Immediately** | Update `status = new_status`, `source = 'Manual'`. | Administrative authority. |
| **23:59 EOD Cron** | *None (Unmarked)* | **System Marks Absent** | Insert `status = 'absent'`, `source = 'System'`. | End-of-day unmarked student resolution. |
| **23:59 EOD Cron** | **Present / Late / Excused** | **Cron Skips** | **NO-OP**. | Cron never alters existing verified attendance marks. |

---

## 8. Roster Table UI/UX Redesign (R5)

### 8.1 60-30-10 Color Architecture & Design Tokens
- **60% Base**: `#F5F5F5` (Light mode background) / `#111827` (Dark mode background).
- **30% Structure**: `#FFFFFF` (Data table card surface) / `#1F2937` (Dark table card surface).
- **10% Intentional Accent**: `#487898` (Steel Blue action button) / `#60A5FA` (Sky blue dark accent).
- **Semantic Colors**: Present (`#16A34A`), Late (`#D97706`), Absent (`#DC2626`), Excused (`#475569`), RFID Badge (`#0D9488`).

### 8.2 Unified Compact Data Table (44px Row Height)
Replace individual boxed cards with a unified data table (`attendance_roster_table.dart`):

| Col # | Header Name | Alignment | Width / Flex | Content Description |
|---|---|---|---|---|
| **1** | `#` | Center | 40px fixed | Sequential row number (1, 2, 3...) |
| **2** | `LRN` | Left | 110px fixed | Monospace DepEd ID (`109283746501`) |
| **3** | `Student Name` | Left | Flex 3 | Bold `Last Name, First Name M.I.` (No circular avatar) |
| **4** | `RFID Card` | Center | 120px fixed | Teal chip `04:A2:3B` or Grey outline `[+ Link]` |
| **5** | `Attendance Status` | Center | 230px fixed | 4-button segmented toggle: `[ P ] [ L ] [ A ] [ E ]` |
| **6** | `Time In / Source` | Left | Flex 2 | Time badge: `07:42 AM` + `RFID` or `Manual` chip |

### 8.3 DepEd Gender Category Tabs & Sorting
- Students sorted **alphabetically by Last Name** by default.
- Header includes segmented filter tabs:
  - `[ All (45) ]` | `[ Male (22) ]` | `[ Female (23) ]`
- Default view groups into collapsible/headed sections:
  - **MALE (22 Students)**
  - **FEMALE (23 Students)**
  *(Complies with DepEd School Form 2 standard layout).*

### 8.4 Persistent Top Action Header
Relocated from the bottom scroll view to the sticky top card:
- **Left**: Subject offering selector, Date navigator (`< Today >`).
- **Center**: Gender filter tabs.
- **Right**:
  - `[ Save Attendance ]` Primary Button (`AppButton.primary`, icon: `LucideIcons.save`).
  - Dirty indicator badge: `"Unsaved Changes"` when local edits are pending.
  - Dropdown batch actions: `"Mark All Present"`, `"Auto-Absent Unmarked"`.

---

## 9. Multi-Platform Attendance History & Analytics (R6)

### 9.1 Teacher Web/Mobile Analytics & Early Warning
Location: `lib/features/teacher/sub_features/attendance/widgets/attendance_history_analytics_view.dart`:
- **KPI Summary Cards**:
  - Attendance Rate: `89.4%` (Trend indicator vs previous week).
  - Total Absences & Excuses: `42 absences`, `6 excused`.
  - **Attendance Warnings (Early Warning Indicator)**: Highlighted count of students with $\ge 3$ cumulative absences in the selected period (DepEd dropout intervention rule).
- **Date Range Filters**: `This Week` | `This Month` | `Custom Range` (inline date pickers).
- **Interactive Daily Trend Chart**: Bar/area chart comparing Present vs Late/Absent daily counts.
- **At-Risk Student Drill-Down**: Table listing flagged students, total absences, consecutive absence counter, and direct "Contact Parent" action button.

### 9.2 Student App View-Only Screen & RLS Policy
Location: `lib/features/student/sub_features/schedule/screens/student_attendance_screen.dart`:
- Strictly view-only; all interactive status toggles and save buttons are omitted.
- Scoped at database level by Supabase RLS policy `student_view_own_attendance`.
- Displays personal attendance rate KPI, total present/late/absent counts.
- Chronological logs list showing Subject, Date, Status chip, and **explicit Source badge (`RFID` vs `Manual`)**.
- Polished empty state when no records exist.

### 9.3 Parent App View-Only Screen & Linked Child RLS
Location: `lib/features/parent/sub_features/child_details/widgets/parent_attendance_tab.dart`:
- Strictly view-only; scoped at database level by Supabase RLS policy `parent_view_child_attendance`.
- Child switcher dropdown in app bar for parents with multiple enrolled students.
- Real-time attendance feed showing when their child tapped in at the school reader (`07:42 AM via RFID`).
- Polished empty state when no records exist.

### 9.4 Polished Empty State Specification
Component: `lib/shared/widgets/empty_states/app_empty_state.dart`:
- **Visual**: Illustrated outline icon (`LucideIcons.calendarCheck2` or `LucideIcons.school`) in Primary Accent tone (`#487898`).
- **Heading**: `"No Attendance Records Yet"` (Inter SemiBold 18px).
- **Subtext**: `"Attendance logs recorded by your teacher or captured via RFID card taps will appear here in real time."` (Inter Regular 14px, muted secondary color).
- **Action**: `"Refresh Records"` outline button (`AppButton.outline`).

---

## 10. Strict Error Presentation Guidelines (R7)

*(Refer to `docs/ATTENDANCE_VALIDATION_MATRIX.md` for exhaustive edge cases and exact copy).*

1. **PROHIBITION OF SNACKBARS**:
   - `ScaffoldMessenger.of(context).showSnackBar()` is **STRICTLY PROHIBITED** for form errors, card conflicts, scanner notices, or network sync messages.
2. **FORM & INPUT VALIDATION**:
   - Must use **Inline Input Errors**: 1.5px red border (`#DC2626`) around input field with 12px error text directly underneath. Error clears immediately upon keystroke/change.
3. **SYSTEM, HARDWARE & CONFLICT ALERTS**:
   - Must use centered **Modal Dialogs** via `AppModals.showErrorDialog()` or `AppModals.showConfirmationDialog()`.
   - All error messages must be sanitized using `AppModals.sanitizeErrorMessage()`. Zero database codes, stack traces, or raw exceptions (`$e`) permitted.

---

## 11. Phased Implementation Roadmap & Testing Strategies

```
+---------------------------------------------------------------------------------+
| PHASE 1: DATABASE & CLOUD FOUNDATION                                            |
| - Execute migration 008_attendance_overhaul.sql on Supabase                     |
| - Implement atomic Postgres RPC: record_rfid_attendance()                       |
| - Implement bulk drain RPC: record_rfid_attendance_batch()                      |
| - Implement stored procedure: fn_trigger_daily_auto_absent()                    |
| - Configure Supabase Edge Function & pg_cron schedule at 15:59 UTC              |
| - Configure and verify Row Level Security (RLS) policies                        |
+---------------------------------------------------------------------------------+
                                       |
                                       v
+---------------------------------------------------------------------------------+
| PHASE 2: LOCAL PERSISTENCE & REPOSITORIES                                       |
| - Increment Drift database schemaVersion to 2; update tables.dart               |
| - Update AttendanceWorkspaceRecord, AttendanceRosterStudent, AttendanceSource   |
| - Implement SupabaseAttendanceRepository methods and RPC integrations           |
| - Add Drift offline caching methods in AppDatabase                              |
+---------------------------------------------------------------------------------+
                                       |
                                       v
+---------------------------------------------------------------------------------+
| PHASE 3: HARDWARE & MOBILE NFC SERVICES                                         |
| - Add nfc_manager & connectivity_plus dependencies                              |
| - Implement MobileNfcAttendanceService for Android/iOS                          |
| - Build, flash, and bench-test ESP32 autonomous RFID scanner firmware           |
| - Verify LittleFS offline spooling (>6,800 scans) and burst batch sync (<2s)    |
+---------------------------------------------------------------------------------+
                                       |
                                       v
+---------------------------------------------------------------------------------+
| PHASE 4: UI/UX REDESIGN (TEACHER, STUDENT, PARENT)                             |
| - Implement 44px compact AttendanceRosterTable with gender tabs                 |
| - Relocate "Save Attendance" button to persistent top action header             |
| - Build dual-input RfidAssignmentModal (USB Scanner + Phone NFC Tap)            |
| - Eliminate all SnackBars across teacher, student, and parent modules           |
| - Build AppEmptyState and update Student & Parent view-only portals             |
+---------------------------------------------------------------------------------+
                                       |
                                       v
+---------------------------------------------------------------------------------+
| PHASE 5: QUALITY ASSURANCE, REGRESSION & E2E TESTING                            |
| - Unit tests: Cutoff calculations, model parsing, conflict resolution logic     |
| - Drift offline queue integration tests                                         |
| - RLS security tests (student viewing another student's attendance blocked)     |
| - Hardware bench stress test (power cycling, offline buffer flush)              |
+---------------------------------------------------------------------------------+
```

### Testing Strategies
- **Unit Testing**:
  - `test/models/attendance_workspace_models_test.dart`: Parsing of `AttendanceSource.rfid`, `AttendanceSource.system`, and `AttendanceWorkspaceRecord`.
  - `test/services/cutoff_validation_test.dart`: Invariant testing ensuring inverted cutoffs throw validation errors.
- **RLS Verification**:
  - Test authenticated queries under Student UID verifying that queries for different student IDs return zero rows.
- **Offline & Conflict Simulation**:
  - Simulate offline scan enqueue, manual teacher override, and verify monotonic promotion logic.
