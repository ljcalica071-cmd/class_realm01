import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:class_realm/models/user_model.dart';
import 'package:class_realm/data/mock_database.dart';

class SupabaseParentRepository {
  final SupabaseClient _client;

  SupabaseParentRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  AccountStatus _parseParentStatus(String? status, {required bool isArchived}) {
    if (isArchived) return AccountStatus.archived;
    switch (status?.toLowerCase().replaceAll(RegExp(r'[\s_-]'), '')) {
      case 'pending':
      case 'pendingfirstlogin':
        return AccountStatus.pendingFirstLogin;
      case 'rejected':
        return AccountStatus.rejected;
      case 'inactive':
      case 'deactivated':
        return AccountStatus.deactivated;
      case 'archived':
        return AccountStatus.archived;
      default:
        return AccountStatus.active;
    }
  }

  Future<List<UserModel>> getParentsForTeacher(
    String teacherId, {
    String? subjectId,
    bool includeArchived = false,
  }) async {
    try {
      // 1. First get all students enrolled under this teacher
      var enrollmentQuery = _client
          .from('student_enrollments')
          .select('''
            student_id,
            student_profiles!inner ( 
              student_id, lrn, first_name, middle_name, last_name, birthday, gender
            ),
            subject_offerings!inner ( 
              id, teacher_id,
              subjects ( id, subject_name ),
              sections ( id, section_name )
            )
          ''')
          .eq('subject_offerings.teacher_id', teacherId);

      if (subjectId != null) {
        enrollmentQuery = enrollmentQuery.eq('subject_offerings.id', subjectId);
      }

      final enrollments = await enrollmentQuery;
      if (enrollments == null || (enrollments as List).isEmpty) {
        return [];
      }

      final studentMap = <String, Map<String, dynamic>>{};
      for (final row in enrollments as List) {
        final stProfile =
            row['student_profiles'] as Map<String, dynamic>? ?? {};
        final offering =
            row['subject_offerings'] as Map<String, dynamic>? ?? {};
        final sub = offering['subjects'] as Map<String, dynamic>? ?? {};
        final sec = offering['sections'] as Map<String, dynamic>? ?? {};
        final studentId =
            stProfile['student_id']?.toString() ??
            row['student_id']?.toString();

        if (studentId != null) {
          final studentFullName = [
            stProfile['first_name'],
            stProfile['middle_name'],
            stProfile['last_name'],
          ].where((n) => n != null && n.toString().trim().isNotEmpty).join(' ');

          studentMap[studentId] = {
            'fullName': studentFullName,
            'lrn': stProfile['lrn']?.toString(),
            'section': sec['section_name']?.toString(),
            'subject': sub['subject_name']?.toString(),
            'subjectId': sub['id']?.toString() ?? offering['id']?.toString(),
          };
        }
      }

      final studentIds = studentMap.keys.toList();
      if (studentIds.isEmpty) return [];

      // 2. Fetch parent links for these student IDs
      final linksResponse = await _client
          .from('parent_student_links')
          .select('''
            parent_id,
            student_id,
            relationship,
            parent_profiles!inner (
              parent_id,
              first_name,
              middle_name,
              last_name,
              contact_number,
              birthday,
              status
            )
          ''')
          .filter('student_id', 'in', studentIds);

      if (linksResponse == null || (linksResponse as List).isEmpty) {
        return [];
      }

      // 3. Fetch user archive status
      final parentIds = (linksResponse as List)
          .map((row) => row['parent_id']?.toString())
          .whereType<String>()
          .toSet()
          .toList();

      final usersResponse = await _client
          .from('users')
          .select('id, email, is_archived')
          .filter('id', 'in', parentIds);

      final userStatusMap = <String, Map<String, dynamic>>{};
      if (usersResponse != null) {
        for (final u in usersResponse as List) {
          userStatusMap[u['id'].toString()] = {
            'is_archived': u['is_archived'] == true,
            'email': u['email']?.toString(),
          };
        }
      }

      final parentGroupMap = <String, Map<String, dynamic>>{};

      for (final row in linksResponse as List) {
        final profile = row['parent_profiles'] as Map<String, dynamic>? ?? {};
        final parentId = row['parent_id']?.toString() ?? '';
        final linkedStudentId = row['student_id']?.toString();
        final studentInfo = studentMap[linkedStudentId] ?? {};

        final userInfo = userStatusMap[parentId] ?? {};
        final isArchived = userInfo['is_archived'] == true;

        if (!includeArchived && isArchived) continue;
        if (includeArchived && !isArchived) continue;

        final studentName =
            studentInfo['fullName']?.toString() ?? 'Enrolled Student';
        final sectionName = studentInfo['section']?.toString() ?? '';

        if (!parentGroupMap.containsKey(parentId)) {
          final fullName = [
            profile['first_name'],
            profile['middle_name'],
            profile['last_name'],
          ].where((n) => n != null && n.toString().trim().isNotEmpty).join(' ');

          final contactNumber = profile['contact_number']?.toString() ?? '';
          final username = contactNumber.isNotEmpty ? contactNumber : parentId;

          parentGroupMap[parentId] = {
            'id': parentId,
            'username': username,
            'email':
                userInfo['email'] ?? '$contactNumber@parent.classrealm.edu',
            'fullName': fullName.isEmpty ? 'Parent / Guardian' : fullName,
            'firstName': profile['first_name']?.toString() ?? '',
            'middleName': profile['middle_name']?.toString(),
            'lastName': profile['last_name']?.toString() ?? '',
            'contactNumber': contactNumber,
            'birthday': profile['birthday']?.toString(),
            'profileStatus': profile['status']?.toString(),
            'relationship':
                row['relationship']?.toString() ?? 'Parent/Guardian',
            'isArchived': isArchived,
            'studentNames': <String>[studentName],
            'sections': <String>[if (sectionName.isNotEmpty) sectionName],
            'primaryStudentId': linkedStudentId,
            'subjectName': studentInfo['subject']?.toString(),
            'subjectId': studentInfo['subjectId']?.toString(),
          };
        } else {
          final existing = parentGroupMap[parentId]!;
          (existing['studentNames'] as List<String>).add(studentName);
          if (sectionName.isNotEmpty &&
              !(existing['sections'] as List<String>).contains(sectionName)) {
            (existing['sections'] as List<String>).add(sectionName);
          }
        }
      }

      final results = <UserModel>[];
      for (final entry in parentGroupMap.values) {
        final studentNames = (entry['studentNames'] as List<String>).join(', ');
        final sections = (entry['sections'] as List<String>).join(', ');

        results.add(
          UserModel(
            id: entry['id'],
            username: entry['username'],
            email: entry['email'],
            fullName: entry['fullName'],
            firstName: entry['firstName'],
            middleName: entry['middleName'],
            lastName: entry['lastName'],
            role: UserRole.parent,
            contactNumber: entry['contactNumber'],
            birthday: DateTime.tryParse(entry['birthday']?.toString() ?? ''),
            parentGuardianRelationship: entry['relationship'],
            linkedStudentId: entry['primaryStudentId'],
            departmentOrSection: sections.isNotEmpty ? sections : '—',
            enrolledSubjectName: entry['subjectName'],
            enrolledSubjectId: entry['subjectId'],
            status: _parseParentStatus(
              entry['profileStatus']?.toString(),
              isArchived: entry['isArchived'] == true,
            ),
            isArchived: entry['isArchived'],
            parentGuardianName:
                studentNames, // Holds the formatted linked student names
          ),
        );
      }

      return results;
    } catch (e) {
      debugPrint(
        'Error fetching parents for teacher (falling back to mock): $e',
      );
      return MockDatabase.instance.users
          .where((u) => u.role == UserRole.parent && !u.isArchived)
          .toList();
    }
  }

