// Realtime Student Proctoring State
// File size constrained to <= 350 lines according to project architecture policy.

import 'proctor_violation_log.dart';

enum ProctorSessionStatus {
  notStarted,
  inProgress,
  submitted,
  kicked,
  retakeRequested,
}

extension ProctorSessionStatusExtension on ProctorSessionStatus {
  String get value {
    switch (this) {
      case ProctorSessionStatus.notStarted:
        return 'not_started';
      case ProctorSessionStatus.inProgress:
        return 'in_progress';
      case ProctorSessionStatus.submitted:
        return 'submitted';
      case ProctorSessionStatus.kicked:
        return 'kicked';
      case ProctorSessionStatus.retakeRequested:
        return 'retake_requested';
    }
  }

  String get displayName {
    switch (this) {
      case ProctorSessionStatus.notStarted:
        return 'Not Started';
      case ProctorSessionStatus.inProgress:
        return 'Taking Test';
      case ProctorSessionStatus.submitted:
        return 'Submitted';
      case ProctorSessionStatus.kicked:
        return 'Kicked / Disqualified';
      case ProctorSessionStatus.retakeRequested:
        return 'Retake Authorized';
    }
  }

  static ProctorSessionStatus fromString(String val) {
    switch (val) {
      case 'in_progress':
        return ProctorSessionStatus.inProgress;
      case 'submitted':
        return ProctorSessionStatus.submitted;
      case 'kicked':
        return ProctorSessionStatus.kicked;
      case 'retake_requested':
        return ProctorSessionStatus.retakeRequested;
      default:
        return ProctorSessionStatus.notStarted;
    }
  }
}

class StudentLiveProctorState {
  final String studentId;
  final String studentName;
  final String lrn;
  final String section;
  final ProctorSessionStatus status;
  final int violationCount;
  final List<ProctorViolationLog> violations;
  final DateTime? lastActiveAt;
  final String? kickedReason;
  final String? gender;
  final double? score;
  final double? totalPoints;
  final bool isEntryAllowed;
  final int? currentQuestionNumber;
  final bool isMissing;
  final String? lastName;
  final String? firstName;
  final String? middleName;

  const StudentLiveProctorState({
    required this.studentId,
    required this.studentName,
    required this.lrn,
    required this.section,
    required this.status,
    required this.violationCount,
    this.violations = const [],
    this.lastActiveAt,
    this.kickedReason,
    this.gender,
    this.score,
    this.totalPoints,
    this.isEntryAllowed = true,
    this.currentQuestionNumber,
    this.isMissing = false,
    this.lastName,
    this.firstName,
    this.middleName,
  });

  bool get hasViolations => violationCount > 0;
  bool get isSevere => violationCount >= 3;

  StudentLiveProctorState copyWith({
    String? studentId,
    String? studentName,
    String? lrn,
    String? section,
    ProctorSessionStatus? status,
    int? violationCount,
    List<ProctorViolationLog>? violations,
    DateTime? lastActiveAt,
    String? kickedReason,
    String? gender,
    double? score,
    double? totalPoints,
    bool? isEntryAllowed,
    int? currentQuestionNumber,
    bool? isMissing,
    String? lastName,
    String? firstName,
    String? middleName,
  }) {
    return StudentLiveProctorState(
      studentId: studentId ?? this.studentId,
      studentName: studentName ?? this.studentName,
      lrn: lrn ?? this.lrn,
      section: section ?? this.section,
      status: status ?? this.status,
      violationCount: violationCount ?? this.violationCount,
      violations: violations ?? this.violations,
      lastActiveAt: lastActiveAt ?? this.lastActiveAt,
      kickedReason: kickedReason ?? this.kickedReason,
      gender: gender ?? this.gender,
      score: score ?? this.score,
      totalPoints: totalPoints ?? this.totalPoints,
      isEntryAllowed: isEntryAllowed ?? this.isEntryAllowed,
      currentQuestionNumber: currentQuestionNumber ?? this.currentQuestionNumber,
      isMissing: isMissing ?? this.isMissing,
      lastName: lastName ?? this.lastName,
      firstName: firstName ?? this.firstName,
      middleName: middleName ?? this.middleName,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'student_id': studentId,
      'student_name': studentName,
      'lrn': lrn,
      'section': section,
      'status': status.value,
      'violation_count': violationCount,
      'violations': violations.map((v) => v.toJson()).toList(),
      'last_active_at': lastActiveAt?.toIso8601String(),
      'kicked_reason': kickedReason,
      'gender': gender,
      'score': score,
      'total_points': totalPoints,
      'is_entry_allowed': isEntryAllowed,
      'current_question_number': currentQuestionNumber,
      'is_missing': isMissing,
      'last_name': lastName,
      'first_name': firstName,
      'middle_name': middleName,
    };
  }

  factory StudentLiveProctorState.fromJson(Map<String, dynamic> json) {
    return StudentLiveProctorState(
      studentId: json['student_id']?.toString() ?? '',
      studentName: json['student_name']?.toString() ?? 'Student',
      lrn: json['lrn']?.toString() ?? '',
      section: json['section']?.toString() ?? '',
      status: ProctorSessionStatusExtension.fromString(
        json['status']?.toString() ?? '',
      ),
      violationCount: (json['violation_count'] as num?)?.toInt() ?? 0,
      violations:
          (json['violations'] as List<dynamic>?)
              ?.map(
                (v) => ProctorViolationLog.fromJson(v as Map<String, dynamic>),
              )
              .toList() ??
          const [],
      lastActiveAt: json['last_active_at'] != null
          ? DateTime.tryParse(json['last_active_at'].toString())
          : null,
      kickedReason: json['kicked_reason']?.toString(),
      gender: json['gender']?.toString(),
      score: (json['score'] as num?)?.toDouble(),
      totalPoints: (json['total_points'] as num?)?.toDouble(),
      isEntryAllowed: json['is_entry_allowed'] != false,
      currentQuestionNumber: (json['current_question_number'] as num?)?.toInt(),
      isMissing: json['is_missing'] == true,
      lastName: json['last_name']?.toString(),
      firstName: json['first_name']?.toString(),
      middleName: json['middle_name']?.toString(),
    );
  }
}
