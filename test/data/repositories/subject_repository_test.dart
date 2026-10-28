import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:class_realm/core/services/local_storage_service.dart';
import 'package:class_realm/data/repositories/subject_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const teacherId = 'teacher-uuid';
  const subjectId = 'subject-uuid';
  const schoolYearId = 'school-year-uuid';
  const termId = 'term-uuid';
  const existingOfferingId = 'existing-offering-uuid';
  const existingSectionId = 'existing-section-uuid';
  const newSectionId = 'new-section-uuid';

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalStorageService.init();
  });

  Future<({SubjectRepository repository, List<http.Request> requests})>
  createRepository({required bool sectionAlreadyExists}) async {
    final requests = <http.Request>[];
    final client = SupabaseClient(
      'https://unit-test.supabase.co',
      'test-anon-key',
      httpClient: MockClient((request) async {
        final httpRequest = request;
        requests.add(httpRequest);
        final path = httpRequest.url.path;

        if (httpRequest.method == 'GET' && path.endsWith('/school_years')) {
          return http.Response(
            jsonEncode([
              {'id': schoolYearId},
            ]),
            200,
            headers: {'content-type': 'application/json'},
            request: httpRequest,
          );
        }
        if (httpRequest.method == 'GET' && path.endsWith('/terms')) {
          return http.Response(
            jsonEncode([
              {'id': termId},
            ]),
            200,
            headers: {'content-type': 'application/json'},
            request: httpRequest,
          );
        }
        if (httpRequest.method == 'GET' &&
            path.endsWith('/sections') &&
            httpRequest.url.queryParameters.containsKey('section_name')) {
          return http.Response(
            jsonEncode(
              sectionAlreadyExists
                  ? [
                      {'id': newSectionId},
                    ]
                  : <Map<String, String>>[],
            ),
            200,
            headers: {'content-type': 'application/json'},
            request: httpRequest,
          );
        }
        if (httpRequest.method == 'GET' &&
            path.endsWith('/subject_offerings') &&
            httpRequest.url.queryParameters.containsKey('id')) {
          return http.Response(
            jsonEncode([
              {'section_id': existingSectionId},
            ]),
            200,
            headers: {'content-type': 'application/json'},
            request: httpRequest,
          );
        }
        if (httpRequest.method == 'GET' &&
            path.endsWith('/subject_offerings')) {
          return http.Response(
            '[]',
            200,
            headers: {'content-type': 'application/json'},
            request: httpRequest,
          );
        }
        if (httpRequest.method == 'POST' && path.endsWith('/sections')) {
          return http.Response(
            jsonEncode({'id': newSectionId}),
            201,
            headers: {'content-type': 'application/json'},
            request: httpRequest,
          );
        }
        if (httpRequest.method == 'POST' &&
            path.endsWith('/subject_offerings')) {
          return http.Response('', 201, request: httpRequest);
        }
        if (httpRequest.method == 'PATCH') {
          return http.Response('', 204, request: httpRequest);
        }

        fail('Unexpected Supabase request: ${httpRequest.method} $path');
      }),
    );

    return (repository: SubjectRepository(client: client), requests: requests);
  }

  Future<void> updateSubject(
    SubjectRepository repository, {
    required List<Map<String, dynamic>> sections,
  }) {
    return repository.updateSubjectAndSections(
      teacherId: teacherId,
      subjectId: subjectId,
      subjectName: 'Mathematics',
      gradeLevel: 'Grade 11',
      wwWeight: 20,
      ptWeight: 50,
      exWeight: 30,
      termsTaught: 3,
      termBlock: '1ST, 2ND, 3RD',
      unitsPerTerm: 2,
      st1Weight: 30,
      st2Weight: 30,
      teWeight: 40,
      sections: sections,
    );
  }

  test(
    'inserts a new section when the draft ID uses the row- format',
    () async {
      final setup = await createRepository(sectionAlreadyExists: false);

      await updateSubject(
        setup.repository,
        sections: [
          {
            'id': 'row-1730000000000-1',
            'name': 'Section 2',
            'isExisting': false,
          },
        ],
      );

      final sectionInsert = setup.requests.singleWhere(
        (request) =>
            request.method == 'POST' && request.url.path.endsWith('/sections'),
      );
      final offeringInsert = setup.requests.singleWhere(
        (request) =>
            request.method == 'POST' &&
            request.url.path.endsWith('/subject_offerings'),
      );
      final offeringData =
          jsonDecode(offeringInsert.body) as Map<String, dynamic>;

      expect(jsonDecode(sectionInsert.body), {
        'section_name': 'Section 2',
        'grade_level': 11,
        'school_year_id': schoolYearId,
        'is_archived': false,
      });
      expect(offeringData['subject_id'], subjectId);
      expect(offeringData['section_id'], newSectionId);
      expect(offeringData['teacher_id'], teacherId);
      expect(offeringData['term_id'], termId);
      expect(
        setup.requests.any(
          (request) =>
              request.method == 'GET' &&
              request.url.path.endsWith('/subject_offerings') &&
              request.url.queryParameters['id'] == 'eq.row-1730000000000-1',
        ),
        isFalse,
      );
    },
  );

  test('updates an existing section using its offering ID', () async {
    final setup = await createRepository(sectionAlreadyExists: true);

    await updateSubject(
      setup.repository,
      sections: [
        {
          'id': existingOfferingId,
          'name': 'Section 1 Updated',
          'isExisting': true,
        },
      ],
    );

    final offeringLookup = setup.requests.singleWhere(
      (request) =>
          request.method == 'GET' &&
          request.url.path.endsWith('/subject_offerings') &&
          request.url.queryParameters.containsKey('id'),
    );
    final sectionUpdate = setup.requests.singleWhere(
      (request) =>
          request.method == 'PATCH' && request.url.path.endsWith('/sections'),
    );

    expect(offeringLookup.url.queryParameters['id'], 'eq.$existingOfferingId');
    expect(offeringLookup.url.queryParameters['teacher_id'], 'eq.$teacherId');
    expect(offeringLookup.url.queryParameters['subject_id'], 'eq.$subjectId');
    expect(sectionUpdate.url.queryParameters['id'], 'eq.$existingSectionId');
    expect(jsonDecode(sectionUpdate.body), {
      'section_name': 'Section 1 Updated',
      'grade_level': 11,
    });
    expect(
      setup.requests.any(
        (request) =>
            request.method == 'POST' &&
            request.url.path.endsWith('/subject_offerings'),
      ),
      isFalse,
    );
  });

  test(
    'rejects stale existing section IDs instead of treating them as drafts',
    () async {
      final requests = <http.Request>[];
      final client = SupabaseClient(
        'https://unit-test.supabase.co',
        'test-anon-key',
        httpClient: MockClient((request) async {
          final httpRequest = request;
          requests.add(httpRequest);
          final path = httpRequest.url.path;

          if (httpRequest.method == 'GET' && path.endsWith('/school_years')) {
            return http.Response(
              jsonEncode([
                {'id': schoolYearId},
              ]),
              200,
              headers: {'content-type': 'application/json'},
              request: httpRequest,
            );
          }
          if (httpRequest.method == 'GET' && path.endsWith('/terms')) {
            return http.Response(
              jsonEncode([
                {'id': termId},
              ]),
              200,
              headers: {'content-type': 'application/json'},
              request: httpRequest,
            );
          }
          if (httpRequest.method == 'GET' &&
              path.endsWith('/subject_offerings') &&
              httpRequest.url.queryParameters.containsKey('id')) {
            return http.Response(
              '[]',
              200,
              headers: {'content-type': 'application/json'},
              request: httpRequest,
            );
          }
          if (httpRequest.method == 'PATCH') {
            return http.Response('', 204, request: httpRequest);
          }

          fail('Unexpected Supabase request: ${httpRequest.method} $path');
        }),
      );
      final repository = SubjectRepository(client: client);

      await expectLater(
        updateSubject(
          repository,
          sections: [
            {'id': existingOfferingId, 'name': 'Section 1', 'isExisting': true},
          ],
        ),
        throwsA(isA<StateError>()),
      );
      expect(requests.any((request) => request.method == 'POST'), isFalse);
    },
  );
}
