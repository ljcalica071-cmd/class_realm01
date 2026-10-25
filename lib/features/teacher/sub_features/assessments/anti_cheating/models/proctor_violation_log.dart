// Model for Anti-Cheating violation events
// File size constrained to <= 350 lines according to project architecture policy.

enum ProctorViolationType {
  tabSwitch,
  windowBlur,
  appBackgrounded,
}

extension ProctorViolationTypeExtension on ProctorViolationType {
  String get value {
    switch (this) {
      case ProctorViolationType.tabSwitch:
        return 'tab_switch';
      case ProctorViolationType.windowBlur:
        return 'window_blur';
      case ProctorViolationType.appBackgrounded:
        return 'app_backgrounded';
    }
  }

  String get displayName {
    switch (this) {
      case ProctorViolationType.tabSwitch:
        return 'Tab Switch';
      case ProctorViolationType.windowBlur:
        return 'Window Unfocused';
      case ProctorViolationType.appBackgrounded:
        return 'App Backgrounded';
    }
  }

  static ProctorViolationType fromString(String val) {
    switch (val) {
      case 'tab_switch':
        return ProctorViolationType.tabSwitch;
      case 'window_blur':
        return ProctorViolationType.windowBlur;
      case 'app_backgrounded':
        return ProctorViolationType.appBackgrounded;
      default:
        return ProctorViolationType.tabSwitch;
    }
  }
}

class ProctorViolationLog {
  final String id;
  final String attemptId;
  final String studentId;
  final String studentName;
  final ProctorViolationType violationType;
  final int durationSeconds;
  final DateTime timestamp;

  const ProctorViolationLog({
    required this.id,
    required this.attemptId,
    required this.studentId,
    required this.studentName,
    required this.violationType,
    required this.durationSeconds,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'attempt_id': attemptId,
      'student_id': studentId,
      'student_name': studentName,
      'violation_type': violationType.value,
      'duration_seconds': durationSeconds,
      'created_at': timestamp.toIso8601String(),
    };
  }

  factory ProctorViolationLog.fromJson(Map<String, dynamic> json) {
    return ProctorViolationLog(
      id: json['id']?.toString() ?? '',
      attemptId: json['attempt_id']?.toString() ?? '',
      studentId: json['student_id']?.toString() ?? '',
      studentName: json['student_name']?.toString() ?? 'Student',
      violationType: ProctorViolationTypeExtension.fromString(
        json['violation_type']?.toString() ?? '',
      ),
      durationSeconds: (json['duration_seconds'] as num?)?.toInt() ?? 0,
      timestamp: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
