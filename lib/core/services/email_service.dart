import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class EmailService {
  static final EmailService instance = EmailService._internal();
  EmailService._internal();

  Future<bool> _invokeEdgeFunction(String to, String subject, String html) async {
    final String? supabaseUrlRaw = dotenv.env['SUPABASE_URL'];
    final String? supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'];

    if (supabaseUrlRaw == null || supabaseAnonKey == null) {
      print("EmailService Error: SUPABASE_URL or SUPABASE_ANON_KEY is not configured in .env");
      return false;
    }

    final String supabaseUrl = supabaseUrlRaw.endsWith('/') 
        ? supabaseUrlRaw.substring(0, supabaseUrlRaw.length - 1) 
        : supabaseUrlRaw;

    final String edgeFunctionUrl = '$supabaseUrl/functions/v1/send-email';

    try {
      final response = await http.post(
        Uri.parse(edgeFunctionUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $supabaseAnonKey',
        },
        body: jsonEncode({
          'to': to,
          'subject': subject,
          'html': html,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        print('Email successfully dispatched via Edge Function to $to.');
        return true;
      } else {
        print('Edge Function Error: ${response.body}');
        return false;
      }
    } catch (e) {
      print('HTTP Email transmission error: $e');
      return false;
    }
  }

  /// Send an official approval email using the Supabase Edge Function
  Future<bool> sendApprovalEmail({
    required String recipientEmail,
    required String tempPassword,
    String recipientName = 'Educator',
  }) async {
    final String htmlTemplate = '''
      <div style="font-family: Arial, sans-serif; color: #333; line-height: 1.6; max-width: 600px; margin: 0 auto; border: 1px solid #ddd; border-radius: 8px; padding: 20px;">
        <h2 style="color: #2b6cb0; text-align: center;">Welcome to ClassRealm</h2>
        <p>Dear <strong>$recipientName</strong>,</p>
        <p>We are pleased to inform you that your account registration has been <strong>approved</strong> by the ClassRealm Admin.</p>
        <p>You may now log in to the ClassRealm portal using the credentials below:</p>
        <div style="background-color: #f7fafc; padding: 15px; border-radius: 5px; margin: 20px 0;">
          <p style="margin: 0;"><strong>Email:</strong> $recipientEmail</p>
          <p style="margin: 0;"><strong>Temporary Password:</strong> <span style="font-family: monospace; font-size: 16px; color: #e53e3e;">$tempPassword</span></p>
        </div>
        <p><em>Note: For security purposes, please change your password immediately upon your first log-in.</em></p>
        <p>Thank you,<br><strong>ClassRealm Admin</strong></p>
      </div>
    ''';

    return await _invokeEdgeFunction(recipientEmail, 'ClassRealm Account Approved', htmlTemplate);
  }

  /// Send a formal rejection email to a teacher
  Future<bool> sendRejectionEmail({
    required String recipientEmail,
    String recipientName = 'Educator',
  }) async {
    final String htmlTemplate = '''
      <div style="font-family: Arial, sans-serif; color: #333; line-height: 1.6; max-width: 600px; margin: 0 auto; border: 1px solid #ddd; border-radius: 8px; padding: 20px;">
        <h2 style="color: #c53030; text-align: center;">Registration Update</h2>
        <p>Dear <strong>$recipientName</strong>,</p>
        <p>We regret to inform you that your account registration for ClassRealm has been <strong>declined</strong> by the ClassRealm Admin.</p>
        <p>If you believe this is a mistake or if you need further clarification, please contact the ClassRealm Admin.</p>
        <p>Contact link: <a href="https://www.facebook.com/lj.calica.01?rdid=tRXKPs3qcRpmL7Pr&share_url=https%3A%2F%2Fwww.facebook.com%2Fshare%2F19NycWuYoZ%2F#">Contact ClassRealm</a></p>
        <p>Thank you,<br><strong>ClassRealm Admin</strong></p>
      </div>
    ''';

    return await _invokeEdgeFunction(recipientEmail, 'ClassRealm Registration Update', htmlTemplate);
  }

  /// Send a simple notification to the Admin that a teacher was approved
  Future<bool> sendAdminNotificationEmail({
    required String adminEmail,
    required String teacherName,
    required String teacherEmail,
    bool isRejection = false,
  }) async {
    final String htmlTemplate = '''
      <div style="font-family: Arial, sans-serif; color: #333;">
        <h2>ClassRealm Notification</h2>
        <p>A teacher account for <strong>$teacherName</strong> ($teacherEmail) was just ${isRejection ? 'declined' : 'approved'}.</p>
      </div>
    ''';

    return await _invokeEdgeFunction(adminEmail, 'ClassRealm Admin Update', htmlTemplate);
  }

  /// Send an OTP verification email for new teacher registration
  Future<bool> sendRegistrationOtpEmail({
    required String recipientEmail,
    required String recipientName,
    required String otpCode,
  }) async {
    final String htmlTemplate = '''
      <div style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; color: #1a1a1a; line-height: 1.6; max-width: 500px; margin: 40px auto; border: 1px solid #eaeaea; border-radius: 16px; padding: 32px; box-shadow: 0 4px 24px rgba(0,0,0,0.04);">
        <div style="text-align: center; margin-bottom: 32px;">
          <h2 style="color: #0f172a; font-size: 24px; font-weight: 700; margin: 0;">Verify your email</h2>
        </div>
        <p style="font-size: 15px; color: #475569; margin-bottom: 24px;">Hello <strong>$recipientName</strong>,</p>
        <p style="font-size: 15px; color: #475569; margin-bottom: 32px;">Thank you for registering at ClassRealm. To complete your registration, please enter the 6-digit verification code below in the application.</p>
        
        <div style="background-color: #f8fafc; border-radius: 12px; padding: 24px; text-align: center; margin-bottom: 32px; border: 1px solid #e2e8f0;">
          <span style="font-family: ui-monospace, SFMono-Regular, Consolas, monospace; font-size: 32px; font-weight: 800; letter-spacing: 8px; color: #2563eb;">$otpCode</span>
        </div>
        
        <p style="font-size: 13px; color: #94a3b8; text-align: center; margin: 0;">This code will expire in 5 minutes. If you did not request this, please ignore this email.</p>
      </div>
    ''';

    return await _invokeEdgeFunction(recipientEmail, 'ClassRealm - Verification Code', htmlTemplate);
  }

  /// Send an OTP verification email for first login password change
  Future<bool> sendPasswordChangeOtpEmail({
    required String recipientEmail,
    required String recipientName,
    required String otpCode,
  }) async {
    final String htmlTemplate = '''
      <div style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; color: #1a1a1a; line-height: 1.6; max-width: 500px; margin: 40px auto; border: 1px solid #eaeaea; border-radius: 16px; padding: 32px; box-shadow: 0 4px 24px rgba(0,0,0,0.04);">
        <div style="text-align: center; margin-bottom: 32px;">
          <h2 style="color: #0f172a; font-size: 24px; font-weight: 700; margin: 0;">Verify your password change</h2>
        </div>
        <p style="font-size: 15px; color: #475569; margin-bottom: 24px;">Hello <strong>$recipientName</strong>,</p>
        <p style="font-size: 15px; color: #475569; margin-bottom: 32px;">To complete your first login and secure your account, please enter the 6-digit verification code below to confirm your new password.</p>
        
        <div style="background-color: #f8fafc; border-radius: 12px; padding: 24px; text-align: center; margin-bottom: 32px; border: 1px solid #e2e8f0;">
          <span style="font-family: ui-monospace, SFMono-Regular, Consolas, monospace; font-size: 32px; font-weight: 800; letter-spacing: 8px; color: #2563eb;">$otpCode</span>
        </div>
        
        <p style="font-size: 13px; color: #94a3b8; text-align: center; margin: 0;">This code will expire in 5 minutes. If you did not request this, please contact the administrator immediately.</p>
      </div>
    ''';

    return await _invokeEdgeFunction(recipientEmail, 'ClassRealm - Security Verification Code', htmlTemplate);
  }

  /// Send student credentials
  static Future<void> sendStudentCredentials({
    required String recipientEmail,
    required String studentName,
    required String studentId,
    required String tempPassword,
  }) async {
    final String htmlTemplate = '''
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
        <h2>Welcome to ClassRealm, $studentName!</h2>
        <p>Your student account has been successfully created by your teacher.</p>
        <p>Below are your temporary credentials. Please log in to complete your account setup and change your password.</p>
        <br>
        <div style="background-color: #f3f4f6; padding: 16px; border-radius: 8px;">
          <p><strong>Email / Username:</strong> $recipientEmail</p>
          <p><strong>LRN / Student ID:</strong> $studentId</p>
          <p><strong>Temporary Password:</strong> $tempPassword</p>
        </div>
        <br>
        <p>Login Portal: <a href="http://localhost:54343">http://localhost:54343</a></p>
        <p><em>This is an automated message. Please do not reply.</em></p>
      </div>
    ''';

    await EmailService.instance._invokeEdgeFunction(recipientEmail, 'Welcome to ClassRealm: Your Student Credentials', htmlTemplate);
  }
}
