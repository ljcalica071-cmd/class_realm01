// Models for Admin Portal, System Settings, User Session Logs, and Activity Analytics
// Follows strict IT Admin privacy guidelines: Only aggregate integer counts and system telemetry.

class SystemSettingsModel {
  final bool isMaintenanceMode;
  final DateTime maintenanceUpdatedAt;
  final String? maintenanceUpdatedBy;
  final DateTime? schoolYearUpdatedAt;

  const SystemSettingsModel({
    required this.isMaintenanceMode,
    required this.maintenanceUpdatedAt,
    this.maintenanceUpdatedBy,
    this.schoolYearUpdatedAt,
  });

  factory SystemSettingsModel.fromJson(Map<String, dynamic> json) {
    return SystemSettingsModel(
      isMaintenanceMode: json['is_maintenance_mode'] == true,
      maintenanceUpdatedAt: json['maintenance_updated_at'] != null
          ? DateTime.tryParse(json['maintenance_updated_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      maintenanceUpdatedBy: json['maintenance_updated_by']?.toString(),
      schoolYearUpdatedAt: json['school_year_updated_at'] != null
          ? DateTime.tryParse(json['school_year_updated_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'is_maintenance_mode': isMaintenanceMode,
      'maintenance_updated_at': maintenanceUpdatedAt.toIso8601String(),
      'maintenance_updated_by': maintenanceUpdatedBy,
      if (schoolYearUpdatedAt != null)
        'school_year_updated_at': schoolYearUpdatedAt!.toIso8601String(),
    };
  }

  SystemSettingsModel copyWith({
    bool? isMaintenanceMode,
    DateTime? maintenanceUpdatedAt,
    String? maintenanceUpdatedBy,
    DateTime? schoolYearUpdatedAt,
  }) {
    return SystemSettingsModel(
      isMaintenanceMode: isMaintenanceMode ?? this.isMaintenanceMode,
      maintenanceUpdatedAt: maintenanceUpdatedAt ?? this.maintenanceUpdatedAt,
      maintenanceUpdatedBy: maintenanceUpdatedBy ?? this.maintenanceUpdatedBy,
      schoolYearUpdatedAt: schoolYearUpdatedAt ?? this.schoolYearUpdatedAt,
    );
  }
}

class UserSessionLog {
  final String id;
  final String userId;
  final String? teacherName;
  final String role;
  final DateTime sessionDate;
  final DateTime loginAt;
  final DateTime lastActiveAt;
  final DateTime? logoutAt;
  final String? logoutReason;
  final bool isActive;
  final int durationSeconds;

  const UserSessionLog({
    required this.id,
    required this.userId,
    this.teacherName,
    required this.role,
    required this.sessionDate,
    required this.loginAt,
    required this.lastActiveAt,
    this.logoutAt,
    this.logoutReason,
    required this.isActive,
    required this.durationSeconds,
  });

  DateTime get effectiveLogoutAt {
    if (logoutAt != null) {
      // Guard against erroneous logoutAt == loginAt when durationSeconds > 0
      if (logoutAt!.isAtSameMomentAs(loginAt) && durationSeconds > 0) {
        if (lastActiveAt.isAfter(loginAt)) return lastActiveAt;
        return loginAt.add(Duration(seconds: durationSeconds));
      }
      return logoutAt!;
    }
    if (!isActive && lastActiveAt.isAfter(loginAt)) {
      return lastActiveAt;
    }
    return loginAt.add(Duration(seconds: durationSeconds));
  }

  factory UserSessionLog.fromJson(Map<String, dynamic> json, {String? teacherName}) {
    final rawActive = json['is_active'] == true;
    final lastActive = json['last_active_at'] != null
        ? DateTime.tryParse(json['last_active_at'].toString())?.toLocal() ?? DateTime.now()
        : DateTime.now();

    // Heartbeat Staleness Guard:
    // If a session has had NO heartbeat recorded in the last 3 minutes,
    // the teacher has closed their browser or lost connection.
    final isStale = DateTime.now().difference(lastActive).inMinutes >= 3;
    final effectiveIsActive = rawActive && !isStale;

    final parsedLogout = json['logout_at'] != null
        ? DateTime.tryParse(json['logout_at'].toString())?.toLocal()
        : (!effectiveIsActive && rawActive ? lastActive : null);

    return UserSessionLog(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      teacherName: teacherName ?? json['teacher_name']?.toString(),
      role: json['role']?.toString() ?? '',
      sessionDate: json['session_date'] != null
          ? DateTime.tryParse(json['session_date'].toString())?.toLocal() ?? DateTime.now()
          : DateTime.now(),
      loginAt: json['login_at'] != null
          ? DateTime.tryParse(json['login_at'].toString())?.toLocal() ?? DateTime.now()
          : DateTime.now(),
      lastActiveAt: lastActive,
      logoutAt: parsedLogout,
      logoutReason: json['logout_reason']?.toString() ?? (!effectiveIsActive && rawActive ? 'terminated' : null),
      isActive: effectiveIsActive,
      durationSeconds: (json['duration_seconds'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'role': role,
      'session_date': sessionDate.toIso8601String().split('T').first,
      'login_at': loginAt.toIso8601String(),
      'last_active_at': lastActiveAt.toIso8601String(),
      'logout_at': logoutAt?.toIso8601String(),
      'logout_reason': logoutReason,
      'is_active': isActive,
      'duration_seconds': durationSeconds,
    };
  }

  UserSessionLog copyWith({
    String? id,
    String? userId,
    String? teacherName,
    String? role,
    DateTime? sessionDate,
    DateTime? loginAt,
    DateTime? lastActiveAt,
    DateTime? logoutAt,
    String? logoutReason,
    bool? isActive,
    int? durationSeconds,
  }) {
    return UserSessionLog(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      teacherName: teacherName ?? this.teacherName,
      role: role ?? this.role,
      sessionDate: sessionDate ?? this.sessionDate,
      loginAt: loginAt ?? this.loginAt,
      lastActiveAt: lastActiveAt ?? this.lastActiveAt,
      logoutAt: logoutAt ?? this.logoutAt,
      logoutReason: logoutReason ?? this.logoutReason,
      isActive: isActive ?? this.isActive,
      durationSeconds: durationSeconds ?? this.durationSeconds,
    );
  }

  String get formattedLogoutReason {
    if (isActive) return 'Online Now';
    switch (logoutReason) {
      case 'manual':
        return 'Manual Logout';
      case 'inactivity':
      case 'inactivity_timeout':
        return 'Inactivity';
      case 'terminated':
      case 'app_closed':
      case 'session_superseded':
      default:
        return 'Terminated';
    }
  }
}

class SchoolYearRecord {
  final String id;
  final String schoolYear;
  final bool isCurrent;
  final bool isArchived;
  final DateTime createdAt;

  const SchoolYearRecord({
    required this.id,
    required this.schoolYear,
    required this.isCurrent,
    required this.isArchived,
    required this.createdAt,
  });

  factory SchoolYearRecord.fromJson(Map<String, dynamic> json) {
    return SchoolYearRecord(
      id: json['id']?.toString() ?? '',
      schoolYear: json['school_year']?.toString() ?? '',
      isCurrent: json['is_current'] == true,
      isArchived: json['is_archived'] == true,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SchoolYearRecord && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}


class PreTransitionAuditResult {
  final int unfinalizedGradesCount;
  final int pendingSubmissionsCount;

  const PreTransitionAuditResult({
    required this.unfinalizedGradesCount,
    required this.pendingSubmissionsCount,
  });

  bool get hasPendingItems => unfinalizedGradesCount > 0 || pendingSubmissionsCount > 0;
}

class TeacherWorkloadSummary {
  final String teacherId;
  final String teacherName;
  final int totalSubjectsCount;
  final int totalSectionsCount;
  final bool isActiveNow;
  final int todayDurationSeconds;
  final int weekDurationSeconds;

  const TeacherWorkloadSummary({
    required this.teacherId,
    required this.teacherName,
    required this.totalSubjectsCount,
    required this.totalSectionsCount,
    required this.isActiveNow,
    required this.todayDurationSeconds,
    required this.weekDurationSeconds,
  });
}
