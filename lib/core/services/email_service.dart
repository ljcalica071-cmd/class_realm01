import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class EmailDeliveryException implements Exception {
  final String message;
  const EmailDeliveryException(this.message);

  @override
  String toString() => message;
}

class EmailService {
  static final EmailService instance = EmailService._internal();
  EmailService._internal();

  /// Pure Dart Universal Email Sender (HTTPS REST based)
  /// Compatible across Flutter Web, Android, iOS, Windows, macOS.
  Future<bool> sendEmail({
    required String to,
    required String subject,
    required String html,
  }) async {
    final cleanRecipient = to.trim();

    // 1. Dispatch via Supabase send-email Edge Function (Nodemailer Gmail SMTP)
    final supabaseUrl = dotenv.env['SUPABASE_URL'];
    final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'];
    if (supabaseUrl != null && supabaseUrl.isNotEmpty && supabaseAnonKey != null) {
      try {
        final url = Uri.parse('$supabaseUrl/functions/v1/send-email');
        final response = await http.post(
          url,
          headers: {
            'Content-Type': 'application/json',
            'apikey': supabaseAnonKey,
            'Authorization': 'Bearer $supabaseAnonKey',
          },
          body: jsonEncode({
            'to': cleanRecipient,
            'subject': subject,
            'html': html,
            'smtp_user': (dotenv.env['SMTP_EMAIL'] != null &&
                    dotenv.env['SMTP_EMAIL'] != 'ljcalica071@gmail.com')
                ? dotenv.env['SMTP_EMAIL']!
                : 'classrealm1@gmail.com',
            'smtp_pass': (dotenv.env['SMTP_PASSWORD'] != null &&
                    dotenv.env['SMTP_PASSWORD'] != 'wowtgfoenxnxewnl' &&
                    dotenv.env['SMTP_PASSWORD'] != 'whbmzbcnbaphwoho')
                ? dotenv.env['SMTP_PASSWORD']!
                : 'hkcgzoavuszbefie',
          }),
        );

        if (response.statusCode >= 200 && response.statusCode < 300) {
          try {
            final data = jsonDecode(response.body);
            if (data is Map && data['success'] == true) {
              debugPrint('[EmailService] Dispatched via Supabase Edge Function to $cleanRecipient');
              return true;
            } else if (data is Map && data['error'] != null) {
              throw EmailDeliveryException(_formatDeliveryError(cleanRecipient, data['error'].toString()));
            }
          } catch (e) {
            if (e is EmailDeliveryException) rethrow;
          }
          return true;
        } else {
          String rawError = response.body;
          try {
            final data = jsonDecode(response.body);
            if (data is Map && data['error'] != null) {
              rawError = data['error'].toString();
            }
          } catch (_) {}
          debugPrint('[EmailService] Supabase Edge Function error (${response.statusCode}): $rawError');
          throw EmailDeliveryException(_formatDeliveryError(cleanRecipient, rawError));
        }
      } on EmailDeliveryException {
        rethrow;
      } catch (e) {
        debugPrint('[EmailService] Supabase send-email error: $e');
        if (e is EmailDeliveryException) rethrow;
        throw EmailDeliveryException(_formatDeliveryError(cleanRecipient, e.toString()));
      }
    }

    // 2. Try Resend REST API (if configured)
    final resendApiKey = dotenv.env['RESEND_API_KEY'];
    if (resendApiKey != null && resendApiKey.trim().isNotEmpty) {
      try {
        final res = await http.post(
          Uri.parse('https://api.resend.com/emails'),
          headers: {
            'Authorization': 'Bearer ${resendApiKey.trim()}',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'from': dotenv.env['EMAIL_FROM'] ?? 'ClassRealm <onboarding@resend.dev>',
            'to': [cleanRecipient],
            'subject': subject,
            'html': html,
          }),
        );
        if (res.statusCode >= 200 && res.statusCode < 300) {
          debugPrint('[EmailService] Dispatched via Resend API to $cleanRecipient');
          return true;
        }
      } catch (e) {
        debugPrint('[EmailService] Resend API error: $e');
      }
    }