  Future<UserModel> createParentAccount({
    required String firstName,
    String? middleName,
    required String lastName,
    required String contactNumber,
    required DateTime birthday,
    required String relationship,
    required List<String> studentIds,
    required String email,
    required String tempPassword,
  }) async {
    String parentId = 'prnt_${DateTime.now().millisecondsSinceEpoch}';

    // 1. Create user in Firebase Auth using a secondary app instance without interrupting active teacher session
    final secondaryAppName =
        'CreateParent_${DateTime.now().millisecondsSinceEpoch}';
    FirebaseApp? secondaryApp;
    try {
      secondaryApp = await Firebase.initializeApp(
        name: secondaryAppName,
        options: Firebase.app().options,
      );
      final auth = FirebaseAuth.instanceFor(app: secondaryApp);
      final cred = await auth.createUserWithEmailAndPassword(
        email: email,
        password: tempPassword,
      );
      if (cred.user != null) {
        parentId = cred.user!.uid;
      }
    } catch (e) {
      debugPrint('Firebase parent auth creation error: $e');
      rethrow;
    } finally {
      if (secondaryApp != null) {
        try {
          await secondaryApp.delete();
        } catch (_) {}
      }
    }

    final bdayIso =
        '${birthday.year}-${birthday.month.toString().padLeft(2, '0')}-${birthday.day.toString().padLeft(2, '0')}';

    // 2. Insert into public.users
    await _client.from('users').upsert({
      'id': parentId,
      'email': email,
      'role': 'parent',
      'is_archived': false,
    });

    // 3. Insert into public.parent_profiles
    await _client.from('parent_profiles').upsert({
      'parent_id': parentId,
      'first_name': firstName,
      'middle_name': middleName,
      'last_name': lastName,
      'contact_number': contactNumber,
      'birthday': bdayIso,
      'status': 'pending_first_login',
    });

    // 4. Insert into public.parent_student_links for all selected students
    for (final sId in studentIds) {
      await _client.from('parent_student_links').insert({
        'parent_id': parentId,
        'student_id': sId,
        'relationship': relationship,
      });
    }

    final fullName = [
      firstName,
      if (middleName != null && middleName.isNotEmpty) middleName,
      lastName,
    ].join(' ');

    return UserModel(
      id: parentId,
      username: email,
      email: email,
      fullName: fullName,
      firstName: firstName,
      middleName: middleName,
      lastName: lastName,
      birthday: birthday,
      contactNumber: contactNumber,
      parentGuardianRelationship: relationship,
      linkedStudentId: studentIds.isNotEmpty ? studentIds.first : null,
      role: UserRole.parent,
      status: AccountStatus.pendingFirstLogin,
      isArchived: false,
    );
  }

