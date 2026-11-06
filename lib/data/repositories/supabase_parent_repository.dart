import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:class_realm/models/user_model.dart';
import 'package:class_realm/models/academic_models.dart';
import 'package:class_realm/data/repositories/supabase_schedule_repository.dart';
import 'package:class_realm/core/utils/parent_credential_helper.dart';
import 'package:class_realm/core/utils/validators.dart';
import 'package:class_realm/core/services/local_storage_service.dart';
import 'package:class_realm/core/services/firebase_auth_admin_service.dart';
import 'package:class_realm/core/services/app_data_cache.dart';

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

  /// Resolves a unique parent email in the format `firstname.lastname.cr@classrealm.com`
  /// (or `firstname.lastname2.cr@classrealm.com` on collision), optionally excluding
  /// `excludeParentId` when updating an existing parent.
  Future<String> _resolveUniqueParentEmail({
    required String firstName,
    required String lastName,
    String? excludeParentId,
  }) async {
    final baseFirst = ParentCredentialHelper.sanitizeNamePart(
      firstName,
      fallback: '',
    );
    final baseLast = ParentCredentialHelper.sanitizeLastName(lastName);
    final prefix = baseFirst.isNotEmpty ? '$baseFirst.$baseLast' : baseLast;

    final existingUsers = await _client
        .from('users')
        .select('id, email')
        .ilike('email', '$prefix%@${ParentCredentialHelper.domain}');

    final takenEmails = <String>{};
    for (final u in existingUsers as List) {
      final uid = u['id']?.toString();
      if (excludeParentId != null && uid == excludeParentId) continue;
      final em = u['email']?.toString().toLowerCase().trim();
      if (em != null) takenEmails.add(em);
    }

    int collisionIndex = 1;
    while (takenEmails.contains(
      ParentCredentialHelper.generateEmail(
        lastName,
        rawFirstName: firstName,
        collisionIndex: collisionIndex,
      ).toLowerCase(),
    )) {
      collisionIndex++;
    }

    return ParentCredentialHelper.generateEmail(
      lastName,
      rawFirstName: firstName,
      collisionIndex: collisionIndex,
    );
  }

  Future<List<UserModel>> getParentsForTeacher(
    String teacherId, {
    String? subjectId,
    bool includeArchived = false,
    void Function(List<UserModel> fresh)? onFreshData,
  }) async {
    final cacheKey =
        'teacher_parents_${teacherId}_${subjectId ?? "all"}_$includeArchived';
    return AppDataCache.instance.fetchWithSvr<List<UserModel>>(
      cacheKey: cacheKey,
      ttl: const Duration(minutes: 5),
      fetcher: () => _fetchParentsFromNetwork(
        teacherId,
        subjectId: subjectId,
        includeArchived: includeArchived,
      ),
      onUpdate: onFreshData,
    );
  }

  Future<List<UserModel>> _fetchParentsFromNetwork(
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
        final rel = row['relationship']?.toString() ?? 'Parent/Guardian';

        if (!parentGroupMap.containsKey(parentId)) {
          final fullName = [
            profile['first_name'],
            profile['middle_name'],
            profile['last_name'],
          ].where((n) => n != null && n.toString().trim().isNotEmpty).join(' ');

          final username = parentId;

          parentGroupMap[parentId] = {
            'id': parentId,
            'username': username,
            'email': userInfo['email'] ?? 'parent_$parentId@classrealm.com',
            'fullName': fullName.isEmpty ? 'Parent / Guardian' : fullName,
            'firstName': profile['first_name']?.toString() ?? '',
            'middleName': profile['middle_name']?.toString(),
            'lastName': profile['last_name']?.toString() ?? '',
            'birthday': profile['birthday']?.toString(),
            'profileStatus': profile['status']?.toString(),
            'relationships': <String>[rel],
            'isArchived': isArchived,
            'studentNames': <String>[studentName],
            'sections': <String>[if (sectionName.isNotEmpty) sectionName],
            'primaryStudentId': linkedStudentId,
            'subjectName': studentInfo['subject']?.toString(),
            'subjectId': studentInfo['subjectId']?.toString(),
          };
        } else {
          final existing = parentGroupMap[parentId]!;
          final studentNamesList = existing['studentNames'] as List<String>;
          if (!studentNamesList.contains(studentName)) {
            studentNamesList.add(studentName);
          }
          final relsList = existing['relationships'] as List<String>;
          if (!relsList.contains(rel)) {
            relsList.add(rel);
          }
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
        final relationships = (entry['relationships'] as List<String>).join(
          ', ',
        );

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
            birthday: DateTime.tryParse(entry['birthday']?.toString() ?? ''),
            parentGuardianRelationship: relationships,
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
      debugPrint('Error fetching parents for teacher: $e');
      return [];
    }
  }

  Future<UserModel> createParentAccount({
    required String firstName,
    String? middleName,
    required String lastName,
    required DateTime birthday,
    required String relationship,
    required List<String> studentIds,
    String? email,
    String? tempPassword,
  }) async {
    final cleanMiddleName = AppValidators.normalizeMiddleInitial(middleName);
    // 1. Sibling Auto-Linking: Check if the exact same parent already exists in public.parent_profiles
    final bdayStr =
        '${birthday.year.toString().padLeft(4, '0')}-${birthday.month.toString().padLeft(2, '0')}-${birthday.day.toString().padLeft(2, '0')}';

    final existingParents = await _client
        .from('parent_profiles')
        .select('parent_id, first_name, last_name, birthday')
        .ilike('first_name', firstName.trim())
        .ilike('last_name', lastName.trim())
        .eq('birthday', bdayStr);

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

      final existingEmail =
          userRow?['email']?.toString() ??
          ParentCredentialHelper.generateEmail(
            lastName,
            rawFirstName: firstName,
          );

      final fullName = [firstName, ?cleanMiddleName, lastName].join(' ');

      AppDataCache.instance.invalidatePrefix('teacher_parents_');
      return UserModel(
        id: existingParentId,
        username: existingEmail,
        email: existingEmail,
        fullName: fullName,
        firstName: firstName,
        middleName: cleanMiddleName,
        lastName: lastName,
        birthday: birthday,
        parentGuardianRelationship: relationship,
        linkedStudentId: studentIds.isNotEmpty ? studentIds.first : null,
        role: UserRole.parent,
        status: AccountStatus.pendingFirstLogin,
        isArchived: userRow?['is_archived'] == true,
      );
    }

    // 2. New Parent: Name Collision Handling (`firstname.lastname.cr@classrealm.com`)
    final baseFirst = ParentCredentialHelper.sanitizeNamePart(
      firstName,
      fallback: '',
    );
    final baseLast = ParentCredentialHelper.sanitizeLastName(lastName);
    final prefix = baseFirst.isNotEmpty ? '$baseFirst.$baseLast' : baseLast;

    final existingUsers = await _client
        .from('users')
        .select('email')
        .ilike('email', '$prefix%@${ParentCredentialHelper.domain}');

    final takenEmails = <String>{};
    for (final u in existingUsers as List) {
      final em = u['email']?.toString().toLowerCase().trim();
      if (em != null) takenEmails.add(em);
    }

    int collisionIndex = 1;
    while (takenEmails.contains(
      ParentCredentialHelper.generateEmail(
        lastName,
        rawFirstName: firstName,
        collisionIndex: collisionIndex,
      ).toLowerCase(),
    )) {
      collisionIndex++;
    }

    String finalEmail = ParentCredentialHelper.generateEmail(
      lastName,
      rawFirstName: firstName,
      collisionIndex: collisionIndex,
    );
    final finalTempPassword =
        tempPassword ??
        ParentCredentialHelper.generateTempPassword(baseLast, birthday);

    final parentFullName = [firstName, ?cleanMiddleName, lastName].join(' ');

    String parentId = 'prnt_${DateTime.now().millisecondsSinceEpoch}';

    try {
      bool created = false;
      for (int attempt = 0; attempt < 20; attempt++) {
        final candidateEmail = ParentCredentialHelper.generateEmail(
          lastName,
          rawFirstName: firstName,
          collisionIndex: collisionIndex,
        );
        final fbUid = await FirebaseAuthAdminService.createUser(
          email: candidateEmail,
          password: finalTempPassword,
          displayName: parentFullName.isNotEmpty
              ? parentFullName
              : 'Parent/Guardian',
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
        throw Exception(
          'Failed to provision parent account in Firebase Authentication.',
        );
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
      'middle_name': cleanMiddleName,
      'last_name': lastName,
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

    final fullName = [firstName, ?cleanMiddleName, lastName].join(' ');

    AppDataCache.instance.invalidatePrefix('teacher_parents_');
    return UserModel(
      id: parentId,
      username: finalEmail,
      email: finalEmail,
      fullName: fullName,
      firstName: firstName,
      middleName: cleanMiddleName,
      lastName: lastName,
      birthday: birthday,
      parentGuardianRelationship: relationship,
      linkedStudentId: studentIds.isNotEmpty ? studentIds.first : null,
      role: UserRole.parent,
      status: AccountStatus.pendingFirstLogin,
      isArchived: false,
    );
  }

  /// Searches for existing parent profiles in the school database by parent name or linked child LRN / name.
  /// Used in AddParentDialog to easily link siblings to an already registered parent account.
  Future<List<Map<String, dynamic>>> searchExistingParents({
    required String query,
  }) async {
    final cleanQuery = query.trim().toLowerCase();
    if (cleanQuery.isEmpty) return [];

    try {
      // 1. Search parent_profiles by first_name or last_name
      final parentResp = await _client
          .from('parent_profiles')
          .select('''
            parent_id,
            first_name,
            middle_name,
            last_name,
            birthday,
            status,
            users!inner ( email, is_archived )
          ''')
          .or('first_name.ilike.%$cleanQuery%,last_name.ilike.%$cleanQuery%')
          .limit(15);

      final parentMap = <String, Map<String, dynamic>>{};
      for (final p in (parentResp as List)) {
        final pid = p['parent_id']?.toString();
        if (pid == null) continue;
        final u = p['users'] as Map<String, dynamic>? ?? {};
        if (u['is_archived'] == true) continue;

        final fullName = [
          p['first_name'],
          p['middle_name'],
          p['last_name'],
        ].where((n) => n != null && n.toString().trim().isNotEmpty).join(' ');

        parentMap[pid] = {
          'parentId': pid,
          'fullName': fullName,
          'firstName': p['first_name']?.toString() ?? '',
          'middleName': p['middle_name']?.toString(),
          'lastName': p['last_name']?.toString() ?? '',
          'birthday': p['birthday'] != null
              ? DateTime.tryParse(p['birthday'].toString())
              : null,
          'email': u['email']?.toString() ?? '',
          'status': p['status']?.toString() ?? 'active',
          'linkedChildren': <Map<String, dynamic>>[],
        };
      }

      // If search by student LRN or name, also check parent_student_links
      if (cleanQuery.length >= 3) {
        final linksByStudentResp = await _client
            .from('parent_student_links')
            .select('''
              parent_id,
              relationship,
              student_profiles!inner (
                student_id,
                lrn,
                first_name,
                middle_name,
                last_name
              )
            ''')
            .or(
              'student_profiles.first_name.ilike.%$cleanQuery%,student_profiles.last_name.ilike.%$cleanQuery%,student_profiles.lrn.ilike.%$cleanQuery%',
            )
            .limit(15);

        final missingParentIds = <String>[];
        for (final row in (linksByStudentResp as List)) {
          final pid = row['parent_id']?.toString();
          if (pid != null && !parentMap.containsKey(pid)) {
            missingParentIds.add(pid);
          }
        }

        if (missingParentIds.isNotEmpty) {
          final extraParents = await _client
              .from('parent_profiles')
              .select('''
                parent_id,
                first_name,
                middle_name,
                last_name,
                birthday,
                status,
                users!inner ( email, is_archived )
              ''')
              .filter('parent_id', 'in', missingParentIds);

          for (final p in (extraParents as List)) {
            final pid = p['parent_id']?.toString();
            if (pid == null) continue;
            final u = p['users'] as Map<String, dynamic>? ?? {};
            if (u['is_archived'] == true) continue;

            final fullName = [p['first_name'], p['middle_name'], p['last_name']]
                .where((n) => n != null && n.toString().trim().isNotEmpty)
                .join(' ');

            parentMap[pid] = {
              'parentId': pid,
              'fullName': fullName,
              'firstName': p['first_name']?.toString() ?? '',
              'middleName': p['middle_name']?.toString(),
              'lastName': p['last_name']?.toString() ?? '',
              'birthday': p['birthday'] != null
                  ? DateTime.tryParse(p['birthday'].toString())
                  : null,
              'email': u['email']?.toString() ?? '',
              'status': p['status']?.toString() ?? 'active',
              'linkedChildren': <Map<String, dynamic>>[],
            };
          }
        }
      }

      if (parentMap.isEmpty) return [];

      // Fetch linked children for all matched parents
      final allParentIds = parentMap.keys.toList();
      final childrenResp = await _client
          .from('parent_student_links')
          .select('''
            parent_id,
            relationship,
            student_profiles!inner (
              student_id,
              lrn,
              first_name,
              middle_name,
              last_name
            )
          ''')
          .filter('parent_id', 'in', allParentIds);

      for (final row in (childrenResp as List)) {
        final pid = row['parent_id']?.toString();
        if (pid == null || !parentMap.containsKey(pid)) continue;

        final sp = row['student_profiles'] as Map<String, dynamic>? ?? {};
        final studentName = [
          sp['first_name'],
          sp['middle_name'],
          sp['last_name'],
        ].where((n) => n != null && n.toString().trim().isNotEmpty).join(' ');

        (parentMap[pid]!['linkedChildren'] as List).add({
          'studentId': sp['student_id']?.toString() ?? '',
          'fullName': studentName,
          'lrn': sp['lrn']?.toString() ?? '',
          'relationship': row['relationship']?.toString() ?? 'Child',
        });
      }

      return parentMap.values.toList();
    } catch (e) {
      debugPrint('Error searching existing parents: $e');
      return [];
    }
  }

  /// Links selected students to an already existing parent account.
  /// Prevents creating duplicate accounts for siblings.
  Future<void> linkStudentsToExistingParent({
    required String parentId,
    required List<String> studentIds,
    required String relationship,
  }) async {
    for (final sId in studentIds) {
      await _client.from('parent_student_links').upsert({
        'parent_id': parentId,
        'student_id': sId,
        'relationship': relationship,
      }, onConflict: 'parent_id,student_id');
    }

    AppDataCache.instance.invalidatePrefix('teacher_parents_');
    AppDataCache.instance.invalidatePrefix('parent_linked_students_$parentId');
  }

  Future<bool> verifyParentIdentityForFirstLogin({
    required String parentId,
    required DateTime birthday,
    required String childLrnLast4,
  }) async {
    try {
      final bdayIso =
          '${birthday.year}-${birthday.month.toString().padLeft(2, '0')}-${birthday.day.toString().padLeft(2, '0')}';
      final cleanLrn4 = childLrnLast4.trim();
      if (cleanLrn4.isEmpty) return false;

      // 1. Query public.parent_profiles for parent_id = parentId
      final profileResp = await _client
          .from('parent_profiles')
          .select('birthday')
          .eq('parent_id', parentId)
          .maybeSingle();

      if (profileResp == null) return false;
      final storedBday = profileResp['birthday']?.toString().trim();
      if (storedBday != bdayIso) {
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
        if (lrnStr != null &&
            lrnStr.length >= 4 &&
            lrnStr.endsWith(cleanLrn4)) {
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

  /// Resets a parent's account back to default temporary password (`lastnameYYYYMMDD`)
  /// and `pending_first_login` status based on their current profile details.
  Future<UserModel> resetParentToDefaultPassword(UserModel parent) async {
    final profileRow = await _client
        .from('parent_profiles')
        .select('first_name, middle_name, last_name, birthday')
        .eq('parent_id', parent.id)
        .maybeSingle();

    final firstName =
        profileRow?['first_name']?.toString().trim().isNotEmpty == true
        ? profileRow!['first_name'].toString().trim()
        : (parent.firstName ?? parent.fullName.split(' ').first);
    final middleName =
        profileRow?['middle_name']?.toString() ?? parent.middleName;
    final lastName =
        profileRow?['last_name']?.toString().trim().isNotEmpty == true
        ? profileRow!['last_name'].toString().trim()
        : (parent.lastName ?? parent.fullName.split(' ').last);
    final bday =
        (profileRow?['birthday'] != null
            ? DateTime.tryParse(profileRow!['birthday'].toString())
            : null) ??
        parent.birthday ??
        DateTime(1970, 1, 1);

    final tempPassword = ParentCredentialHelper.generateTempPassword(
      lastName,
      bday,
    );

    final expectedEmail = await _resolveUniqueParentEmail(
      firstName: firstName,
      lastName: lastName,
      excludeParentId: parent.id,
    );

    // 1. Update password directly in Firebase Auth
    final pwUpdated = await FirebaseAuthAdminService.updateUserPassword(
      uid: parent.id,
      newPassword: tempPassword,
    );
    if (!pwUpdated) {
      throw Exception(
        'Failed to reset password in Firebase Authentication. Please try again.',
      );
    }

    // 2. Ensure email in Firebase Auth & Supabase matches the canonical format
    if (parent.email.trim().toLowerCase() != expectedEmail.toLowerCase()) {
      await FirebaseAuthAdminService.updateUserEmail(
        uid: parent.id,
        newEmail: expectedEmail,
      );
      await _client
          .from('users')
          .update({'email': expectedEmail})
          .eq('id', parent.id);
    }

    // 3. Set status = 'pending_first_login' in public.parent_profiles
    await _client
        .from('parent_profiles')
        .update({'status': 'pending_first_login'})
        .eq('parent_id', parent.id);

    AppDataCache.instance.invalidatePrefix('teacher_parents_');

    final fullName = [
      firstName,
      if (middleName != null && middleName.trim().isNotEmpty) middleName.trim(),
      lastName,
    ].join(' ');

    return parent.copyWith(
      email: expectedEmail,
      username: expectedEmail,
      fullName: fullName,
      firstName: firstName,
      middleName: middleName,
      lastName: lastName,
      birthday: bday,
      status: AccountStatus.pendingFirstLogin,
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

      if ((linksResp as List).isEmpty) {
        return [];
      }

      final studentIds = (linksResp as List)
          .map((row) {
            final p = row['student_profiles'] as Map<String, dynamic>? ?? {};
            return p['student_id']?.toString() ?? row['student_id']?.toString();
          })
          .whereType<String>()
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList();

      final privacyByStudentId = <String, Map<String, bool>>{};
      if (studentIds.isNotEmpty) {
        try {
          final settingsResp = await _client
              .from('student_settings')
              .select(
                'student_id, hide_term_grades_from_parent, hide_final_grades_from_parent',
              )
              .filter('student_id', 'in', studentIds);
          for (final sRow in (settingsResp as List)) {
            final sid = sRow['student_id']?.toString();
            if (sid != null) {
              privacyByStudentId[sid] = {
                'hideTerm': sRow['hide_term_grades_from_parent'] == true,
                'hideFinal': sRow['hide_final_grades_from_parent'] == true,
              };
            }
          }
        } catch (e) {
          debugPrint('Student settings privacy columns notice: $e');
        }
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
            .ilike('status', 'enrolled')
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

        final localPrivacy = LocalStorageService.getStudentGradePrivacy(sId);
        final dbPrivacy = privacyByStudentId[sId];
        final hideTerm =
            dbPrivacy?['hideTerm'] ?? localPrivacy?['hideTermGrades'] ?? false;
        final hideFinal =
            dbPrivacy?['hideFinal'] ??
            localPrivacy?['hideFinalGrades'] ??
            false;

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
            hideTermGradesFromParent: hideTerm,
            hideFinalGradesFromParent: hideFinal,
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

  /// Updates a parent's personal profile, synchronizes their login credentials if needed,
  /// and synchronizes their multi-student relationship links (enforcing >= 1 linked student).
  Future<UserModel> updateParentAccountAndLinks({
    required UserModel currentParent,
    required String firstName,
    String? middleName,
    required String lastName,
    required DateTime birthday,
    required List<Map<String, String>> studentLinks,
  }) async {
    if (studentLinks.isEmpty) {
      throw Exception(
        'At least 1 student must remain linked to this parent account.',
      );
    }

    final cleanFirst = firstName.trim();
    final cleanMiddle = AppValidators.normalizeMiddleInitial(middleName);
    final cleanLast = lastName.trim();
    final bdayIso =
        '${birthday.year.toString().padLeft(4, '0')}-${birthday.month.toString().padLeft(2, '0')}-${birthday.day.toString().padLeft(2, '0')}';

    // 1. Update public.parent_profiles
    await _client
        .from('parent_profiles')
        .update({
          'first_name': cleanFirst,
          'middle_name': cleanMiddle,
          'last_name': cleanLast,
          'birthday': bdayIso,
        })
        .eq('parent_id', currentParent.id);

    // 2. Resolve canonical email (`firstname.lastname.cr@classrealm.com`)
    final newEmail = await _resolveUniqueParentEmail(
      firstName: cleanFirst,
      lastName: cleanLast,
      excludeParentId: currentParent.id,
    );

    if (newEmail.toLowerCase() != currentParent.email.trim().toLowerCase()) {
      await _client
          .from('users')
          .update({'email': newEmail})
          .eq('id', currentParent.id);
      await FirebaseAuthAdminService.updateUserEmail(
        uid: currentParent.id,
        newEmail: newEmail,
      );
    }

    // 3. If account is still pending first login, keep temp password synced with updated lastName + birthday
    if (currentParent.status == AccountStatus.pendingFirstLogin) {
      final newTempPassword = ParentCredentialHelper.generateTempPassword(
        cleanLast,
        birthday,
      );
      await FirebaseAuthAdminService.updateUserPassword(
        uid: currentParent.id,
        newPassword: newTempPassword,
      );
    }

    // 4. Synchronize parent_student_links
    final existingLinksResp = await _client
        .from('parent_student_links')
        .select('student_id')
        .eq('parent_id', currentParent.id);
    final existingStudentIds = (existingLinksResp as List)
        .map((r) => r['student_id']?.toString())
        .whereType<String>()
        .toSet();

    final targetStudentIds = <String>{};
    for (final link in studentLinks) {
      final sId = link['studentId']?.trim() ?? '';
      final rel = link['relationship']?.trim().isNotEmpty == true
          ? link['relationship']!.trim()
          : 'Guardian';
      if (sId.isEmpty) continue;
      targetStudentIds.add(sId);
      await _client.from('parent_student_links').upsert({
        'parent_id': currentParent.id,
        'student_id': sId,
        'relationship': rel,
      }, onConflict: 'parent_id,student_id');
    }

    final toDelete = existingStudentIds.difference(targetStudentIds);
    for (final delId in toDelete) {
      await _client
          .from('parent_student_links')
          .delete()
          .eq('parent_id', currentParent.id)
          .eq('student_id', delId);
    }

    AppDataCache.instance.invalidatePrefix('teacher_parents_');
    AppDataCache.instance.invalidatePrefix(
      'parent_linked_students_${currentParent.id}',
    );

    final fullName = [cleanFirst, ?cleanMiddle, cleanLast].join(' ');
    final relsSummary = studentLinks
        .map((l) => l['relationship'] ?? 'Guardian')
        .toSet()
        .join(', ');

    return currentParent.copyWith(
      email: newEmail,
      username: newEmail,
      fullName: fullName,
      firstName: cleanFirst,
      middleName: cleanMiddle,
      lastName: cleanLast,
      birthday: birthday,
      parentGuardianRelationship: relsSummary,
      linkedStudentId: targetStudentIds.first,
    );
  }

  Future<void> updateParent({
    required String parentId,
    required String firstName,
    String? middleName,
    required String lastName,
    required String relationship,
    String? studentId,
  }) async {
    final cleanMiddleName = AppValidators.normalizeMiddleInitial(middleName);
    await _client
        .from('parent_profiles')
        .update({
          'first_name': firstName,
          'middle_name': cleanMiddleName,
          'last_name': lastName,
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
    AppDataCache.instance.invalidatePrefix('teacher_parents_');
  }

  Future<void> setArchived(
    String parentId,
    bool archived, {
    String? currentStatusHint,
  }) async {
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
        final statusToSave =
            (currentStatus != null &&
                currentStatus.isNotEmpty &&
                currentStatus != 'archived')
            ? currentStatus
            : (currentStatusHint ?? 'active');

        await _client
            .from('parent_profiles')
            .update({'previous_status': statusToSave, 'status': 'archived'})
            .eq('parent_id', parentId);
      } else {
        final cur = await _client
            .from('parent_profiles')
            .select('previous_status')
            .eq('parent_id', parentId)
            .maybeSingle();
        final prev = cur?['previous_status']?.toString();
        final targetStatus =
            (prev != null && prev.isNotEmpty && prev != 'archived')
            ? prev
            : 'active';

        await _client
            .from('parent_profiles')
            .update({'status': targetStatus, 'previous_status': null})
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
    AppDataCache.instance.invalidatePrefix('teacher_parents_');
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

  /// Fetches a student's enrolled subject offerings along with real teacher profile
  /// and public contact settings from `teacher_profiles`, `users`, and `teacher_settings`.
  Future<List<Map<String, dynamic>>> getEnrolledOfferingsWithTeachersForStudent(
    String studentId,
  ) async {
    if (studentId.trim().isEmpty) return [];
    try {
      final rawEnrollments = await _client
          .from('student_enrollments')
          .select('''
            subject_offerings!inner (
              id,
              teacher_id,
              ww_weight,
              pt_weight,
              ex_weight,
              terms_taught,
              term_block,
              subjects ( id, subject_name, subject_code, grade_level ),
              sections ( id, section_name, grade_level ),
              teacher_profiles ( teacher_id, first_name, middle_name, last_name, gender )
            )
          ''')
          .eq('student_id', studentId)
          .ilike('status', 'enrolled');

      final offerings = (rawEnrollments as List)
          .map((row) => Map<String, dynamic>.from(row as Map))
          .map((row) {
            final off = row['subject_offerings'];
            if (off is Map<String, dynamic>) {
              return Map<String, dynamic>.from(off);
            }
            if (off is Map) return Map<String, dynamic>.from(off);
            return <String, dynamic>{};
          })
          .where((offering) => offering.isNotEmpty)
          .toList();

      if (offerings.isEmpty) return [];

      final teacherIds = <String>{};
      for (final off in offerings) {
        final tid = off['teacher_id']?.toString().trim() ?? '';
        if (tid.isNotEmpty) teacherIds.add(tid);
        final tp = off['teacher_profiles'];
        if (tp is Map) {
          final tpId = tp['teacher_id']?.toString().trim() ?? '';
          if (tpId.isNotEmpty) teacherIds.add(tpId);
        }
      }

      final teacherEmails = <String, String>{};
      final teacherSettingsMap = <String, Map<String, dynamic>>{};

      if (teacherIds.isNotEmpty) {
        final idList = teacherIds.toList();
        try {
          final usersResp = await _client
              .from('users')
              .select('id, email')
              .filter('id', 'in', idList);
          for (final u in (usersResp as List)) {
            final uid = u['id']?.toString();
            final em = u['email']?.toString();
            if (uid != null && em != null) {
              teacherEmails[uid] = em;
            }
          }
        } catch (e) {
          debugPrint('Teacher email lookup notice: $e');
        }

        try {
          final settingsResp = await _client
              .from('teacher_settings')
              .select(
                'teacher_id, contact_number, is_phone_public, facebook_link, is_facebook_public, consultation_hours, subject_specialization',
              )
              .filter('teacher_id', 'in', idList);
          for (final ts in (settingsResp as List)) {
            final tid = ts['teacher_id']?.toString();
            if (tid != null) {
              teacherSettingsMap[tid] = Map<String, dynamic>.from(ts as Map);
            }
          }
        } catch (e) {
          debugPrint('Teacher settings lookup notice: $e');
        }
      }

      for (final off in offerings) {
        final rawTp = off['teacher_profiles'];
        final tp = rawTp is Map
            ? Map<String, dynamic>.from(rawTp)
            : <String, dynamic>{};
        final tid =
            tp['teacher_id']?.toString().trim() ??
            off['teacher_id']?.toString().trim() ??
            '';

        if (tid.isNotEmpty) {
          tp['teacher_id'] = tid;
          if (teacherEmails.containsKey(tid)) {
            tp['email'] = teacherEmails[tid];
          }
          final ts = teacherSettingsMap[tid];
          if (ts != null) {
            final isPhonePublic = ts['is_phone_public'] == true;
            final isFacebookPublic = ts['is_facebook_public'] == true;
            tp['is_phone_public'] = isPhonePublic;
            tp['contact_number'] = isPhonePublic
                ? ts['contact_number']?.toString()
                : null;
            tp['is_facebook_public'] = isFacebookPublic;
            tp['facebook_link'] = isFacebookPublic
                ? ts['facebook_link']?.toString()
                : null;
            tp['consultation_hours'] = ts['consultation_hours']?.toString();
            tp['subject_specialization'] = ts['subject_specialization']
                ?.toString();
          }
        }
        off['teacher_profiles'] = tp;
      }

      return offerings;
    } catch (e) {
      debugPrint('Error fetching enrolled offerings with teachers: $e');
      return [];
    }
  }

  /// Fetches all linked parents/guardians for a given student so the student
  /// can see who is linked to their account before toggling 18+ grade privacy.
  Future<List<Map<String, dynamic>>> getLinkedParentsForStudent(
    String studentId,
  ) async {
    if (studentId.trim().isEmpty) return [];
    try {
      final linksResp = await _client
          .from('parent_student_links')
          .select('''
            parent_id,
            relationship,
            parent_profiles!inner (
              parent_id,
              first_name,
              middle_name,
              last_name,
              status
            )
          ''')
          .eq('student_id', studentId);

      if ((linksResp as List).isEmpty) return [];

      final parentIds = (linksResp as List)
          .map((r) => r['parent_id']?.toString())
          .whereType<String>()
          .toSet()
          .toList();

      final emailByParentId = <String, String>{};
      if (parentIds.isNotEmpty) {
        try {
          final usersResp = await _client
              .from('users')
              .select('id, email, is_archived')
              .filter('id', 'in', parentIds);
          for (final u in (usersResp as List)) {
            if (u['is_archived'] == true) continue;
            final pid = u['id']?.toString();
            final em = u['email']?.toString();
            if (pid != null && em != null) {
              emailByParentId[pid] = em;
            }
          }
        } catch (_) {}
      }

      final parents = <Map<String, dynamic>>[];
      for (final row in (linksResp as List)) {
        final pid = row['parent_id']?.toString() ?? '';
        final profile = row['parent_profiles'] as Map<String, dynamic>? ?? {};
        final fullName = [
          profile['first_name'],
          profile['middle_name'],
          profile['last_name'],
        ].where((n) => n != null && n.toString().trim().isNotEmpty).join(' ');

        parents.add({
          'parentId': pid,
          'fullName': fullName.isNotEmpty ? fullName : 'Parent / Guardian',
          'relationship': row['relationship']?.toString() ?? 'Guardian',
          'email': emailByParentId[pid] ?? '',
        });
      }
      return parents;
    } catch (e) {
      debugPrint('Error fetching linked parents for student: $e');
      return [];
    }
  }

  /// Reads the student's 18+ grade privacy toggles from `student_settings` (with local cache fallback).
  Future<Map<String, bool>> getStudentGradePrivacySettings(
    String studentId,
  ) async {
    final local = LocalStorageService.getStudentGradePrivacy(studentId);
    if (studentId.trim().isEmpty) {
      return {'hideTermGrades': false, 'hideFinalGrades': false};
    }

    try {
      final resp = await _client
          .from('student_settings')
          .select(
            'hide_term_grades_from_parent, hide_final_grades_from_parent',
          )
          .eq('student_id', studentId)
          .maybeSingle();
      if (resp != null) {
        final hideTerm = resp['hide_term_grades_from_parent'] == true;
        final hideFinal = resp['hide_final_grades_from_parent'] == true;
        await LocalStorageService.saveStudentGradePrivacy(
          studentId,
          hideTermGrades: hideTerm,
          hideFinalGrades: hideFinal,
        );
        return {'hideTermGrades': hideTerm, 'hideFinalGrades': hideFinal};
      }
    } catch (e) {
      debugPrint('Student grade privacy DB read fallback: $e');
    }

    return {
      'hideTermGrades': local?['hideTermGrades'] ?? false,
      'hideFinalGrades': local?['hideFinalGrades'] ?? false,
    };
  }

  /// Updates the student's 18+ grade privacy toggles in `student_settings` and invalidates parent caches.
  Future<void> updateStudentGradePrivacySettings({
    required String studentId,
    required bool hideTermGrades,
    required bool hideFinalGrades,
  }) async {
    if (studentId.trim().isEmpty) return;

    await LocalStorageService.saveStudentGradePrivacy(
      studentId,
      hideTermGrades: hideTermGrades,
      hideFinalGrades: hideFinalGrades,
    );

    try {
      await _client
          .from('student_settings')
          .update({
            'hide_term_grades_from_parent': hideTermGrades,
            'hide_final_grades_from_parent': hideFinalGrades,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('student_id', studentId);
    } catch (e) {
      debugPrint('Student grade privacy DB update notice: $e');
    }

    AppDataCache.instance.invalidatePrefix('parent_linked_students_');
    AppDataCache.instance.invalidatePrefix('parent_child_grades_');
    AppDataCache.instance.invalidatePrefix('parent_student_overview_data_');
    AppDataCache.instance.invalidate('student_dashboard_$studentId');
  }

  /// Fetches the parent/guardian's own live profile from `public.parent_profiles`
  /// and `public.users`.
  Future<UserModel?> getParentProfile(String parentId) async {
    if (parentId.trim().isEmpty) return null;
    try {
      final results = await Future.wait<dynamic>([
        _client
            .from('parent_profiles')
            .select(
              'parent_id, first_name, middle_name, last_name, birthday, status',
            )
            .eq('parent_id', parentId)
            .maybeSingle(),
        _client
            .from('users')
            .select('id, email, is_archived')
            .eq('id', parentId)
            .maybeSingle(),
      ]);

      final profile = results[0] as Map<String, dynamic>?;
      final userRow = results[1] as Map<String, dynamic>?;
      if (profile == null && userRow == null) return null;

      final firstName = profile?['first_name']?.toString().trim() ?? '';
      final middleName = profile?['middle_name']?.toString().trim();
      final lastName = profile?['last_name']?.toString().trim() ?? '';
      final email = userRow?['email']?.toString().trim() ?? '';
      final birthdayStr = profile?['birthday']?.toString();
      final statusStr = profile?['status']?.toString();
      final isArchived = userRow?['is_archived'] == true;

      final fullName = [
        firstName,
        if (middleName != null && middleName.isNotEmpty) middleName,
        lastName,
      ].where((s) => s.isNotEmpty).join(' ');

      return UserModel(
        id: parentId,
        username: email.isNotEmpty ? email : parentId,
        email: email,
        fullName: fullName.isNotEmpty ? fullName : email,
        firstName: firstName.isNotEmpty ? firstName : null,
        middleName: (middleName != null && middleName.isNotEmpty)
            ? middleName
            : null,
        lastName: lastName.isNotEmpty ? lastName : null,
        birthday: birthdayStr != null ? DateTime.tryParse(birthdayStr) : null,
        role: UserRole.parent,
        status: _parseParentStatus(statusStr, isArchived: isArchived),
        isArchived: isArchived,
      );
    } catch (e) {
      debugPrint('Error fetching parent profile from Supabase: $e');
      return null;
    }
  }

  /// Fetches the student's real weekly schedules directly from their enrolled
  /// `subject_offerings` in `public.student_enrollments` -> `public.teacher_schedule`,
  /// falling back to `fallbackSection` if needed.
  Future<List<ScheduleModel>> getSchedulesForStudent(
    String studentId, {
    String? fallbackSection,
  }) async {
    if (studentId.trim().isEmpty) {
      if (fallbackSection != null && fallbackSection.trim().isNotEmpty) {
        return SupabaseScheduleRepository.instance.getSchedules(
          section: fallbackSection.trim(),
        );
      }
      return [];
    }

    try {
      final enrollResp = await _client
          .from('student_enrollments')
          .select('subject_offering_id')
          .eq('student_id', studentId)
          .ilike('status', 'enrolled');

      final offeringIds = (enrollResp as List)
          .map((r) => r['subject_offering_id']?.toString())
          .whereType<String>()
          .where((id) => id.isNotEmpty)
          .toSet()
          .toList();

      if (offeringIds.isNotEmpty) {
        final schedResp = await _client
            .from('teacher_schedule')
            .select('''
              id, day_of_week, start_time, end_time, room, is_active,
              subject_offerings!inner (
                id, teacher_id, ww_weight, pt_weight, ex_weight,
                subjects ( id, subject_name, grade_level ),
                sections ( id, section_name, grade_level )
              )
            ''')
            .filter('subject_offering_id', 'in', offeringIds)
            .order('day_of_week')
            .order('start_time');

        final list = <ScheduleModel>[];
        for (final row in (schedResp as List)) {
          final offering =
              row['subject_offerings'] as Map<String, dynamic>? ?? {};
          final sub = offering['subjects'] as Map<String, dynamic>? ?? {};
          final sec = offering['sections'] as Map<String, dynamic>? ?? {};

          final subName = sub['subject_name']?.toString() ?? 'Subject';
          final secName = sec['section_name']?.toString() ?? 'Section';
          final dayIndex = row['day_of_week'] is int
              ? row['day_of_week'] as int
              : int.tryParse(row['day_of_week']?.toString() ?? '1') ?? 1;

          list.add(
            ScheduleModel(
              id: row['id'].toString(),
              subject: subName,
              section: secName,
              room: row['room']?.toString() ?? '',
              dayOfWeek: ScheduleModel.dayFromIndex(dayIndex),
              startTime: ScheduleModel.formatTime24to12(
                row['start_time']?.toString() ?? '08:00:00',
              ),
              endTime: ScheduleModel.formatTime24to12(
                row['end_time']?.toString() ?? '09:00:00',
              ),
              sectionId: sec['id']?.toString() ?? secName,
              subjectId: sub['id']?.toString(),
              teacherId: offering['teacher_id']?.toString(),
              gradeLevel: sub['grade_level'] is int
                  ? sub['grade_level'] as int
                  : null,
              wwWeight: (offering['ww_weight'] as num?)?.toDouble() ?? 20.0,
              ptWeight: (offering['pt_weight'] as num?)?.toDouble() ?? 50.0,
              exWeight: (offering['ex_weight'] as num?)?.toDouble() ?? 30.0,
            ),
          );
        }
        if (list.isNotEmpty) return list;
      }
    } catch (e) {
      debugPrint('Error fetching schedules by student enrollments: $e');
    }

    if (fallbackSection != null && fallbackSection.trim().isNotEmpty) {
      return SupabaseScheduleRepository.instance.getSchedules(
        section: fallbackSection.trim(),
      );
    }
    return [];
  }

  /// Verifies the parent's current password and updates their password in
  /// Firebase Authentication and local storage.
  /// Returns `null` on success, or an error map `{'field': 'current'|'new', 'message': '...'}`.
  Future<Map<String, String>?> changeParentPassword({
    required UserModel parent,
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      final fbUser = firebase_auth.FirebaseAuth.instance.currentUser;
      final email = (fbUser?.email?.trim().isNotEmpty == true)
          ? fbUser!.email!.trim()
          : parent.email.trim();

      if (email.isEmpty) {
        return {
          'field': 'current',
          'message': 'Unable to verify parent account email. Please re-login.',
        };
      }

      if (fbUser != null) {
        try {
          final cred = firebase_auth.EmailAuthProvider.credential(
            email: email,
            password: currentPassword,
          );
          await fbUser.reauthenticateWithCredential(cred);
        } on firebase_auth.FirebaseAuthException catch (e) {
          if (e.code == 'wrong-password' ||
              e.code == 'invalid-credential' ||
              e.code == 'user-mismatch') {
            return {
              'field': 'current',
              'message': 'Current password is incorrect.',
            };
          }
          return {
            'field': 'current',
            'message': e.message ?? 'Could not verify current password.',
          };
        }
      }

      bool updated = false;
      if (fbUser != null) {
        try {
          await fbUser.updatePassword(newPassword);
          updated = true;
        } catch (_) {}
      }

      if (!updated) {
        updated = await FirebaseAuthAdminService.updateUserPassword(
          uid: parent.id,
          newPassword: newPassword,
        );
      }

      if (!updated) {
        return {
          'field': 'new',
          'message': 'Failed to update password. Please try again.',
        };
      }

      try {
        await _client
            .from('parent_profiles')
            .update({'status': 'active'})
            .eq('parent_id', parent.id);
      } catch (_) {}

      await LocalStorageService.updateSavedPasswordIfRemembered(
        newPassword,
        forEmail: email,
      );
      return null;
    } catch (e) {
      return {
        'field': 'new',
        'message': e.toString().replaceFirst('Exception: ', ''),
      };
    }
  }
}
