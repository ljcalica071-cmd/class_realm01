import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:class_realm/shared/widgets/buttons/app_buttons.dart';

class LegalDocumentSection {
  final String title;
  final String body;

  const LegalDocumentSection({required this.title, required this.body});
}

/// Shared, reusable In-App Legal Documents Modal for ClassRealm.
/// Displays identical Terms of Service and Privacy Policy (RA 10173 + Account Deletion)
/// across Login, Student Settings, Parent Settings, and Teacher Settings.
class LegalDocumentsModal {
  static const String institutionSubtitle =
      'Eduardo Barretto Senior Integrated School • Version 1.0.0 (SSHS Edition)';
  static const String privacySubtitle =
      'Republic Act No. 10173 (Data Privacy Act of 2012) & Account Deletion Policy';

  static const List<LegalDocumentSection> termsSections = [
    LegalDocumentSection(
      title: '1. Acceptance of Terms',
      body:
          'By accessing, downloading, installing, or using the ClassRealm mobile application or web portal ("System"), you acknowledge that you have read, understood, and agree to be bound by these Terms of Service and our Privacy Policy. ClassRealm is an Integrated Senior High School Academic Management System developed for Eduardo Barretto Senior Integrated School. If you do not agree to these terms, please discontinue use of the System immediately.',
    ),
    LegalDocumentSection(
      title: '2. Purpose and Scope of the System',
      body:
          'ClassRealm is provided exclusively for official educational, classroom management, attendance tracking, academic assessment, and parent-school communication purposes at Eduardo Barretto Senior Integrated School. The System supports four (4) authorized user portals: Administrator, Teacher, Student, and Parent/Guardian.',
    ),
    LegalDocumentSection(
      title: '3. User Accounts and Role Responsibilities',
      body:
          '• System Administrators: Responsible for managing teacher accounts, academic school year configurations, system-wide broadcasts, maintenance schedules, and overall platform security.\n'
          '• Teachers: Responsible for accurate encoding of class schedules, learning materials, assessments, attendance logs, and quarterly grades in accordance with Department of Education (DepEd) guidelines, and for safeguarding their login credentials.\n'
          '• Students: Responsible for maintaining academic honesty during online quizzes and examinations, submitting original classwork, keeping their login credentials confidential, and using only their personally assigned RFID card for attendance scanning.\n'
          '• Parents and Legal Guardians: Granted read-only monitoring access strictly to view their linked child\'s attendance records, class schedules, school announcements, teacher directory, and authorized academic grades.',
    ),
    LegalDocumentSection(
      title: '4. RFID Attendance and Hardware Usage',
      body:
          'Students issued a school RFID card must tap only their own card on the classroom ESP32 RFID scanner or authorized teacher NFC device. Tapping an RFID card on behalf of another student ("proxy attendance") or tampering with classroom scanning hardware is a disciplinary offense subject to school policies.',
    ),
    LegalDocumentSection(
      title: '5. Academic Integrity and Anti-Cheating Monitoring',
      body:
          'During digital quizzes and examinations, ClassRealm enforces automated anti-cheating safeguards. The System detects and logs focus loss, tab switching, app backgrounding, screen splits, and unauthorized copy/paste attempts ("suspicious session events"). Real-time alerts are transmitted to the proctoring teacher, who may issue warnings, lock the assessment, or require a supervised retake. Any attempt to bypass or manipulate these proctoring mechanisms is strictly prohibited.',
    ),
    LegalDocumentSection(
      title: '6. Adult Student Grade Privacy (18 Years Old and Above)',
      body:
          'In compliance with Republic Act No. 10173 (Data Privacy Act of 2012), students who are eighteen (18) years of age or older are recognized as legal adults and may configure whether their Quarterly Term Grades and Final Grades are visible to linked Parent/Guardian accounts via their Settings screen. Attendance records, class schedules, and school alerts remain accessible to linked parents/guardians for student safety and school monitoring.',
    ),
    LegalDocumentSection(
      title: '7. Acceptable Use and Prohibited Conduct',
      body:
          'Users agree not to:\n'
          '• Share passwords, One-Time Passwords (OTPs), or active sessions with any other person;\n'
          '• Attempt to access accounts, portals, or student records for which they are not authorized;\n'
          '• Upload malicious files, inappropriate content, or unauthorized third-party materials;\n'
          '• Disrupt, overload, or reverse-engineer the System\'s servers, local databases, or authentication services.\n'
          'Multiple failed login or verification attempts will trigger automated progressive device and account lockouts for security protection.',
    ),
    LegalDocumentSection(
      title: '8. Offline-First Architecture and Data Synchronization',
      body:
          'ClassRealm uses an offline-first architecture. Certain academic and attendance actions may be temporarily stored on your device\'s encrypted local database when internet connectivity is unavailable and will automatically synchronize with the school\'s cloud database once a stable connection is restored. Users are responsible for connecting to the internet periodically to ensure their records are fully synchronized.',
    ),
    LegalDocumentSection(
      title: '9. System Maintenance and Availability',
      body:
          'The System Administrator may schedule temporary maintenance windows or emergency broadcasts. During active maintenance, non-administrator users may be temporarily logged out while pending offline data remains preserved on the device.',
    ),
    LegalDocumentSection(
      title: '10. Limitation of Liability and Amendments',
      body:
          'ClassRealm is provided on an "as-is" and "as-available" basis for academic pilot and institutional deployment. Eduardo Barretto Senior Integrated School and the ClassRealm Capstone Development Team shall not be liable for delays, grade synchronization delays caused by lack of user internet connectivity, or unauthorized access resulting from a user\'s failure to protect their credentials. These Terms may be updated periodically to reflect school policy or regulatory changes.',
    ),
  ];

