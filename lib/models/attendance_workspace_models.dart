import 'package:flutter/foundation.dart';
import 'academic_models.dart';

export 'academic_models.dart' show AttendanceStatus;

enum AttendanceSource {
  manual,
  rfid,
  system;

  static AttendanceSource parse(String? value) {
    if (value == null || value.trim().isEmpty) return AttendanceSource.manual;

    switch (value.trim().toLowerCase()) {
      case 'manual':
        return AttendanceSource.manual;
      case 'rfid':
      case 'rfid scan':
        return AttendanceSource.rfid;
      case 'system':
      case 'auto':
      case 'auto (system)':
        return AttendanceSource.system;
      default:
        throw FormatException('Unsupported attendance source: $value');
    }
  }

  /// Canonical database value ('Manual', 'RFID', 'System')
  String toDbString() {
    switch (this) {
      case AttendanceSource.manual:
        return 'Manual';
      case AttendanceSource.rfid:
        return 'RFID';
      case AttendanceSource.system:
        return 'System';
    }
  }

  String toJson() => toDbString();

  String get label {
    switch (this) {
      case AttendanceSource.manual:
        return 'Manual';
      case AttendanceSource.rfid:
        return 'RFID';
      case AttendanceSource.system:
        return 'System';
    }
  }
}

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
  final String? timeIn;
  final String? deviceId;
  final DateTime? createdAt;
  final String? modifiedBy;

  const AttendanceWorkspaceRecord({
    required this.id,
    required this.studentId,
    required this.subjectOfferingId,
    required this.attendanceDate,
    required this.status,
    required this.source,
    this.remarks,
    this.recordedBy,
    this.timeIn,
    this.deviceId,
    this.createdAt,
    this.modifiedBy,
  });

  AttendanceWorkspaceRecord copyWith({
    String? id,
    String? studentId,
    String? subjectOfferingId,
    DateTime? attendanceDate,
    AttendanceStatus? status,
    AttendanceSource? source,
    String? remarks,
    String? recordedBy,
    String? timeIn,
    String? deviceId,
    DateTime? createdAt,
    String? modifiedBy,
  }) {
    return AttendanceWorkspaceRecord(
      id: id ?? this.id,
      studentId: studentId ?? this.studentId,
      subjectOfferingId: subjectOfferingId ?? this.subjectOfferingId,
      attendanceDate: attendanceDate ?? this.attendanceDate,
      status: status ?? this.status,
      source: source ?? this.source,
      remarks: remarks ?? this.remarks,
      recordedBy: recordedBy ?? this.recordedBy,
      timeIn: timeIn ?? this.timeIn,
      deviceId: deviceId ?? this.deviceId,
      createdAt: createdAt ?? this.createdAt,
      modifiedBy: modifiedBy ?? this.modifiedBy,
    );
  }

  factory AttendanceWorkspaceRecord.fromJson(Map<String, dynamic> json) {
    return AttendanceWorkspaceRecord(
      id: _optionalString(json, 'id'),
      studentId: _requiredString(json, 'student_id'),
      subjectOfferingId: _requiredString(json, 'subject_offering_id'),
      attendanceDate: _parseDate(_requiredValue(json, 'attendance_date')),
      status: _parseStatus(_requiredString(json, 'status')),
      source: AttendanceSource.parse(
        _optionalString(json, 'recording_method') ??
            _optionalString(json, 'source'),
      ),
      remarks: _optionalString(json, 'remarks'),
      recordedBy: _optionalString(json, 'recorded_by'),
      timeIn: _optionalString(json, 'time_in'),
      deviceId: _optionalString(json, 'device_id'),
      createdAt: _optionalDate(json, 'created_at'),
      modifiedBy: _optionalString(json, 'modified_by'),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'student_id': studentId,
        'subject_offering_id': subjectOfferingId,
        'attendance_date': _formatDate(attendanceDate),
        'status': status.name,
        'recording_method': source.toDbString(),
        'source': source.name,
        'remarks': remarks,
        'recorded_by': recordedBy,
        'time_in': timeIn,
        'device_id': deviceId,
        'created_at': createdAt?.toUtc().toIso8601String(),
        'modified_by': modifiedBy,
      };
}