    // 3. Try Brevo / Sendinblue REST API (if configured)
    final brevoApiKey = dotenv.env['BREVO_API_KEY'];
    if (brevoApiKey != null && brevoApiKey.trim().isNotEmpty) {
      try {
        final res = await http.post(
          Uri.parse('https://api.brevo.com/v3/smtp/email'),
          headers: {
            'api-key': brevoApiKey.trim(),
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'sender': {'name': 'ClassRealm', 'email': dotenv.env['SMTP_EMAIL'] ?? 'noreply@classrealm.edu'},
            'to': [{'email': cleanRecipient}],
            'subject': subject,
            'htmlContent': html,
          }),
        );
        if (res.statusCode >= 200 && res.statusCode < 300) {
          debugPrint('[EmailService] Dispatched via Brevo API to $cleanRecipient');
          return true;
        }
      } catch (e) {
        debugPrint('[EmailService] Brevo API error: $e');
      }
    }

    throw EmailDeliveryException(
      "Unable to deliver email to '$cleanRecipient'. Please check if the email address exists and is active.",
    );
  }

  static String _formatDeliveryError(String email, String rawError) {
    final lower = rawError.toLowerCase();
    if (lower.contains('535') ||
        lower.contains('badcredentials') ||
        lower.contains('username and password not accepted')) {
      final sender = (dotenv.env['SMTP_EMAIL'] != null &&
              dotenv.env['SMTP_EMAIL'] != 'ljcalica071@gmail.com')
          ? dotenv.env['SMTP_EMAIL']!
          : 'classrealm1@gmail.com';
      return "Gmail SMTP Error (535 Bad Credentials): Google rejected the App Password for sender account ($sender). If you recently changed the account password or updated 2FA, please generate a fresh 16-character App Password at myaccount.google.com/apppasswords.";
    }
    if (lower.contains('daily user sending limit exceeded') ||
        lower.contains('sending limit') ||
        lower.contains('550-5.4.5') ||
        lower.contains('550 5.4.5')) {
      return "Google Gmail daily sending limit reached for the sender account. Google resets this after 24 hours. Please try again later.";
    }
    if (lower.contains('blocked') ||
        lower.contains('suspicious') ||
        lower.contains('message not delivered')) {
      return "Delivery to '$email' was blocked or rejected by mail provider (Message not delivered). Check the email address.";
    }
    if (lower.contains('address not found') ||
        lower.contains('couldn\'t be found') ||
        lower.contains('wasn\'t delivered') ||
        lower.contains('unable to receive mail') ||
        lower.contains('not found')) {
      return "The email address '$email' was not found (Address not found). Check for typos and try again.";
    }
    if (lower.contains('enotfound') ||
        lower.contains('getaddrinfo') ||
        lower.contains('domain does not exist') ||
        lower.contains('550 5.1.2') ||
        lower.contains('unrouteable') ||
        lower.contains('recipient address rejected')) {
      return "The email domain for '$email' does not exist or rejected delivery.";
    }
    if (lower.contains('user unknown') ||
        lower.contains('550 5.1.1') ||
        lower.contains('mailbox unavailable') ||
        lower.contains('no such user')) {
      return "The mailbox for '$email' does not exist (Address not found).";
    }
    if (rawError.trim().isNotEmpty &&
        !rawError.trim().startsWith('{') &&
        !rawError.trim().startsWith('<')) {
      return rawError.trim();
    }
    return "Failed to deliver verification code to '$email'. Please verify that the email address exists.";
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
        
        <p style="font-size: 13px; color: #94a3b8; text-align: center; margin: 0;">This code will expire in 10 minutes. If you did not request this, please contact the administrator immediately.</p>
      </div>
    ''';

    return await sendEmail(
      to: recipientEmail,
      subject: 'ClassRealm - Security Verification Code',
      html: htmlTemplate,
    );
  }

  /// Send student credentials
  static Future<void> sendStudentCredentials({
    required String recipientEmail,
    required String studentName,
    required String studentId,
    required String tempPassword,
  }) async {
    final String htmlTemplate = '''
      <div style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto; background: #ffffff; padding: 24px; border-radius: 12px; border: 1px solid #e2e8f0;">
        <h2 style="color: #1e3a5f;">Welcome to ClassRealm, $studentName!</h2>
        <p style="color: #334155; font-size: 15px;">Your student account has been successfully created by your teacher.</p>
        <p style="color: #334155; font-size: 15px;">Below are your temporary login details. Please log in to complete your account setup and change your password.</p>
        <br>
        <div style="background-color: #f8fafc; padding: 18px; border-radius: 8px; border: 1px solid #cbd5e1;">
          <p style="margin: 6px 0;"><strong>Email / Username:</strong> $recipientEmail</p>
          <p style="margin: 6px 0;"><strong>LRN / Student ID:</strong> $studentId</p>
          <p style="margin: 6px 0;"><strong>Temporary Password:</strong> <code style="font-weight: bold; color: #2563eb;">$tempPassword</code></p>
        </div>
        <br>
        <p style="font-size: 13px; color: #64748b;"><em>This is an automated message. Please keep your credentials secure.</em></p>
      </div>
    ''';

    await EmailService.instance.sendEmail(
      to: recipientEmail,
      subject: 'Welcome to ClassRealm: Your Student Credentials',
      html: htmlTemplate,
    );
  }

  /// Send teacher verification code
  Future<bool> sendTeacherVerificationCode({
    required String recipientEmail,
    required String teacherName,
    required String code,
  }) async {
    final String htmlTemplate = '''
      <div style="font-family: Arial, sans-serif; max-width: 500px; margin: 20px auto; padding: 24px; border: 1px solid #e2e8f0; border-radius: 12px; background: #ffffff;">
        <h2 style="color: #1e3a5f; margin-top: 0;">Teacher Account Verification</h2>
        <p>Hello <strong>$teacherName</strong>,</p>
        <p>Your 6-digit verification OTP code for ClassRealm teacher setup is:</p>
        <div style="background: #f1f5f9; padding: 18px; text-align: center; font-size: 32px; font-weight: bold; letter-spacing: 8px; color: #2563eb; border-radius: 8px; margin: 20px 0;">
          $code
        </div>
        <div style="background: #fef3c7; border: 1px solid #f59e0b; border-radius: 8px; padding: 12px 16px; margin: 20px 0;">
          <p style="margin: 0; color: #92400e; font-size: 13px; font-weight: bold;">
            ⏳ Notice: This verification OTP code is valid for 10 minutes only.
          </p>
          <p style="margin: 4px 0 0 0; color: #b45309; font-size: 12px;">
            The cooldown for resending is 1 minute.
          </p>
        </div>
        <p style="font-size: 12px; color: #64748b; margin-top: 16px;">Do not share this code with anyone. If you did not request this, please disregard this email.</p>
        <hr style="border: none; border-top: 1px solid #e2e8f0; margin: 16px 0;" />
        <p style="font-size: 11px; color: #94a3b8; margin: 0;">Eduardo Barretto Sr. Integrated School — ClassRealm</p>
      </div>
    ''';

    return await sendEmail(
      to: recipientEmail,
      subject: 'ClassRealm - Teacher Verification Code (Valid for 10 minutes)',
      html: htmlTemplate,
    );
  }

  /// Send teacher temporary credentials welcome email
  Future<bool> sendTeacherWelcomeEmail({
    required String recipientEmail,
    required String teacherName,
    required String tempPassword,
  }) async {
    final String htmlTemplate = '''
      <div style="font-family: Arial, sans-serif; max-width: 520px; margin: 20px auto; padding: 26px; border: 1px solid #e2e8f0; border-radius: 12px; background: #ffffff;">
        <h2 style="color: #1e3a5f; margin-top: 0; font-size: 22px; font-weight: bold;">Welcome to ClassRealm!</h2>
        <p style="font-size: 15px; color: #334155; margin-bottom: 8px;">Hello <strong>$teacherName</strong>,</p>
        <p style="font-size: 14px; color: #475569; line-height: 1.6; margin-top: 0;">Your teacher account for <strong>Eduardo Barretto Sr. Integrated School</strong> is ready. Use these credentials to sign in:</p>
        
        <div style="background: #f8fafc; border: 1px solid #cbd5e1; border-radius: 10px; padding: 18px 20px; margin: 20px 0;">
          <div style="margin-bottom: 12px;">
            <span style="font-size: 11px; font-weight: 700; text-transform: uppercase; letter-spacing: 0.8px; color: #64748b; display: block; margin-bottom: 4px;">Email Address</span>
            <span style="font-size: 15px; font-weight: 600; color: #1e293b; font-family: monospace;">$recipientEmail</span>
          </div>
          <div>
            <span style="font-size: 11px; font-weight: 700; text-transform: uppercase; letter-spacing: 0.8px; color: #64748b; display: block; margin-bottom: 4px;">Temporary Password</span>
            <code style="font-size: 18px; font-weight: 700; color: #2563eb; background: #eff6ff; border: 1px solid #bfdbfe; padding: 5px 12px; border-radius: 6px; letter-spacing: 1px; display: inline-block; font-family: monospace;">$tempPassword</code>
          </div>
        </div>

        <div style="background: #fef3c7; border: 1px solid #f59e0b; border-radius: 8px; padding: 12px 16px; margin: 20px 0;">
          <p style="margin: 0; color: #92400e; font-size: 13px; font-weight: bold;">
            🔒 Notice: First-Time Password Change Required
          </p>
          <p style="margin: 4px 0 0 0; color: #b45309; font-size: 12px;">
            For your security, you will be required to set a new password the first time you sign in.
          </p>
        </div>

        <p style="font-size: 12px; color: #64748b; margin-top: 16px;">Please keep these credentials secure. Do not share your temporary password with unauthorized individuals.</p>
        <hr style="border: none; border-top: 1px solid #e2e8f0; margin: 18px 0;" />
        <p style="font-size: 11px; color: #94a3b8; margin: 0; text-align: center;">Eduardo Barretto Sr. Integrated School — ClassRealm</p>
      </div>
    ''';

    return await sendEmail(
      to: recipientEmail,
      subject: 'Welcome to ClassRealm - Teacher Account Credentials',
      html: htmlTemplate,
    );
  }
}