  static const List<LegalDocumentSection> privacySections = [
    LegalDocumentSection(
      title: '1. Introduction',
      body:
          'ClassRealm ("we," "our," or "the System") is committed to protecting the privacy, confidentiality, and security of personal and academic information of all students, parents/guardians, teachers, and administrators at Eduardo Barretto Senior Integrated School. This Privacy Policy explains what information we collect, how we process and store it, and how users may exercise their rights—including account and data deletion—in strict compliance with Republic Act No. 10173, otherwise known as the Data Privacy Act of 2012, and its Implementing Rules and Regulations.',
    ),
    LegalDocumentSection(
      title: '2. Information We Collect',
      body:
          'We collect only the minimum personal, academic, and technical data necessary to deliver academic management services:\n'
          '• Students: Full Name, Learner Reference Number (LRN), School/Personal Email Address, Date of Birth, Gender, Grade Level, and Section.\n'
          '• Parents/Guardians: Full Name, Email Address, Contact/Mobile Number, Relationship to the linked student(s), and linked Student LRN(s).\n'
          '• Teachers & Administrators: Full Name, Email Address, Contact Number, Subject Specialization, Consultation Hours, and optional public directory links.\n'
          '• RFID and Attendance Data: Assigned RFID Card Unique Identifier (UID), daily time-in/time-out scan timestamps, attendance status (Present, Late, Absent, Excused), and scanner device logs captured via classroom ESP32 RFID readers or teacher NFC devices.\n'
          '• Academic and Classwork Data: Written Works (WW), Performance Tasks (PT), Quarterly Examination (EX) scores, uploaded activity submissions/files, computed initial and transmuted grades (Strengthened Senior High School Curriculum under DepEd Order No. 15, s. 2026), and teacher feedback.\n'
          '• Assessment Integrity Telemetry: During active online quizzes and exams only, the System logs app lifecycle changes (tab switches, window minimize/focus loss, and copy attempts) to uphold examination integrity. ClassRealm does NOT record camera video, microphone audio, personal photos, contacts, or GPS location.\n'
          '• Device Security Metadata: Anonymous device installation identifiers, login timestamps, and failed authentication counters used solely to prevent brute-force attacks and unauthorized account access.',
    ),
    LegalDocumentSection(
      title: '3. How We Use Your Information',
      body:
          'Your data is processed strictly for legitimate educational and institutional purposes:\n'
          '• Authenticating user identity and providing role-based access to the Admin, Teacher, Student, and Parent portals;\n'
          '• Recording, computing, and reporting daily attendance (including DepEd School Form 2 exports) and quarterly academic grades;\n'
          '• Delivering real-time attendance, grade, and school broadcast notifications to students and linked parents/guardians;\n'
          '• Sending One-Time Passwords (OTPs), account verification codes, and security alerts via email;\n'
          '• Maintaining examination integrity during digital assessments and auditing system security.\n'
          'We do NOT sell, rent, trade, or use student or parent personal data for commercial advertising or third-party marketing.',
    ),
    LegalDocumentSection(
      title: '4. Offline-First Local Storage and Cloud Synchronization',
      body:
          'ClassRealm operates on an offline-first architecture using a local SQLite (Drift) database on your device paired with secure cloud synchronization. When you use the app offline, academic and attendance records are cached locally on your device and automatically transmitted over encrypted HTTPS/TLS connections to our cloud database once internet connectivity is restored. Logging out of your account clears active session tokens on the device.',
    ),
    LegalDocumentSection(
      title: '5. Third-Party Infrastructure and Service Providers',
      body:
          'To ensure enterprise-grade reliability and security, ClassRealm utilizes trusted cloud service providers that process data strictly on our behalf:\n'
          '• Google Firebase Authentication: For secure password authentication, session token management, and account security.\n'
          '• Supabase (PostgreSQL Cloud Database & Storage): For encrypted cloud storage of academic records, attendance logs, and learning materials with Row-Level Security (RLS).\n'
          '• Google Gemini AI (Teacher Portal Only): Used by teachers to assist in generating DepEd-aligned lesson plan drafts. Student personal identities (names, LRNs, emails) are never sent to AI models.',
    ),
    LegalDocumentSection(
      title: '6. Data Sharing, Visibility, and 18+ Student Privacy Rights',
      body:
          '• Access to student data is strictly restricted to the student, their assigned subject teachers, class adviser, authorized school administrators, and verified linked parents/guardians.\n'
          '• Under RA 10173, students aged 18 and above may restrict parent/guardian visibility of their Term Grades and Final Grades through the "Parent / Guardian Privacy Controls" in Student Settings.',
    ),
    LegalDocumentSection(
      title: '7. Data Security Measures',
      body:
          'We implement organizational, physical, and technical security measures including HTTPS/TLS encryption in transit, salted password hashing, Row-Level Security (RLS) database policies, role-based access controls, OTP verification for sensitive actions, and progressive rate-limiting against unauthorized login attempts.',
    ),
    LegalDocumentSection(
      title: '8. Data Retention Policy',
      body:
          'Personal and academic records are retained only for the duration of the active Academic School Year and the retention period required by Department of Education (DepEd) school record-keeping guidelines. Inactive or graduated accounts are archived and purged in accordance with school administration schedules.',
    ),
    LegalDocumentSection(
      title:
          '9. Account and Data Deletion Policy (Google Play & RA 10173 Compliance)',
      body:
          'Users (Students, Parents/Guardians, and Teachers) have the right to request the deletion of their ClassRealm user account and associated personal data at any time:\n'
          '• In-School Request: Submit a request directly to your Class Adviser (for Students and Parents) or the School System Administrator at Eduardo Barretto Senior Integrated School.\n'
          '• Email Request: Send an email with the subject line "ClassRealm Account Deletion Request" to the ClassRealm System Administrator / Support Team using your registered email address, stating your Full Name, User Role (Student/Parent/Teacher), and registered Email or LRN.\n'
          '• Verification & Timeline: To protect against unauthorized deletion, the Administrator or Adviser will verify the requester\'s identity and process the account deletion within seven (7) to fourteen (14) school days.\n'
          '• Deleted vs. Retained Records: Upon approval, your Firebase Authentication credentials, login profile, device tokens, and personal portal access are permanently deleted. Official academic grades and attendance records required by the Department of Education (DepEd) as part of official school registries remain under the custody of Eduardo Barretto Senior Integrated School until the end of the mandatory DepEd retention period.',
    ),
    LegalDocumentSection(
      title: '10. Your Rights Under the Data Privacy Act of 2012 (RA 10173)',
      body:
          'As a data subject under Philippine law, you have the right to be informed, the right to access your personal data, the right to object, the right to rectification of inaccurate records, the right to erasure or blocking, and the right to data portability.',
    ),
    LegalDocumentSection(
      title: '11. Contact Information',
      body:
          'For privacy inquiries, data correction requests, or account deletion requests, please coordinate with:\n'
          '• Data Protection / System Administrator: ClassRealm Capstone Team & School Administration\n'
          '• Institution: Eduardo Barretto Senior Integrated School (Calamba City, Laguna)\n'
          '• Contact Channel: Your Class Adviser, School ICT Coordinator, or the official ClassRealm Administrator office at Eduardo Barretto Senior Integrated School.',
    ),
  ];

