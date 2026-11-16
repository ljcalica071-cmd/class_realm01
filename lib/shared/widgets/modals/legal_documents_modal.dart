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
      'Eduardo Barretto Senior Integrated School • Version 2.0.0 (SSHS Edition)\nEffective Date: November 2026';
  static const String privacySubtitle =
      'Republic Act No. 10173 (Data Privacy Act of 2012) & Account Deletion Policy\nEduardo Barretto Senior Integrated School • Version 2.0.0 (SSHS Edition)';

  static const List<LegalDocumentSection> termsSections = [
    LegalDocumentSection(
      title: '1. Acceptance of Terms',
      body:
          'By accessing, downloading, installing, registering an account on, or interacting with the ClassRealm mobile application, Progressive Web Application (PWA), or associated school web portals (collectively referred to as the "System"), you explicitly acknowledge that you have read, understood, and agreed to be legally bound by these Terms of Service in conjunction with the ClassRealm Privacy Policy.\n\n'
          'ClassRealm is an Integrated Senior High School Academic Management, Attendance Tracking, Performance Analytics, and Learning Portal engineered specifically for Eduardo Barretto Senior Integrated School. These Terms constitute a binding institutional agreement between all active end-users (Administrators, Teachers, Students, and Parents/Legal Guardians) and the educational administration. If you do not consent to, understand, or agree with any stipulation set forth in these Terms, you must immediately discontinue use of the System, uninstall the application from your devices, and notify your Class Adviser or School ICT Coordinator.',
    ),
    LegalDocumentSection(
      title: '2. Purpose, Institutional Scope, and Intended Use',
      body:
          'ClassRealm is deployed strictly and exclusively for legitimate educational, classroom administration, academic performance evaluation, institutional communication, and campus security purposes within Eduardo Barretto Senior Integrated School.\n\n'
          'The System supports four (4) distinct role-based access tiers:\n'
          '• School Administrator Portal: Enterprise-level management of school year terms, academic calendars, teacher onboarding, centralized emergency announcements, system audit monitoring, and platform operational health.\n'
          '• Teacher Portal: Encoding, computing, and releasing official learner grades, managing classroom attendance sessions, reviewing real-time Performance Analytics and rankings, authoring digital assessments, publishing learning modules, and conducting live anti-cheating supervision.\n'
          '• Student Portal: Reviewing personalized class schedules, accessing learning materials, submitting classwork activities and attachments, taking proctored assessments, monitoring attendance scan records, and tracking quarterly academic progress.\n'
          '• Parent and Guardian Portal: Read-only monitoring of their linked child\'s daily campus attendance, official announcements, teacher directory, and authorized academic grades.\n\n'
          'Commercial exploitation, external advertising, unauthorized third-party integrations, and any utilization outside sanctioned school operations are strictly prohibited.',
    ),
    LegalDocumentSection(
      title:
          '3. User Accounts, Access Credentials, Email Integrity, and Role Responsibilities',
      body:
          'Access to ClassRealm is restricted to verified members of the Eduardo Barretto Senior Integrated School community. All users are personally responsible for upholding the confidentiality of their credentials and adhering to their assigned roles:\n\n'
          '• Valid Email & Identity Integrity: Users must register and maintain an active, accessible, and legitimate email address. Disposable, temporary, or fabricated email addresses are strictly prohibited and automatically rejected by the System to ensure reliable One-Time Password (OTP) delivery, account verification, and official school communication.\n'
          '• Single-Session Protection: To safeguard student and faculty accounts from unauthorized sharing, the System monitors active login sessions and alerts users if conflicting or simultaneous access is detected on multiple devices.\n'
          '• System Administrators: Obligated to enforce institutional data protection standards, manage teacher access permissions, safeguard master administrative controls, schedule non-disruptive maintenance windows, and ensure prompt response to data privacy inquiries.\n'
          '• Teachers: Must ensure prompt, objective, and accurate recording of attendance, learning outputs, and quarterly grades adhering strictly to Department of Education (DepEd) standards under the Strengthened Senior High School Curriculum (DepEd Order No. 15, s. 2026). Teachers must never share their portal credentials or grant unverified individuals access to student records.\n'
          '• Students: Expected to demonstrate unwavering academic honesty during examinations, submit their own original classwork, maintain the security of their login credentials, and use only their personally issued RFID card for campus gate and classroom attendance.\n'
          '• Parents and Legal Guardians: Granted non-editable, read-only monitoring access to foster active parental guidance. Parents agree to utilize the portal solely for supporting their child\'s academic growth and must refrain from attempting to alter records, compromise other student accounts, or impersonate their child during online assessments.',
    ),
    LegalDocumentSection(
      title:
          '4. RFID Card Attendance, Scanner Terminals, and Anti-Proxy Regulations',
      body:
          'ClassRealm utilizes an integrated attendance system combining physical school RFID scanning terminals with optional teacher NFC verification devices:\n\n'
          '• Physical Card Possession: Every student is issued an individual school RFID card linked to their unique Learner Reference Number (LRN). The card remains the student\'s personal responsibility throughout the academic school year.\n'
          '• Tap Execution: Students must tap only their own card upon arriving at and departing from designated school scanning terminals. Tapping on behalf of an absent or late classmate ("proxy attendance") constitutes a severe breach of school discipline and will result in disciplinary action under the EBSIS Student Code of Conduct.\n'
          '• Hardware Tampering: Any attempt to physically damage, disconnect, tamper with, clone, emulate via unauthorized wireless transmitters, or manipulate classroom attendance readers or school network infrastructure is strictly prohibited and subject to immediate administrative sanctions and disciplinary review.',
    ),
    LegalDocumentSection(
      title:
          '5. Academic Integrity and Real-Time Anti-Cheating Proctoring Safeguards',
      body:
          'To preserve academic credibility and fair assessment standards during digital quizzes, long tests, and quarterly examinations, ClassRealm deploys an automated real-time proctoring safeguard:\n\n'
          '• Activity and Focus Monitoring: During active assessment sessions, the System monitors and records application focus events. This includes detecting tab switches, browser focus loss, window minimization, split-screen multi-tasking, backgrounding the application, and unauthorized copy/paste attempts ("suspicious session events").\n'
          '• Proctor Alerts and Automated Enforcement: Detected anomalies are transmitted in real time to the proctoring teacher\'s monitoring console. Based on the frequency and severity of detected anomalies, the teacher or the System may automatically issue on-screen warnings, temporarily lock the assessment session, deduct score points, or terminate the student\'s exam attempt, requiring a formal supervised retake.\n'
          '• Strict Privacy Guarantee: ClassRealm does NOT record camera feeds, microphone audio, screen video recordings, browser history outside the assessment page, personal photo files, or device GPS locations. The monitoring safeguard is operational strictly while an assessment attempt is in progress.',
    ),
    LegalDocumentSection(
      title: '6. Adult Student Grade Privacy Rights (18 Years Old and Above)',
      body:
          'In strict compliance with the Philippine Data Privacy Act of 2012 (Republic Act No. 10173), students who have reached the age of majority (eighteen [18] years old and above) possess independent statutory privacy rights over their sensitive educational records:\n\n'
          '• Privacy Controls: Adult learners are provided with configurable "Parent / Guardian Privacy Controls" within their Student Settings screen, allowing them to enable or restrict parent/guardian visibility over their Quarterly Term Grades and Final Computed Grades.\n'
          '• Non-Restricted Safety Records: Daily campus attendance timestamps, emergency broadcast notifications, class schedules, and institutional announcements remain continuously accessible to linked parents/guardians regardless of the student\'s age, in accordance with the school\'s duty of care, campus safety policies, and institutional parental communication guidelines.',
    ),
    LegalDocumentSection(
      title: '7. Acceptable Use, System Security, and Prohibited Activities',
      body:
          'Users must utilize ClassRealm in an ethical, lawful, and constructive manner. The following actions are strictly forbidden:\n\n'
          '• Credential Sharing: Disclosing, transferring, selling, or lending user passwords, One-Time Passwords (OTPs), or active session access to any other party.\n'
          '• Unauthorized Access: Attempting to bypass role-based security boundaries, gain unauthorized administrative access, escalate user privileges, or view academic and personal records of unassigned students.\n'
          '• Malicious Uploads: Uploading files containing viruses, malicious scripts, corrupted executables, offensive media, or copyrighted materials without proper authorization.\n'
          '• Infrastructure Disruption: Attempting to overload school servers, automate mass login attempts, manipulate client application files, or disrupt the normal operation of the portal for other students and teachers.\n\n'
          'To protect institutional data integrity, ClassRealm implements automated rate-limiting, temporary session lockouts, and persistent security logging against offending activities.',
    ),
    LegalDocumentSection(
      title:
          '8. Offline Functionality, Local Caching, and Synchronization Responsibilities',
      body:
          'ClassRealm is designed to support reliable mobile operation even in areas with intermittent or unstable campus internet connectivity:\n\n'
          '• Local Data Caching: Attendance scans, draft grading sheets, and learner progress updates may be temporarily stored in secure local storage on the authorized device while offline.\n'
          '• Automatic Synchronization: Cached records are automatically queued and synchronized with the official school system as soon as a verified internet connection is re-established.\n'
          '• User Responsibility: Teachers and students are responsible for periodically connecting their mobile devices or laptops to the internet to ensure pending updates are synchronized prior to official school deadlines. The school cannot be held liable for delayed report generation or missing grade submissions arising from prolonged offline usage without synchronization.',
    ),
    LegalDocumentSection(
      title: '9. Scheduled Maintenance, System Updates, and Emergency Broadcasts',
      body:
          'To preserve optimal performance, platform stability, and software security, the school administration reserves the right to perform routine and emergency platform updates:\n\n'
          '• Maintenance Windows: Scheduled maintenance, system optimizations, and version upgrades will be announced in advance through in-app notification banners. Non-administrative users may be temporarily restricted from logging in during active maintenance windows.\n'
          '• Data Preservation: Synchronized records remain safely preserved during server maintenance.\n'
          '• Emergency Broadcasts: In cases of severe weather, campus emergencies, or administrative school suspensions, System Administrators may dispatch priority alert banners that override regular notification preferences to ensure immediate campus-wide awareness.',
    ),
    LegalDocumentSection(
      title: '10. Limitation of Liability, Institutional Disclaimer, and Amendments',
      body:
          'ClassRealm is provided to students, parents, and educators on an "as-is" and "as-available" basis for institutional deployment and operational school management:\n\n'
          '• Liability Disclaimer: To the fullest extent permitted by Philippine law, Eduardo Barretto Senior Integrated School, its administrators, and faculty members shall not be held liable for any indirect, incidental, or consequential damages resulting from lost internet access, device incompatibilities, user failure to safeguard credentials, or unapproved hardware usage.\n'
          '• Amendments: The school administration reserves the right to modify, refine, or update these Terms of Service periodically to reflect evolving Department of Education directives, statutory legal revisions, or institutional school policies. Continued use of the System after amendments are published constitutes full acceptance of the revised Terms.',
    ),
  ];

  static const List<LegalDocumentSection> privacySections = [
    LegalDocumentSection(
      title: '1. Introduction',
      body:
          'ClassRealm ("we," "our," or "the System") is committed to protecting the privacy, confidentiality, and security of personal and academic information of all students, parents/guardians, teachers, and administrators at Eduardo Barretto Senior Integrated School (EBSIS). This Privacy Policy explains what information we collect, how we process, analyze, and store it, and how users may exercise their rights—including account and data deletion—in strict compliance with Republic Act No. 10173, otherwise known as the Data Privacy Act of 2012, and its Implementing Rules and Regulations.',
    ),
    LegalDocumentSection(
      title: '2. Information We Collect',
      body:
          'We collect only the minimum personal, academic, and security data necessary to deliver official school management and learning services:\n\n'
          '• Students: Full Name, Learner Reference Number (LRN), Verified Personal or School Email Address, Date of Birth, Gender, Grade Level, and Section.\n'
          '• Parents/Guardians: Full Name, Verified Email Address, Contact/Mobile Number, Relationship to the linked student(s), and linked Student LRN(s).\n'
          '• Teachers & Administrators: Full Name, Email Address, Contact Number, Subject Specialization, Consultation Hours, and optional public faculty directory information.\n'
          '• RFID and Attendance Data: Assigned School RFID Card Identifier, daily time-in/time-out scan timestamps, attendance status (Present, Late, Absent, Excused), and campus/classroom attendance scanner records.\n'
          '• Academic, Classwork, and Performance Analytics Data: Written Works (WW), Performance Tasks (PT), Quarterly Examination (EX) scores, uploaded activity submissions and files, computed initial and transmuted grades (under DepEd Order No. 15, s. 2026), class rankings, learning trajectory indicators, and teacher feedback.\n'
          '• Assessment Integrity Telemetry: During active online quizzes and exams only, the System logs application focus changes (tab switches, window minimize or focus loss, and copy attempts) to uphold examination integrity. ClassRealm does NOT record camera video, microphone audio, personal photos, contacts, or device GPS location.\n'
          '• Account & Session Security Metadata: Device session identifiers, login timestamps, email verification records, and failed authentication counters used solely to prevent unauthorized account access and ensure single-session safety.',
    ),
    LegalDocumentSection(
      title: '3. How We Use Your Information',
      body:
          'Your data is processed strictly for legitimate educational, institutional, and campus safety purposes:\n'
          '• Authenticating user identity and providing secure role-based access to the Admin, Teacher, Student, and Parent portals;\n'
          '• Recording, computing, and reporting daily attendance (including DepEd School Form 2 exports) and quarterly academic grades;\n'
          '• Generating real-time Performance Analytics to help teachers identify learners who are advancing or who need academic support;\n'
          '• Delivering real-time attendance warnings, grade releases, and official school broadcast notifications to students and linked parents/guardians;\n'
          '• Sending One-Time Passwords (OTPs), account verification codes, and security alerts via email;\n'
          '• Maintaining examination integrity during digital assessments and protecting portal security.\n\n'
          'We do NOT sell, rent, trade, or use student, parent, or teacher personal data for commercial advertising or third-party marketing.',
    ),
    LegalDocumentSection(
      title: '4. Secure Local Device Storage and Cloud Synchronization',
      body:
          'When using the mobile application in areas with weak or intermittent internet connectivity, ClassRealm temporarily stores essential academic and attendance records in secure local storage on your device. Once an internet connection is restored, these records are transmitted over encrypted HTTPS/TLS connections to our secure school cloud system. Logging out of your account immediately clears active session tokens from your device.',
    ),
    LegalDocumentSection(
      title: '5. Authorized Infrastructure & Data Processing Partners',
      body:
          'To ensure reliable, high-availability service for the school community, ClassRealm utilizes trusted enterprise cloud infrastructure for encrypted authentication, database hosting, file storage, and email verification delivery. These services process data strictly on behalf of Eduardo Barretto Senior Integrated School under strict confidentiality and security agreements. Student personal identities (names, LRNs, emails, and grades) are never shared with external marketing entities or unauthorized third parties.',
    ),
    LegalDocumentSection(
      title: '6. Data Sharing, Visibility, and 18+ Student Privacy Rights',
      body:
          '• Strict Access Control: Access to student data is strictly restricted to the student themselves, their assigned subject teachers, class adviser, authorized school administrators, and verified linked parents/guardians.\n'
          '• Adult Student Privacy Rights (18+): Under Republic Act No. 10173, students who have reached eighteen (18) years of age and above may independently enable or restrict parent/guardian visibility of their Quarterly Term Grades and Final Grades through the "Parent / Guardian Privacy Controls" in Student Settings. Daily campus attendance and emergency safety notifications remain visible to linked parents/guardians for campus safety.',
    ),
    LegalDocumentSection(
      title: '7. Data Security Measures',
      body:
          'We implement organizational, physical, and technical safeguards to protect your records against unauthorized access, alteration, or loss. These include encrypted HTTPS/TLS data transmission, secure salted password hashing, strict role-based access restrictions, One-Time Password (OTP) verification for sensitive changes, single-session login protection, and automated rate-limiting against unauthorized login attempts.',
    ),
    LegalDocumentSection(
      title: '8. Data Retention Policy',
      body:
          'Personal and academic records are retained only for the duration of the active Academic School Year and for the mandatory retention period required by Department of Education (DepEd) school record-keeping regulations. Inactive or graduated accounts are archived and purged in accordance with official school administration schedules.',
    ),
    LegalDocumentSection(
      title:
          '9. Account and Data Deletion Policy (Google Play & RA 10173 Compliance)',
      body:
          'Users (Students, Parents/Guardians, and Teachers) have the right to request the deletion of their ClassRealm user account and associated personal portal data at any time:\n\n'
          '• In-School Request: Submit a request directly to your Class Adviser (for Students and Parents) or to the School System Administrator / ICT Coordinator at Eduardo Barretto Senior Integrated School.\n'
          '• Email Request: Send an email with the subject line "ClassRealm Account Deletion Request" to the ClassRealm System Administrator / Support Team using your registered email address, stating your Full Name, User Role (Student, Parent, or Teacher), and registered Email or LRN.\n'
          '• Verification & Timeline: To protect against unauthorized deletion, the Administrator or Adviser will verify the requester\'s identity and process the account deletion within seven (7) to fourteen (14) school days.\n'
          '• Deleted vs. Retained Records: Upon approval, your login credentials, portal profile, device session tokens, and personal app access are permanently deleted. Official academic grades and attendance records required by the Department of Education (DepEd) as part of official school registries remain under the custody of Eduardo Barretto Senior Integrated School until the end of the mandatory DepEd retention period.',
    ),
    LegalDocumentSection(
      title: '10. Your Rights Under the Data Privacy Act of 2012 (RA 10173)',
      body:
          'As a data subject under Philippine law, you are entitled to the following rights:\n'
          '• Right to be Informed: To know how your personal data is collected and used.\n'
          '• Right to Access: To request reasonable access to your personal and academic records stored in the System.\n'
          '• Right to Rectification: To dispute and request correction of any inaccurate, outdated, or incomplete personal information.\n'
          '• Right to Object & Erasure/Blocking: To object to unauthorized processing or request deletion of personal data, subject to mandatory DepEd record-keeping laws.\n'
          '• Right to Data Portability: To request a structured copy of your academic records in accordance with school guidelines.',
    ),
    LegalDocumentSection(
      title: '11. Contact Information',
      body:
          'For privacy inquiries, data correction requests, or account deletion requests, please coordinate with:\n'
          '• Data Protection / Support Team: ClassRealm Development Team\n'
          '• Institution: Eduardo Barretto Senior Integrated School (Calamba City, Laguna)\n'
          '• Contact Channel: Your Class Adviser, or the official ClassRealm Development Team.',
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