class AttendanceDateRange {
  final DateTime startDate;
  final DateTime endDate;

  AttendanceDateRange({required DateTime startDate, required DateTime endDate})
      : startDate = _dateOnly(startDate),
        endDate = _dateOnly(endDate) {
    if (this.startDate.isAfter(this.endDate)) {
      throw ArgumentError('The start date must not be after the end date.');
    }
  }

  Map<String, String> toJson() => {
        'start_date': _formatDate(startDate),
        'end_date': _formatDate(endDate),
      };
}

class AttendanceHistoryFilter {
  final String subjectOfferingId;
  final AttendanceDateRange dateRange;
  final int offset;
  final int pageSize;

  const AttendanceHistoryFilter({
    required this.subjectOfferingId,
    required this.dateRange,
    this.offset = 0,
    this.pageSize = 20,
  })  : assert(subjectOfferingId != ''),
        assert(offset >= 0),
        assert(pageSize > 0);
}

class AttendancePage<T> {
  final List<T> rows;
  final int nextOffset;
  final bool hasMore;

  AttendancePage({
    required List<T> rows,
    required this.nextOffset,
    required this.hasMore,
  }) : rows = List<T>.unmodifiable(rows) {
    if (nextOffset < 0) {
      throw ArgumentError.value(
        nextOffset,
        'nextOffset',
        'Must be nonnegative',
      );
    }
  }
}

class AttendanceStatusCounts {
  final int presentCount;
  final int lateCount;
  final int absentCount;
  final int excusedCount;
  final int unmarkedCount;

  const AttendanceStatusCounts({
    required this.presentCount,
    required this.lateCount,
    required this.absentCount,
    required this.excusedCount,
    required this.unmarkedCount,
  });

  int get markedCount => presentCount + lateCount + absentCount + excusedCount;
}

class AttendancePresenceMetrics {
  final double? presenceRate;
  final int absencesAndExcuses;

  const AttendancePresenceMetrics({
    required this.presenceRate,
    required this.absencesAndExcuses,
  });
}

class AttendanceTrendPoint {
  final DateTime? bucketStart;
  final String? periodLabel;
  final int presentCount;
  final int absentOrExcusedCount;

  const AttendanceTrendPoint({
    this.bucketStart,
    this.periodLabel,
    required this.presentCount,
    required this.absentOrExcusedCount,
  });
}

class AttendanceAtRiskStudent {
  final String studentId;
  final String studentName;
  final String section;
  final int absenceCount;

  const AttendanceAtRiskStudent({
    required this.studentId,
    required this.studentName,
    required this.section,
    required this.absenceCount,
  });
}

class AttendanceAnalyticsSummary {
  final double? presenceRate;
  final int absencesAndExcuses;
  final int warningCount;
  final int presentCount;
  final int lateCount;
  final int absentCount;
  final int excusedCount;
  final List<AttendanceTrendPoint> trendPoints;
  final List<AttendanceAtRiskStudent> atRiskStudents;

  const AttendanceAnalyticsSummary({
    required this.presenceRate,
    required this.absencesAndExcuses,
    required this.warningCount,
    required this.presentCount,
    required this.lateCount,
    required this.absentCount,
    required this.excusedCount,
    this.trendPoints = const [],
    this.atRiskStudents = const [],
  });
}

class AttendanceStudentSummary {
  final String studentId;
  final int presentCount;
  final int lateCount;
  final int absentCount;
  final int excusedCount;
  final int totalDays;
  final double presenceRate; // 0.0 to 100.0 percentage

  const AttendanceStudentSummary({
    required this.studentId,
    required this.presentCount,
    this.lateCount = 0,
    this.absentCount = 0,
    this.excusedCount = 0,
    required this.totalDays,
    required this.presenceRate,
  });

