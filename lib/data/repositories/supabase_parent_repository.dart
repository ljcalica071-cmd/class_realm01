import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:class_realm/models/user_model.dart';
import 'package:class_realm/core/utils/parent_credential_helper.dart';
import 'package:class_realm/data/repositories/supabase_learning_material_repository.dart';
import 'package:class_realm/core/services/firebase_auth_admin_service.dart';


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
      if ((enrollments as List).isEmpty) {
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

      if ((linksResponse as List).isEmpty) {
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
      for (final u in usersResponse as List) {
        userStatusMap[u['id'].toString()] = {
          'is_archived': u['is_archived'] == true,
          'email': u['email']?.toString(),
        };
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
        'Error fetching parents for teacher: $e',
      );
      return [];
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
    String? email,
    String? tempPassword,
  }) async {
    // 1. Sibling Auto-Linking: Check if the exact same parent already exists in public.parent_profiles
    final existingParents = await _client
        .from('parent_profiles')
        .select('parent_id, first_name, last_name, contact_number, birthday')
        .ilike('first_name', firstName.trim())
        .ilike('last_name', lastName.trim())
        .eq('contact_number', contactNumber.trim());

    if ((existingParents as List).isNotEmpty) {
      final existingProfile = existingParents.first;
      final existingParentId = existingProfile['parent_id'].toString();

      // Upsert all selected studentIds into public.parent_student_links (onConflict: 'parent_id,student_id')
      for (final sId in studentIds) {
        await _client.from('parent_student_links').upsert({
          'parent_id': existingParentId,
          'student_id': sId,
          'relationship': relationship,
        }, onConflict: 'parent_id,student_id');
      }

      // Fetch existing email from public.users
      final userRow = await _client
          .from('users')
          .select('email, is_archived')
          .eq('id', existingParentId)
          .maybeSingle();

      final existingEmail = userRow?['email']?.toString() ??
          ParentCredentialHelper.generateEmail(lastName);

      final fullName = [
        firstName,
        if (middleName != null && middleName.isNotEmpty) middleName,
        lastName,
      ].join(' ');

      return UserModel(
        id: existingParentId,
        username: existingEmail,
        email: existingEmail,
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
        isArchived: userRow?['is_archived'] == true,
      );
    }

    // 2. New Parent: Surname Collision Handling
    final baseLastName = ParentCredentialHelper.sanitizeLastName(lastName);

    // Query public.users for existing emails matching baseLastName%@classrealm.com
    final existingUsers = await _client
        .from('users')
        .select('email')
        .ilike('email', '$baseLastName%@${ParentCredentialHelper.domain}');

    final takenEmails = <String>{};
    for (final u in existingUsers as List) {
      final em = u['email']?.toString().toLowerCase().trim();
      if (em != null) takenEmails.add(em);
    }

    int collisionIndex = 1;
    while (takenEmails.contains(
      ParentCredentialHelper.generateEmail(baseLastName, collisionIndex: collisionIndex).toLowerCase(),
    )) {
      collisionIndex++;
    }

    String finalEmail = ParentCredentialHelper.generateEmail(baseLastName, collisionIndex: collisionIndex);
    final finalTempPassword = tempPassword ?? ParentCredentialHelper.generateTempPassword(baseLastName, birthday);

    final parentFullName = [firstName, middleName, lastName]
        .where((s) => s != null && s.isNotEmpty)
        .join(' ');

    String parentId = 'prnt_${DateTime.now().millisecondsSinceEpoch}';

    try {
      bool created = false;
      for (int attempt = 0; attempt < 20; attempt++) {
        final candidateEmail = ParentCredentialHelper.generateEmail(
          baseLastName,
          collisionIndex: collisionIndex,
        );
        final fbUid = await FirebaseAuthAdminService.createUser(
          email: candidateEmail,
          password: finalTempPassword,
          displayName: parentFullName.isNotEmpty ? parentFullName : 'Parent/Guardian',
        );
        if (fbUid != null && fbUid.isNotEmpty) {
          parentId = fbUid;
          finalEmail = candidateEmail;
          created = true;
          break;
        } else {
          collisionIndex++;
        }
      }
      if (!created) {
        throw Exception('Failed to provision parent account in Firebase Authentication.');
      }
    } catch (e) {
      debugPrint('Firebase parent auth creation error: $e');
      rethrow;
    }

    final bdayIso =
        '${birthday.year}-${birthday.month.toString().padLeft(2, '0')}-${birthday.day.toString().padLeft(2, '0')}';

    // 3. Insert into public.users
    await _client.from('users').upsert({
      'id': parentId,
      'email': finalEmail,
      'role': 'parent',
      'is_archived': false,
    });

    // 4. Insert into public.parent_profiles
    await _client.from('parent_profiles').upsert({
      'parent_id': parentId,
      'first_name': firstName,
      'middle_name': middleName,
      'last_name': lastName,
      'contact_number': contactNumber,
      'birthday': bdayIso,
      'status': 'pending_first_login',
    });

    // 5. Insert into public.parent_student_links for all selected students
    for (final sId in studentIds) {
      await _client.from('parent_student_links').upsert({
        'parent_id': parentId,
        'student_id': sId,
        'relationship': relationship,
      }, onConflict: 'parent_id,student_id');
    }

    final fullName = [
      firstName,
      if (middleName != null && middleName.isNotEmpty) middleName,
      lastName,
    ].join(' ');

    return UserModel(
      id: parentId,
      username: finalEmail,
      email: finalEmail,
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

  /// Verifies the parent's identity for first login:
  /// checks contact number matches public.parent_profiles
  /// and at least one linked student's 12-digit LRN ends with childLrnLast4.
  Future<bool> verifyParentIdentityForFirstLogin({
    required String parentId,
    required String contactNumber,
    required String childLrnLast4,
  }) async {
    try {
      final cleanPhone = contactNumber.trim();
      final cleanLrn4 = childLrnLast4.trim();
      if (cleanPhone.isEmpty || cleanLrn4.isEmpty) return false;

      // 1. Query public.parent_profiles for parent_id = parentId
      final profileResp = await _client
          .from('parent_profiles')
          .select('contact_number')
          .eq('parent_id', parentId)
          .maybeSingle();

      if (profileResp == null) return false;
      final storedContact = profileResp['contact_number']?.toString().trim();
      if (storedContact != cleanPhone) {
        return false;
      }

      // 2. Query public.parent_student_links joined with student_profiles!inner(lrn)
      final linksResp = await _client
          .from('parent_student_links')
          .select('''
            student_id,
            student_profiles!inner (
              lrn
            )
          ''')
          .eq('parent_id', parentId);

      if ((linksResp as List).isEmpty) {
        return false;
      }

      bool matchedLrn = false;
      for (final row in linksResp as List) {
        final st = row['student_profiles'];
        String? lrnStr;
        if (st is Map) {
          lrnStr = st['lrn']?.toString().trim();
        } else if (st is List && st.isNotEmpty) {
          lrnStr = (st.first as Map)['lrn']?.toString().trim();
        }
        if (lrnStr != null && lrnStr.length >= 4 && lrnStr.endsWith(cleanLrn4)) {
          matchedLrn = true;
          break;
        }
      }

      return matchedLrn;
    } catch (e) {
      debugPrint('Error verifying parent identity for first login: $e');
      return false;
    }
  }

  /// Resets a parent's account back to default password and pending_first_login.
  Future<UserModel> resetParentToDefaultPassword(UserModel parent) async {
    final bday = parent.birthday ?? DateTime.now();
    final tempPassword = ParentCredentialHelper.generateTempPassword(
      parent.lastName ?? parent.fullName.split(' ').last,
      bday,
    );

    // 1. Use secondary FirebaseApp instance to test if signInWithEmailAndPassword works
    final secondaryAppName = 'TestReset_${DateTime.now().millisecondsSinceEpoch}';
    FirebaseApp? secondaryApp;
    bool tempPasswordWorked = false;

    try {
      secondaryApp = await Firebase.initializeApp(
        name: secondaryAppName,
        options: Firebase.app().options,
      );
      final auth = FirebaseAuth.instanceFor(app: secondaryApp);

      try {
        await auth.signInWithEmailAndPassword(
          email: parent.email,
          password: tempPassword,
        );
        tempPasswordWorked = true;
      } catch (_) {
        tempPasswordWorked = false;
      }
    } finally {
      if (secondaryApp != null) {
        try {
          await secondaryApp.delete();
        } catch (_) {}
      }
    }

    if (tempPasswordWorked) {
      // If login with tempPassword succeeds, simply update status = 'pending_first_login'
      await _client
          .from('parent_profiles')
          .update({'status': 'pending_first_login'})
          .eq('parent_id', parent.id);

      return parent.copyWith(status: AccountStatus.pendingFirstLogin);
    } else {
      // Parent's password was changed on mobile. Provision a fresh Firebase Auth UID with the next available alias
      final baseLastName = ParentCredentialHelper.sanitizeLastName(
        parent.lastName ?? parent.fullName.split(' ').last,
      );

      final existingUsers = await _client
          .from('users')
          .select('email')
          .ilike('email', '$baseLastName%@${ParentCredentialHelper.domain}');

      final takenEmails = <String>{};
      for (final u in existingUsers as List) {
        final em = u['email']?.toString().toLowerCase().trim();
        if (em != null) takenEmails.add(em);
      }

      int collisionIndex = 1;
      while (takenEmails.contains(
        ParentCredentialHelper.generateEmail(baseLastName, collisionIndex: collisionIndex).toLowerCase(),
      )) {
        collisionIndex++;
      }

      String newUid = 'prnt_${DateTime.now().millisecondsSinceEpoch}';
      String newEmail = ParentCredentialHelper.generateEmail(baseLastName, collisionIndex: collisionIndex);

      try {
        bool created = false;
        for (int i = 0; i < 20; i++) {
          final candidate = ParentCredentialHelper.generateEmail(
            baseLastName,
            collisionIndex: collisionIndex,
          );
          final fbUid = await FirebaseAuthAdminService.createUser(
            email: candidate,
            password: tempPassword,
            displayName: parent.fullName.isNotEmpty ? parent.fullName : 'Parent/Guardian',
          );
          if (fbUid != null && fbUid.isNotEmpty) {
            newUid = fbUid;
            newEmail = candidate;
            created = true;
            break;
          } else {
            collisionIndex++;
          }
        }
        if (!created) {
          throw Exception('Failed to provision reset credentials in Firebase Authentication.');
        }
      } catch (e) {
        debugPrint('Firebase resetParentCredentials error: $e');
        rethrow;
      }

      // Fetch existing profile and linked students
      final oldProfile = await _client
          .from('parent_profiles')
          .select()
          .eq('parent_id', parent.id)
          .maybeSingle();

      final oldLinks = await _client
          .from('parent_student_links')
          .select()
          .eq('parent_id', parent.id);

      // Insert into public.users with newUid and newEmail
      await _client.from('users').insert({
        'id': newUid,
        'email': newEmail,
        'role': 'parent',
        'is_archived': false,
      });

      // Insert into public.parent_profiles with newUid, status = 'pending_first_login'
      final bdayIso = parent.birthday != null
          ? '${parent.birthday!.year}-${parent.birthday!.month.toString().padLeft(2, '0')}-${parent.birthday!.day.toString().padLeft(2, '0')}'
          : oldProfile?['birthday'];

      await _client.from('parent_profiles').insert({
        'parent_id': newUid,
        'first_name': oldProfile?['first_name'] ?? parent.firstName ?? '',
        'middle_name': oldProfile?['middle_name'] ?? parent.middleName,
        'last_name': oldProfile?['last_name'] ?? parent.lastName ?? '',
        'contact_number': oldProfile?['contact_number'] ?? parent.contactNumber ?? '',
        'birthday': bdayIso,
        'status': 'pending_first_login',
      });

      // Insert into public.parent_student_links for all previously linked students
      if ((oldLinks as List).isNotEmpty) {
        for (final link in oldLinks as List) {
          await _client.from('parent_student_links').insert({
            'parent_id': newUid,
            'student_id': link['student_id'],
            'relationship': link['relationship'] ?? parent.parentGuardianRelationship ?? 'Parent/Guardian',
          });
        }
      }

      // Cleanup old rows safely
      try {
        await _client.from('parent_student_links').delete().eq('parent_id', parent.id);
        await _client.from('parent_profiles').delete().eq('parent_id', parent.id);
        await _client.from('users').delete().eq('id', parent.id);
      } catch (e) {
        debugPrint('Cleanup old parent error: $e');
      }

      return parent.copyWith(
        id: newUid,
        email: newEmail,
        username: newEmail,
        status: AccountStatus.pendingFirstLogin,
      );
    }
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

      if ((linksResp as List).isEmpty) {
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

  Future<void> setArchived(String parentId, bool archived, {String? currentStatusHint}) async {
    await _client
        .from('users')
        .update({'is_archived': archived})
        .eq('id', parentId);

    try {
      if (archived) {
        final cur = await _client
            .from('parent_profiles')
            .select('status')
            .eq('parent_id', parentId)
            .maybeSingle();
        final currentStatus = cur?['status']?.toString();
        final statusToSave = (currentStatus != null &&
                currentStatus.isNotEmpty &&
                currentStatus != 'archived')
            ? currentStatus
            : (currentStatusHint ?? 'active');

        await _client
            .from('parent_profiles')
            .update({
              'previous_status': statusToSave,
              'status': 'archived',
            })
            .eq('parent_id', parentId);
      } else {
        final cur = await _client
            .from('parent_profiles')
            .select('previous_status')
            .eq('parent_id', parentId)
            .maybeSingle();
        final prev = cur?['previous_status']?.toString();
        final targetStatus = (prev != null && prev.isNotEmpty && prev != 'archived')
            ? prev
            : 'active';

        await _client
            .from('parent_profiles')
            .update({
              'status': targetStatus,
              'previous_status': null,
            })
            .eq('parent_id', parentId);
      }
    } catch (e) {
      debugPrint('Error updating parent archive profile status: $e');
    }

    try {
      await FirebaseAuthAdminService.setUserDisabled(
        uid: parentId,
        disabled: archived,
      );
    } catch (_) {}
  }

  Future<void> permanentlyDelete(String parentId) async {
    await _client
        .from('parent_student_links')
        .delete()
        .eq('parent_id', parentId);
    await _client.from('parent_profiles').delete().eq('parent_id', parentId);
    await _client.from('users').delete().eq('id', parentId);
    try {
      await FirebaseAuthAdminService.deleteUser(uid: parentId);
    } catch (_) {}
  }

  /// Read-only helper: fetches learning materials for a parent's linked student,
  /// ensuring enrollment isolation and hierarchical visibility.
  Future<List<Map<String, dynamic>>> getStudentLearningMaterialsForParent({
    required String parentId,
    required String studentId,
  }) async {
    try {
      // 1. Verify link between parent and student
      final link = await _client
          .from('parent_student_links')
          .select('student_id')
          .eq('parent_id', parentId)
          .eq('student_id', studentId)
          .maybeSingle();

      if (link == null) return [];

      // 2. Fetch enrolled subject offerings
      final enrollments = await _client
          .from('student_enrollments')
          .select('subject_offering_id')
          .eq('student_id', studentId)
          .eq('status', 'enrolled');

      if ((enrollments as List).isEmpty) return [];

      final offeringIds = (enrollments as List)
          .map((e) => e['subject_offering_id']?.toString())
          .whereType<String>()
          .toList();

      // 3. Fetch materials using hierarchical visibility
      final materials = <Map<String, dynamic>>[];
      for (final oId in offeringIds) {
        final list = await SupabaseLearningMaterialRepository.instance
            .getStudentMaterialsWithHierarchy(subjectOfferingId: oId);
        for (final m in list) {
          materials.add({
            'id': m.id,
            'title': m.displayName,
            'fileName': m.fileName,
            'format': m.fileExtension,
            'size': m.formattedSize,
            'description': m.description,
            'createdAt': m.createdAt.toIso8601String(),
          });
        }
      }
      return materials;
    } catch (e) {
      debugPrint('Error getting student materials for parent: $e');
      return [];
    }
  }
}

