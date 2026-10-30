import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;

Future<void> main() async {
  print('Loading env...');
  final envFile = File('.env');
  final lines = envFile.readAsLinesSync();
  final env = <String, String>{};
  for (var line in lines) {
    if (line.trim().isEmpty || line.startsWith('#')) continue;
    final parts = line.split('=');
    if (parts.length >= 2) {
      final key = parts[0].trim();
      final value = parts.sublist(1).join('=').trim().replaceAll('"', '');
      env[key] = value;
    }
  }

  final supabaseUrl = env['SUPABASE_URL']!;
  final serviceRoleKey = env['SUPABASE_SERVICE_ROLE_KEY']!;
  final firebaseApiKey = env['FIREBASE_WEB_API_KEY']!;

  Future<dynamic> supaPost(String table, Map<String, dynamic> body) async {
    final res = await http.post(
      Uri.parse('$supabaseUrl/rest/v1/$table'),
      headers: {
        'apikey': serviceRoleKey,
        'Authorization': 'Bearer $serviceRoleKey',
        'Content-Type': 'application/json',
        'Prefer': 'resolution=merge-duplicates'
      },
      body: jsonEncode(body),
    );
    if (res.statusCode >= 400) {
      print('SupaPost Error ${res.statusCode} in $table: ${res.body}');
    }
  }

  Future<String?> createFirebaseUser(String email, String password) async {
    final fbRes = await http.post(
      Uri.parse('https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=$firebaseApiKey'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
        'returnSecureToken': true,
      }),
    );
    if (fbRes.statusCode == 200) {
      final fbData = jsonDecode(fbRes.body);
      return fbData['localId']?.toString();
    } else {
      print('Firebase Error: ${fbRes.body}');
      return null;
    }
  }

  final section1OfferingId = 'd28fbca1-bbbe-478d-8c41-682391a37461';
  final section2OfferingId = 'b0292c4a-77ae-44dd-bd25-a23a0593e7ba';

  final section1Students = [
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

  final section2Students = [
    {'lrn': '120000000201', 'first': 'Kevin', 'middle': 'V.', 'last': 'Tolentino', 'bday': '2007-11-15', 'gender': 'Male'},
    {'lrn': '120000000202', 'first': 'Luis', 'middle': 'W.', 'last': 'Pascual', 'bday': '2006-12-04', 'gender': 'Male'},
    {'lrn': '120000000203', 'first': 'Mia', 'middle': 'X.', 'last': 'Navarro', 'bday': '2007-11-20', 'gender': 'Female'},
    {'lrn': '120000000204', 'first': 'Nina', 'middle': 'Y.', 'last': 'Alonzo', 'bday': '2006-12-25', 'gender': 'Female'},
  ];

  Future<void> enrollBatch(List<Map<String, String>> students, String offeringId) async {
    for (var s in students) {
      final cleanFirst = s['first']!.toLowerCase().replaceAll(' ', '');
      final cleanLast = s['last']!.toLowerCase().replaceAll(' ', '');
      final email = '$cleanFirst.$cleanLast.cr@gmail.com';
      
      // Capitalize first letter of last name, lowercase rest, remove spaces, append 123
      final rawLast = s['last']!.replaceAll(' ', '');
      final password = '${rawLast[0].toUpperCase()}${rawLast.substring(1).toLowerCase()}123';
      
      print('Processing ${s['first']} ${s['last']}...');
      
      final uid = await createFirebaseUser(email, password);
      if (uid == null) {
        print('Skipping ${s['first']} due to Firebase error.');
        continue;
      }

      await supaPost('users', {
        'id': uid,
        'email': email,
        'role': 'student',
        'is_archived': false
      });

      await supaPost('student_profiles', {
        'student_id': uid,
        'lrn': s['lrn'],
        'first_name': s['first'],
        'middle_name': s['middle'],
        'last_name': s['last'],
        'gender': s['gender'],
        'birthday': s['bday'],
      });

      await supaPost('student_settings', {
        'student_id': uid,
        'status': 'active'
      });

      await supaPost('student_enrollments', {
        'student_id': uid,
        'subject_offering_id': offeringId,
        'status': 'enrolled'
      });
      print(' -> Inserted successfully!');
    }
  }

  print('=== Section 1 ===');
  await enrollBatch(section1Students, section1OfferingId);
  
  print('=== Section 2 ===');
  await enrollBatch(section2Students, section2OfferingId);
  
  print('Finished!');
}
