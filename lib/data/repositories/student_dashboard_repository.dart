import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:class_realm/core/services/supabase_service.dart';
import 'package:class_realm/models/student_dashboard_models.dart';

class StudentDashboardRepository {
  StudentDashboardRepository._();

  static final StudentDashboardRepository instance =
      StudentDashboardRepository._();

  Future<StudentDashboardData> loadDashboard() async {
    final authUser = firebase_auth.FirebaseAuth.instance.currentUser;
    if (authUser == null) {
      throw Exception('Please sign in again to load your student dashboard.');
    }

    final token = await authUser.getIdToken();
    if (token == null || token.isEmpty) {
      throw Exception('Your sign-in session could not be verified.');
    }

    final response = await SupabaseService().client.functions.invoke(
      'student-dashboard',
      headers: {
        'x-firebase-token': token,
        'x-firebase-api-key':
            firebase_auth.FirebaseAuth.instance.app.options.apiKey,
      },
      body: const {},
    );
    if (response.data is! Map) {
      throw Exception(
        'Student dashboard service returned an unexpected response.',
      );
    }

    final data = Map<String, dynamic>.from(response.data as Map);
    if (data['error'] != null) {
      throw Exception(data['error'].toString());
    }
    return StudentDashboardData.fromJson(data);
  }
}
