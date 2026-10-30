import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:class_realm/data/repositories/supabase_student_repository.dart';
import 'package:class_realm/core/services/firebase_auth_admin_service.dart';

// IMPORTANT: You need to initialize Supabase and Firebase before running this in a real environment.
// This is a standalone script structure.

void main() async {
  debugPrint('Starting Student Population Script...');
  
  // NOTE: You must have initialized Supabase.initialize(...) and Firebase.initializeApp(...) 
  // in your main app before this repository can work.
  // Assuming the client is available globally or passed in:
  final supabase = Supabase.instance.client;
  final studentRepo = SupabaseStudentRepository(client: supabase);

  // 1. Find Teacher Naruto Uzumaki's ID
  final teacherRes = await supabase
      .from('users')
      .select('id')
      .eq('email', 'rexanjuan24@gmail.com') // Wait, in your screenshot, Naruto isn't there, but let's assume we find him by name or you hardcode it.
      .limit(1)
      .maybeSingle();
      
  // For the sake of this script, you will need to replace these with the actual IDs 
  // if the auto-fetch fails, because I cannot see your live Supabase data.
  String section1OfferingId = 'REPLACE_WITH_SECTION_1_OFFERING_ID'; 
  String section2OfferingId = 'REPLACE_WITH_SECTION_2_OFFERING_ID';

  /* 
  // Code to auto-fetch if you know exactly how subjects/sections are named in your DB:
  final offeringsRes = await supabase
      .from('subject_offerings')
      .select('id, sections!inner(section_name)')
      .eq('teacher_id', teacherId);
      // ... parse to find Section 1 and Section 2
  */

  if (section1OfferingId == 'REPLACE_WITH_SECTION_1_OFFERING_ID') {
    debugPrint('ERROR: You must put the actual subject_offering_ids in the script first!');
    exit(1);
  }

  // Define Students for Section 1
  final section1Students = [
    // Boys
    {'lrn': '120000000101', 'first': 'Aaron', 'middle': 'B.', 'last': 'Santos', 'bday': '2007-01-15', 'gender': 'Male'},
    {'lrn': '120000000102', 'first': 'Bryan', 'middle': 'C.', 'last': 'Reyes', 'bday': '2007-02-20', 'gender': 'Male'},
    {'lrn': '120000000103', 'first': 'Carlos', 'middle': 'D.', 'last': 'Cruz', 'bday': '2006-03-10', 'gender': 'Male'},
    {'lrn': '120000000104', 'first': 'Dennis', 'middle': 'E.', 'last': 'Bautista', 'bday': '2007-04-05', 'gender': 'Male'},
    {'lrn': '120000000105', 'first': 'Erwin', 'middle': 'F.', 'last': 'Ocampo', 'bday': '2007-05-12', 'gender': 'Male'},
    {'lrn': '120000000106', 'first': 'Felix', 'middle': 'G.', 'last': 'Aquino', 'bday': '2006-06-18', 'gender': 'Male'},
    {'lrn': '120000000107', 'first': 'Gabriel', 'middle': 'H.', 'last': 'Garcia', 'bday': '2007-07-25', 'gender': 'Male'},
    {'lrn': '120000000108', 'first': 'Hector', 'middle': 'I.', 'last': 'Mendoza', 'bday': '2006-08-30', 'gender': 'Male'},
    {'lrn': '120000000109', 'first': 'Ian', 'middle': 'J.', 'last': 'Villanueva', 'bday': '2007-09-14', 'gender': 'Male'},
    {'lrn': '120000000110', 'first': 'Justin', 'middle': 'K.', 'last': 'Dela Cruz', 'bday': '2007-10-09', 'gender': 'Male'},
    // Girls
    {'lrn': '120000000111', 'first': 'Anna', 'middle': 'L.', 'last': 'Ramos', 'bday': '2007-01-22', 'gender': 'Female'},
    {'lrn': '120000000112', 'first': 'Bea', 'middle': 'M.', 'last': 'Castro', 'bday': '2007-02-14', 'gender': 'Female'},
    {'lrn': '120000000113', 'first': 'Chloe', 'middle': 'N.', 'last': 'Roxas', 'bday': '2006-03-28', 'gender': 'Female'},
    {'lrn': '120000000114', 'first': 'Diana', 'middle': 'O.', 'last': 'Mercado', 'bday': '2007-04-16', 'gender': 'Female'},
    {'lrn': '120000000115', 'first': 'Elena', 'middle': 'P.', 'last': 'Villanueva', 'bday': '2007-05-08', 'gender': 'Female'},
    {'lrn': '120000000116', 'first': 'Fiona', 'middle': 'Q.', 'last': 'Aguilar', 'bday': '2006-06-02', 'gender': 'Female'},
    {'lrn': '120000000117', 'first': 'Grace', 'middle': 'R.', 'last': 'Gonzales', 'bday': '2007-07-19', 'gender': 'Female'},
    {'lrn': '120000000118', 'first': 'Hanna', 'middle': 'S.', 'last': 'Lopez', 'bday': '2006-08-11', 'gender': 'Female'},
    {'lrn': '120000000119', 'first': 'Iris', 'middle': 'T.', 'last': 'Perez', 'bday': '2007-09-05', 'gender': 'Female'},
    {'lrn': '120000000120', 'first': 'Julia', 'middle': 'U.', 'last': 'Domingo', 'bday': '2007-10-31', 'gender': 'Female'},
  ];

  // Define Students for Section 2
  final section2Students = [
    {'lrn': '120000000201', 'first': 'Kevin', 'middle': 'V.', 'last': 'Tolentino', 'bday': '2007-11-15', 'gender': 'Male'},
    {'lrn': '120000000202', 'first': 'Luis', 'middle': 'W.', 'last': 'Pascual', 'bday': '2006-12-04', 'gender': 'Male'},
    {'lrn': '120000000203', 'first': 'Mia', 'middle': 'X.', 'last': 'Navarro', 'bday': '2007-11-20', 'gender': 'Female'},
    {'lrn': '120000000204', 'first': 'Nina', 'middle': 'Y.', 'last': 'Alonzo', 'bday': '2006-12-25', 'gender': 'Female'},
  ];

  Future<void> enrollBatch(List<Map<String, String>> students, String offeringId) async {
    for (var s in students) {
      // Generate email and password formats
      final cleanFirst = s['first']!.toLowerCase().replaceAll(' ', '');
      final cleanLast = s['last']!.toLowerCase().replaceAll(' ', '');
      final email = '$cleanFirst.$cleanLast.cr@gmail.com';
      
      debugPrint('Enrolling ${s['first']} ${s['last']} ($email)...');
      
      try {
        await studentRepo.enrollStudent(
          lrn: s['lrn']!,
          firstName: s['first']!,
          middleName: s['middle']!,
          lastName: s['last']!,
          birthday: DateTime.parse(s['bday']!),
          email: email,
          gender: s['gender']!,
          subjectId: offeringId,
          skipEmail: true, // Don't spam real emails if somehow they exist
        );
        
        // Since enrollStudent in your repo creates the user in Firebase and Supabase but sets status to 'pending_first_login',
        // we need to manually force the status to 'active' for this test data.
        
        // Find the student_id by LRN
        final profileRes = await supabase.from('student_profiles').select('student_id').eq('lrn', s['lrn']!).maybeSingle();
        if (profileRes != null) {
          final studentId = profileRes['student_id'];
          // Force active status
          await supabase.from('student_settings').update({'status': 'active'}).eq('student_id', studentId);
          debugPrint('Successfully enrolled and activated ${s['first']} ${s['last']}.');
        }

      } catch (e) {
        debugPrint('Failed to enroll ${s['first']}: $e');
      }
    }
  }

  debugPrint('--- Starting Section 1 ---');
  await enrollBatch(section1Students, section1OfferingId);
  
  debugPrint('--- Starting Section 2 ---');
  await enrollBatch(section2Students, section2OfferingId);

  debugPrint('Done!');
  exit(0);
}