  static Future<void> showTermsOfService(BuildContext context) {
    return _showDocumentDialog(
      context: context,
      title: 'Terms of Service',
      subtitle: institutionSubtitle,
      introBanner:
          'Please read these Terms of Service carefully before using the ClassRealm Academic Management System.',
      sections: termsSections,
    );
  }

  static Future<void> showPrivacyPolicy(BuildContext context) {
    return _showDocumentDialog(
      context: context,
      title: 'Privacy Policy',
      subtitle: privacySubtitle,
      introBanner:
          'We protect your personal and academic information in strict compliance with the Philippine Data Privacy Act of 2012 (RA 10173).',
      sections: privacySections,
    );
  }

  static Future<void> _showDocumentDialog({
    required BuildContext context,
    required String title,
    required String subtitle,
    required String introBanner,
    required List<LegalDocumentSection> sections,
  }) {
    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close',
      barrierColor: Colors.black.withValues(alpha: 0.55),
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        final theme = Theme.of(dialogContext);
        final isDark = theme.brightness == Brightness.dark;
        final size = MediaQuery.sizeOf(dialogContext);
        final dialogWidth = (size.width - 32).clamp(320.0, 620.0);
        final dialogMaxHeight = size.height * 0.84;

        final bgColor = isDark ? theme.colorScheme.surface : Colors.white;
        final borderColor = isDark
            ? theme.colorScheme.onSurface.withValues(alpha: 0.14)
            : const Color(0xFFE2E8F0);
        final headingColor = isDark
            ? theme.colorScheme.onSurface
            : const Color(0xFF0F172A);
        final bodyColor = isDark
            ? theme.colorScheme.onSurface.withValues(alpha: 0.78)
            : const Color(0xFF475569);
        final accentColor = isDark
            ? theme.colorScheme.primary
            : const Color(0xFF2563EB);

        return Center(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
            child: Material(
              color: Colors.transparent,
              child: Container(
                width: dialogWidth,
                constraints: BoxConstraints(maxHeight: dialogMaxHeight),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: borderColor, width: 1.5),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x260F172A),
                      blurRadius: 32,
                      offset: Offset(0, 12),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 20, 16, 16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: accentColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.verified_user_outlined,
                              color: accentColor,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 19,
                                    color: headingColor,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  subtitle,
                                  style: TextStyle(
                                    color: accentColor,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 11.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.close_rounded,
                              size: 20,
                              color: bodyColor,
                            ),
                            onPressed: () => Navigator.of(dialogContext).pop(),
                            tooltip: 'Close',
                            style: IconButton.styleFrom(
                              backgroundColor: isDark
                                  ? theme.colorScheme.onSurface.withValues(
                                      alpha: 0.08,
                                    )
                                  : const Color(0xFFF1F5F9),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Divider(height: 1, thickness: 1, color: borderColor),

                    // Scrollable Content
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(14),
                              margin: const EdgeInsets.only(bottom: 18),
                              decoration: BoxDecoration(
                                color: accentColor.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: accentColor.withValues(alpha: 0.22),
                                ),
                              ),
                              child: Text(
                                introBanner,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  height: 1.5,
                                  fontWeight: FontWeight.w600,
                                  color: headingColor,
                                ),
                              ),
                            ),
                            ...sections.map(
                              (section) => Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      section.title,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                        color: headingColor,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      section.body,
                                      textAlign: TextAlign.justify,
                                      style: TextStyle(
                                        fontSize: 13,
                                        height: 1.55,
                                        color: bodyColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Footer
                    Divider(height: 1, thickness: 1, color: borderColor),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 14, 24, 18),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: AppButton.primary(
                          label: 'I Understand',
                          onPressed: () => Navigator.of(dialogContext).pop(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curve = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        return FadeTransition(
          opacity: curve,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.95, end: 1.0).animate(curve),
            child: child,
          ),
        );
      },
    );
  }
}
