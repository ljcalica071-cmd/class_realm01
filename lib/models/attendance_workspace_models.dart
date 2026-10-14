import 'academic_models.dart';

export 'academic_models.dart' show AttendanceStatus;

enum AttendanceSource {
  manual,
  rfid;

  static AttendanceSource parse(String? value) {
    if (value == null) return AttendanceSource.manual;

    switch (value.trim().toLowerCase()) {
      case 'manual':
        return AttendanceSource.manual;
      case 'rfid':
        return AttendanceSource.rfid;
      default:
        throw FormatException('Unsupported attendance source: $value');
    }
  }

  String toJson() => name;
}

class AttendanceWorkspaceRecord {
  final String? id;
  final String studentId;
  final String subjectOfferingId;
  final DateTime attendanceDate;
  final AttendanceStatus status;
  final AttendanceSource source;
  final String? remarks;
  final String? recordedBy;
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
    this.createdAt,
    this.modifiedBy,
  });

  factory AttendanceWorkspaceRecord.fromJson(Map<String, dynamic> json) {
    return AttendanceWorkspaceRecord(
      id: _optionalString(json, 'id'),
      studentId: _requiredString(json, 'student_id'),
      subjectOfferingId: _requiredString(json, 'subject_offering_id'),
      attendanceDate: _parseDate(_requiredValue(json, 'attendance_date')),
      status: _parseStatus(_requiredString(json, 'status')),
      source: AttendanceSource.parse(_optionalString(json, 'source')),
      remarks: _optionalString(json, 'remarks'),
      recordedBy: _optionalString(json, 'recorded_by'),
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
    'source': source.toJson(),
    'remarks': remarks,
    'recorded_by': recordedBy,
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
  }) : assert(subjectOfferingId != ''),
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
  final int totalDays;
  final double presenceRate;

  const AttendanceStudentSummary({
    required this.studentId,
    required this.presentCount,
    required this.totalDays,
    required this.presenceRate,
  });

  factory AttendanceStudentSummary.fromJson(Map<String, dynamic> json) {
    return AttendanceStudentSummary(
      studentId: _requiredString(json, 'student_id'),
      presentCount: (json['present_count'] as num?)?.toInt() ?? 0,
      totalDays: (json['total_days'] as num?)?.toInt() ?? 0,
      presenceRate: (json['presence_rate'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
    'student_id': studentId,
    'present_count': presentCount,
    'total_days': totalDays,
    'presence_rate': presenceRate,
  };
}

class AttendanceRosterStudent {
  final String studentId;
  final String firstName;
  final String? middleName;
  final String lastName;
  final String gender; // 'male', 'female', 'unspecified'

  const AttendanceRosterStudent({
    required this.studentId,
    required this.firstName,
    this.middleName,
    required this.lastName,
    required this.gender,
  });

  /// Formatted as: Last name, First name, Middle initial. (e.g. Dela Cruz, Juan H.)
  String get displayName {
    final ln = lastName.trim();
    final fn = firstName.trim();
    final mn = middleName?.trim();
    final mi = (mn != null && mn.isNotEmpty) ? '${mn[0].toUpperCase()}.' : null;

    final parts = [
      if (ln.isNotEmpty) '$ln,',
      if (fn.isNotEmpty) fn,
      if (mi != null) mi,
    ];
    if (parts.isEmpty) return studentId;
    return parts.join(' ');
  }

  factory AttendanceRosterStudent.fromJson(Map<String, dynamic> json) {
    return AttendanceRosterStudent(
      studentId: json['student_id']?.toString() ?? '',
      firstName: json['first_name']?.toString() ?? '',
      middleName: json['middle_name']?.toString(),
      lastName: json['last_name']?.toString() ?? '',
      gender: (json['gender']?.toString() ?? 'unspecified').toLowerCase(),
    );
  }

  Map<String, dynamic> toJson() => {
    'student_id': studentId,
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

String _requiredString(Map<String, dynamic> json, String key) {
  final value = _requiredValue(json, key);
  if (value is String && value.isNotEmpty) return value;
  throw FormatException('Expected a non-empty string for "$key".');
}

String? _optionalString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value == null) return null;
  if (value is String) return value;
  throw FormatException('Expected a string or null for "$key".');
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
    if (status.name == value.toLowerCase()) return status;
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