  factory AttendanceStudentSummary.fromJson(Map<String, dynamic> json) {
    return AttendanceStudentSummary(
      studentId: _requiredString(json, 'student_id'),
      presentCount: (json['present_count'] as num?)?.toInt() ?? 0,
      lateCount: (json['late_count'] as num?)?.toInt() ?? 0,
      absentCount: (json['absent_count'] as num?)?.toInt() ?? 0,
      excusedCount: (json['excused_count'] as num?)?.toInt() ?? 0,
      totalDays: (json['total_days'] as num?)?.toInt() ?? 0,
      presenceRate: (json['presence_rate'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
        'student_id': studentId,
        'present_count': presentCount,
        'late_count': lateCount,
        'absent_count': absentCount,
        'excused_count': excusedCount,
        'total_days': totalDays,
        'presence_rate': presenceRate,
      };
}

@immutable
class AttendanceRosterStudent {
  final String studentId;
  final String? lrn;
  final String? rfidUid;
  final String firstName;
  final String? middleName;
  final String lastName;
  final String gender; // 'male', 'female', 'unspecified'

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

  String? get middleInitial {
    final mn = middleName?.trim();
    if (mn == null || mn.isEmpty) return null;
    return '${mn[0].toUpperCase()}.';
  }

  /// Formatted as: Last name, First name, Middle initial. (e.g. Calica, Ljay H.)
  String get displayName {
    final ln = lastName.trim();
    final fn = firstName.trim();
    final mi = middleInitial;

    final parts = [
      if (ln.isNotEmpty) '$ln,',
      if (fn.isNotEmpty) fn,
      ?mi,
    ];
    if (parts.isEmpty) return studentId;
    return parts.join(' ');
  }

  AttendanceRosterStudent copyWith({
    String? studentId,
    String? lrn,
    String? rfidUid,
    bool clearRfidUid = false,
    String? firstName,
    String? middleName,
    String? lastName,
    String? gender,
  }) {
    return AttendanceRosterStudent(
      studentId: studentId ?? this.studentId,
      lrn: lrn ?? this.lrn,
      rfidUid: clearRfidUid ? null : (rfidUid ?? this.rfidUid),
      firstName: firstName ?? this.firstName,
      middleName: middleName ?? this.middleName,
      lastName: lastName ?? this.lastName,
      gender: gender ?? this.gender,
    );
  }

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

class AttendanceRosterResult {
  final List<AttendanceRosterStudent> students;
  final List<AttendanceWorkspaceRecord> records;

  const AttendanceRosterResult({
    required this.students,
    required this.records,
  });
}

@immutable
class AttendanceCutoffConfig {
  final String subjectOfferingId;
  final int presentStartMinsBefore;
  final int presentGraceMins;
  final int lateCutoffMins;
  final int absentCutoffMins;

  const AttendanceCutoffConfig({
    required this.subjectOfferingId,
    this.presentStartMinsBefore = 15,
    this.presentGraceMins = 15,
    this.lateCutoffMins = 45,
    this.absentCutoffMins = 60,
  });

  factory AttendanceCutoffConfig.fromJson(Map<String, dynamic> json) {
    return AttendanceCutoffConfig(
      subjectOfferingId: json['subject_offering_id']?.toString() ?? '',
      presentStartMinsBefore:
          (json['present_start_mins_before'] as num?)?.toInt() ?? 15,
      presentGraceMins: (json['present_grace_mins'] as num?)?.toInt() ?? 15,
      lateCutoffMins: (json['late_cutoff_mins'] as num?)?.toInt() ?? 45,
      absentCutoffMins: (json['absent_cutoff_mins'] as num?)?.toInt() ?? 60,
    );
  }

  Map<String, dynamic> toJson() => {
        'subject_offering_id': subjectOfferingId,
        'present_start_mins_before': presentStartMinsBefore,
        'present_grace_mins': presentGraceMins,
        'late_cutoff_mins': lateCutoffMins,
        'absent_cutoff_mins': absentCutoffMins,
      };

  AttendanceCutoffConfig copyWith({
    String? subjectOfferingId,
    int? presentStartMinsBefore,
    int? presentGraceMins,
    int? lateCutoffMins,
    int? absentCutoffMins,
  }) {
    return AttendanceCutoffConfig(
      subjectOfferingId: subjectOfferingId ?? this.subjectOfferingId,
      presentStartMinsBefore:
          presentStartMinsBefore ?? this.presentStartMinsBefore,
      presentGraceMins: presentGraceMins ?? this.presentGraceMins,
      lateCutoffMins: lateCutoffMins ?? this.lateCutoffMins,
      absentCutoffMins: absentCutoffMins ?? this.absentCutoffMins,
    );
  }
}

@immutable
class AttendanceScheduleStatus {
  final bool hasPlottedScheduleAnyDay;
  final bool isScheduledOnDate;
  final bool isHoliday;
  final String? holidayName;
  final String? startTime; // HH:mm:ss or HH:mm
  final String? endTime;
  final String? room;
  final AttendanceCutoffConfig cutoffConfig;

  const AttendanceScheduleStatus({
    required this.hasPlottedScheduleAnyDay,
    required this.isScheduledOnDate,
    this.isHoliday = false,
    this.holidayName,
    this.startTime,
    this.endTime,
    this.room,
    required this.cutoffConfig,
  });

  bool get isLockedByDefault =>
      isHoliday || (hasPlottedScheduleAnyDay && !isScheduledOnDate);

  String? get lockReason {
    if (isHoliday) {
      return holidayName != null && holidayName!.trim().isNotEmpty
          ? 'School Holiday: $holidayName — Attendance scans are locked for this date.'
          : 'Recognized School Holiday — Attendance scans are locked for this date.';
    }
    if (hasPlottedScheduleAnyDay && !isScheduledOnDate) {
      return 'No class session is plotted for this subject on the selected day.';
    }
    return null;
  }
}

@immutable
class RfidScanOutcome {
  final bool success;
  final String code;
  final AttendanceStatus? status;
  final String? studentId;
  final String? studentName;
  final String? timeIn;
  final String message;
  final bool isOfflineQueued;

  const RfidScanOutcome({
    required this.success,
    required this.code,
    this.status,
    this.studentId,
    this.studentName,
    this.timeIn,
    required this.message,
    this.isOfflineQueued = false,
  });

  factory RfidScanOutcome.fromJson(
    Map<String, dynamic> json, {
    bool isOfflineQueued = false,
  }) {
    final statusRaw = json['status']?.toString();
    AttendanceStatus? parsedStatus;
    if (statusRaw != null && statusRaw.trim().isNotEmpty) {
      for (final s in AttendanceStatus.values) {
        if (s.name == statusRaw.trim().toLowerCase()) {
          parsedStatus = s;
          break;
        }
      }
    }
    return RfidScanOutcome(
      success: json['success'] == true,
      code: json['code']?.toString() ?? 'UNKNOWN',
      status: parsedStatus,
      studentId: json['student_id']?.toString(),
      studentName: json['student_name']?.toString(),
      timeIn: json['time_in']?.toString(),
      message: json['message']?.toString() ?? '',
      isOfflineQueued: isOfflineQueued,
    );
  }
}

@immutable
class RfidCardConflictCheck {
  final bool isTaken;
  final String? existingStudentId;
  final String? existingStudentName;
  final String? existingLrn;

  const RfidCardConflictCheck({
    required this.isTaken,
    this.existingStudentId,
    this.existingStudentName,
    this.existingLrn,
  });
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = _requiredValue(json, key);
  final str = value.toString();
  if (str.isNotEmpty) return str;
  throw FormatException('Expected a non-empty string for "$key".');
}

String? _optionalString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  return value.toString();
}

Object _requiredValue(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) throw FormatException('Missing required value "$key".');
  return value;
}

DateTime _parseDate(Object value) {
  if (value is DateTime) return value;
  if (value is String) {
    final parsed = DateTime.tryParse(value);
    if (parsed != null) return parsed;
  }
  throw FormatException('Invalid attendance date: $value');
}

DateTime? _optionalDate(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  return _parseDate(value);
}

AttendanceStatus _parseStatus(String value) {
  for (final status in AttendanceStatus.values) {
    if (status.name == value.trim().toLowerCase()) return status;
  }
  throw FormatException('Unsupported attendance status: $value');
}

DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

String _formatDate(DateTime date) {
  final year = date.year.toString().padLeft(4, '0');
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}
