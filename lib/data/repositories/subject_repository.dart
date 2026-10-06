import 'package:supabase_flutter/supabase_flutter.dart';

class SubjectRepository {
  final SupabaseClient _client;

  SubjectRepository({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  static final SubjectRepository instance = SubjectRepository();

  /// Saves a subject along with multiple sections. 
  /// Each section becomes a new row in the subjects table.
  Future<void> saveSubjects({
    required String teacherId,
    required String subjectName,
    required String gradeLevel,
    required double wwWeight,
    required double ptWeight,
    required double exWeight,
    required List<String> sectionNames,
    String schoolYear = '2026-2027',
  }) async {
    // Determine integer grade level from string like 'Grade 11'
    int gLevel = 11;
    if (gradeLevel.contains('12')) {
      gLevel = 12;
    }

    final List<Map<String, dynamic>> rowsToInsert = sectionNames.map((sectionName) {
      return {
        'teacher_id': teacherId,
        'subject_name': subjectName,
        'grade_level': gLevel,
        'section_name': sectionName,
        'ww_weight': wwWeight,
        'pt_weight': ptWeight,
        'ex_weight': exWeight,
        'school_year': schoolYear,
      };
    }).toList();

    await _client.from('subjects').insert(rowsToInsert);
  }

  /// Fetches all subjects for a specific teacher.
  Future<List<Map<String, dynamic>>> getTeacherSubjects(String teacherId, {String schoolYear = '2026-2027'}) async {
    final response = await _client
        .from('subjects')
        .select('*')
        .eq('teacher_id', teacherId)
        .eq('school_year', schoolYear)
        .order('subject_name')
        .order('section_name');
        
    return List<Map<String, dynamic>>.from(response);
  }
  
  /// Archive/Delete subject logic can be added here if needed
}
