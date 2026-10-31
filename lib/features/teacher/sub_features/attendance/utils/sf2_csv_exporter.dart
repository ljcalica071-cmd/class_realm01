import 'package:csv/csv.dart';
import 'package:class_realm/models/attendance_workspace_models.dart';
import 'sf2_save_outcome.dart';
import 'sf2_file_saver_stub.dart'
    if (dart.library.io) 'sf2_file_saver_io.dart'
    if (dart.library.js_interop) 'sf2_file_saver_web.dart';

export 'sf2_save_outcome.dart';

class Sf2CsvExporter {
  static String sf2CodeForStatus(AttendanceStatus status) {
    switch (status) {
      case AttendanceStatus.present:
        return 'P';
      case AttendanceStatus.late:
        return 'L';
      case AttendanceStatus.absent:
        return 'X';
      case AttendanceStatus.excused:
        return 'E';
    }
  }

  static String formatDateIso(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  /// Generates a DepEd SF2-compatible CSV summary of the class attendance
  /// analytics, early-warning learners, per-learner tallies, and daily logs.
  static String buildSf2SummaryCsv({
    required String subjectOfferingId,
    required AttendanceDateRange dateRange,
    required AttendanceAnalyticsSummary summary,
    required List<AttendanceWorkspaceRecord> historyRows,
    DateTime? generatedAt,
  }) {
    final now = generatedAt ?? DateTime.now();
    final startStr = formatDateIso(dateRange.startDate);
    final endStr = formatDateIso(dateRange.endDate);
    final rateStr = summary.presenceRate != null
        ? '${summary.presenceRate!.clamp(0.0, 100.0).toStringAsFixed(1)}%'
        : '0.0%';

    final csvRows = <List<dynamic>>[
      ['DepEd School Form 2 (SF2) - Daily Attendance Report of Learners'],
      ['System', 'CLASSREALM Integrated SHS Management System'],
      ['Subject Offering ID', subjectOfferingId],
      ['Reporting Period', '$startStr to $endStr'],
      ['Generated At', now.toIso8601String()],
      [],
      ['--- SUMMARY KPI METRICS ---'],
      [
        'Presence Rate (%)',
        'Present',
        'Late / Tardy',
        'Absent',
        'Excused',
        'Early Warning Count (>= 3 Absences)',
      ],
      [
        rateStr,
        summary.presentCount,
        summary.lateCount,
        summary.absentCount,
        summary.excusedCount,
        summary.warningCount > summary.atRiskStudents.length
            ? summary.warningCount
            : summary.atRiskStudents.length,
      ],
      [],
      ['--- EARLY WARNING AT-RISK LEARNERS (>= 3 ABSENCES) ---'],
      ['Student ID', 'Learner Name', 'Section', 'Absences', 'Intervention Status'],
    ];

    if (summary.atRiskStudents.isEmpty) {
      csvRows.add(['—', 'None (All learners in good standing)', '—', 0, 'Good Standing']);
    } else {
      for (final s in summary.atRiskStudents) {
        csvRows.add([
          s.studentId,
          s.studentName,
          s.section,
          s.absenceCount,
          '3+ Absences — Intervention Needed',
        ]);
      }
    }

    // Aggregate per-student SF2 tallies from loaded records
    final uniqueDates = <String>{};
    final perStudentByDate = <String, Map<String, AttendanceStatus>>{};
    for (final rec in historyRows) {
      final d = formatDateIso(rec.attendanceDate);
      uniqueDates.add(d);
      (perStudentByDate[rec.studentId] ??= {})[d] = rec.status;
    }
    final sortedDates = uniqueDates.toList()..sort();
    final sortedStudents = perStudentByDate.keys.toList()..sort();

    csvRows.add([]);
    csvRows.add([
      '--- LEARNER SF2 DAILY MATRIX (Codes: P=Present, L=Late, X=Absent, E=Excused) ---',
    ]);
    csvRows.add([
      'Student ID',
      ...sortedDates,
      'Total Present',
      'Total Late',
      'Total Absent',
      'Total Excused',
      'Presence Rate (%)',
    ]);

    for (final studentId in sortedStudents) {
      final dateMap = perStudentByDate[studentId]!;
      int p = 0, l = 0, a = 0, e = 0;
      final dateCodes = <String>[];
      for (final d in sortedDates) {
        final st = dateMap[d];
        if (st == null) {
          dateCodes.add('');
        } else {
          dateCodes.add(sf2CodeForStatus(st));
          switch (st) {
            case AttendanceStatus.present:
              p++;
              break;
            case AttendanceStatus.late:
              l++;
              break;
            case AttendanceStatus.absent:
              a++;
              break;
            case AttendanceStatus.excused:
              e++;
              break;
          }
        }
      }
      final accounted = p + l + a;
      final sRate = accounted > 0
          ? '${(((p + l) / accounted) * 100.0).toStringAsFixed(1)}%'
          : '0.0%';
      csvRows.add([
        studentId,
        ...dateCodes,
        p,
        l,
        a,
        e,
        sRate,
      ]);
    }

    csvRows.add([]);
    csvRows.add(['--- DETAILED ATTENDANCE AUDIT LOG ---']);
    csvRows.add([
      'Date',
      'Student ID',
      'Status',
      'SF2 Code',
      'Time In',
      'Provenance / Source',
      'Remarks',
    ]);

    for (final row in historyRows) {
      csvRows.add([
        formatDateIso(row.attendanceDate),
        row.studentId,
        row.status.name.toUpperCase(),
        sf2CodeForStatus(row.status),
        (row.timeIn != null && row.timeIn!.trim().isNotEmpty)
            ? row.timeIn!.trim()
            : '—',
        row.source.label,
        row.remarks ?? '',
      ]);
    }

    return const ListToCsvConverter().convert(csvRows);
  }

  static Future<Sf2SaveOutcome> exportSf2Csv({
    required String fileName,
    required String csvContent,
  }) {
    return saveSf2CsvPlatform(
      fileName: fileName,
      csvContent: csvContent,
    );
  }
}