  Future<List<UserModel>> getLinkedStudentsForParent(String parentId) async {
    try {
      final linksResp = await _client
          .from('parent_student_links')
          .select('''
            student_id,
            relationship,
            student_profiles!inner (
              student_id,
              lrn,
              first_name,
              middle_name,
              last_name,
              birthday,
              gender
            )
          ''')
          .eq('parent_id', parentId);

      if (linksResp == null || (linksResp as List).isEmpty) {
        return [];
      }

      final results = <UserModel>[];
      for (final row in linksResp as List) {
        final profile = row['student_profiles'] as Map<String, dynamic>? ?? {};
        final sId =
            profile['student_id']?.toString() ??
            row['student_id']?.toString() ??
            '';
        final firstName = profile['first_name']?.toString() ?? '';
        final middleName = profile['middle_name']?.toString();
        final lastName = profile['last_name']?.toString() ?? '';
        final fullName = [
          firstName,
          if (middleName != null && middleName.isNotEmpty) middleName,
          lastName,
        ].join(' ');

        // Check enrollment for section
        final enrollmentResp = await _client
            .from('student_enrollments')
            .select('subject_offerings(sections(section_name, grade_level))')
            .eq('student_id', sId)
            .eq('status', 'enrolled')
            .limit(1)
            .maybeSingle();

        final offeringRaw = enrollmentResp?['subject_offerings'];
        final offering = offeringRaw is List
            ? (offeringRaw.isNotEmpty ? offeringRaw.first : null)
            : offeringRaw;
        final sectionRaw = offering?['sections'];
        final section = sectionRaw is List
            ? (sectionRaw.isNotEmpty ? sectionRaw.first : null)
            : sectionRaw;

        results.add(
          UserModel(
            id: sId,
            studentId: sId,
            username: profile['lrn']?.toString() ?? sId,
            email: '',
            fullName: fullName.trim().isNotEmpty ? fullName : 'Student',
            firstName: firstName,
            middleName: middleName,
            lastName: lastName,
            lrn: profile['lrn']?.toString(),
            gender: profile['gender']?.toString(),
            birthday: profile['birthday'] != null
                ? DateTime.tryParse(profile['birthday'].toString())
                : null,
            role: UserRole.student,
            departmentOrSection: section is Map
                ? section['section_name']?.toString()
                : null,
            gradeLevel: section is Map
                ? section['grade_level']?.toString()
                : null,
            parentGuardianRelationship: row['relationship']?.toString(),
            status: AccountStatus.active,
          ),
        );
      }
      return results;
    } catch (e) {
      debugPrint('Error getting linked students for parent: $e');
      return [];
    }
  }

  Future<void> updateParent({
    required String parentId,
    required String firstName,
    String? middleName,
    required String lastName,
    required String contactNumber,
    required String relationship,
    String? studentId,
  }) async {
    await _client
        .from('parent_profiles')
        .update({
          'first_name': firstName,
          'middle_name': middleName,
          'last_name': lastName,
          'contact_number': contactNumber,
        })
        .eq('parent_id', parentId);

    final updateData = <String, dynamic>{'relationship': relationship};
    if (studentId != null) {
      updateData['student_id'] = studentId;
    }
    await _client
        .from('parent_student_links')
        .update(updateData)
        .eq('parent_id', parentId);
  }

  Future<void> setArchived(String parentId, bool archived) async {
    await _client
        .from('users')
        .update({'is_archived': archived})
        .eq('id', parentId);
  }

  Future<void> permanentlyDelete(String parentId) async {
    await _client
        .from('parent_student_links')
        .delete()
        .eq('parent_id', parentId);
    await _client.from('parent_profiles').delete().eq('parent_id', parentId);
    await _client.from('users').delete().eq('id', parentId);
  }
}
