import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:class_realm/core/config/env_config.dart';

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
    bool skipBounceCheck = false,
  }) async {
    final cleanRecipient = to.trim();
    final lower = cleanRecipient.toLowerCase();

    // Handle test/example addresses gracefully
    if (lower.endsWith('@example.com') ||
        lower.endsWith('@test.com') ||
        lower.endsWith('@sample.com') ||
        lower == 'example@gmail.com') {
      debugPrint(
        '[EmailService] Test/example recipient ($cleanRecipient) - delivery simulated successfully.',
      );
      return true;
    }

    // 1. Dispatch via Supabase send-email Edge Function (Nodemailer Gmail SMTP)
    final supabaseUrl = EnvConfig.supabaseUrl;
    final supabaseAnonKey = EnvConfig.supabaseAnonKey;
    final smtpUser = EnvConfig.smtpEmail;
    final smtpPass = EnvConfig.smtpPassword;

    if (supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty) {
      if (smtpUser.isEmpty || smtpPass.isEmpty) {
        throw const EmailDeliveryException(
          'SMTP credentials are not configured in .env. Please set SMTP_EMAIL and SMTP_PASSWORD.',
        );
      }
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
            'smtp_user': smtpUser,
            'smtp_pass': smtpPass,
            'skip_bounce_check': skipBounceCheck,
          }),
        );

        if (response.statusCode >= 200 && response.statusCode < 300) {
          try {
            final data = jsonDecode(response.body);
            if (data is Map && data['success'] == true) {
              debugPrint(
                '[EmailService] Dispatched via Supabase Edge Function to $cleanRecipient',
              );
              return true;
            } else if (data is Map && data['error'] != null) {
              throw EmailDeliveryException(
                _formatDeliveryError(cleanRecipient, data['error'].toString()),
              );
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
          debugPrint(
            '[EmailService] Supabase Edge Function error (${response.statusCode}): $rawError',
          );
          throw EmailDeliveryException(
            _formatDeliveryError(cleanRecipient, rawError),
          );
        }
      } on EmailDeliveryException {
        rethrow;
      } catch (e) {
        debugPrint('[EmailService] Supabase send-email error: $e');
        if (e is EmailDeliveryException) rethrow;
        throw EmailDeliveryException(
          _formatDeliveryError(cleanRecipient, e.toString()),
        );
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
            'from':
                dotenv.env['EMAIL_FROM'] ??
                'ClassRealm <onboarding@resend.dev>',
            'to': [cleanRecipient],
            'subject': subject,
            'html': html,
          }),
        );
        if (res.statusCode >= 200 && res.statusCode < 300) {
          debugPrint(
            '[EmailService] Dispatched via Resend API to $cleanRecipient',
          );
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
            'sender': {
              'name': 'ClassRealm',
              'email': EnvConfig.smtpEmail.isNotEmpty
                  ? EnvConfig.smtpEmail
                  : 'noreply@classrealm.edu',
            },
            'to': [
              {'email': cleanRecipient},
            ],
            'subject': subject,
            'htmlContent': html,
          }),
        );
        if (res.statusCode >= 200 && res.statusCode < 300) {
          debugPrint(
            '[EmailService] Dispatched via Brevo API to $cleanRecipient',
          );
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
      final sender = EnvConfig.smtpEmail.isNotEmpty
          ? EnvConfig.smtpEmail
          : 'SMTP account';
      return "App Password Expired: The system rejected the email credentials for ($sender). Please contact ClassRealm Admin to generate a fresh App Password at myaccount.google.com/apppasswords.";
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
    final String htmlTemplate =
        '''
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

    return await sendEmail(
      to: recipientEmail,
      subject: 'ClassRealm - Security Verification Code',
      html: htmlTemplate,
    );
  }

  /// Send student temporary credentials welcome email (matching teacher welcome email design)
  Future<bool> sendStudentWelcomeEmail({
    required String recipientEmail,
    required String studentName,
    required String tempPassword,
    bool skipBounceCheck = true,
  }) async {
    final cleanRecipient = recipientEmail.trim();
    final String htmlTemplate =
        '''
      <div style="font-family: Arial, sans-serif; max-width: 520px; margin: 20px auto; padding: 26px; border: 1px solid #e2e8f0; border-radius: 12px; background: #ffffff;">
        <h2 style="color: #1e3a5f; margin-top: 0; font-size: 22px; font-weight: bold;">Welcome to ClassRealm!</h2>
        <p style="font-size: 15px; color: #334155; margin-bottom: 8px;">Hello <strong>$studentName</strong>,</p>
        <p style="font-size: 14px; color: #475569; line-height: 1.6; margin-top: 0;">Your student account for <strong>Eduardo Barretto Sr. Integrated School</strong> is ready. Use these credentials to log in to the ClassRealm app:</p>
        
        <div style="background: #f8fafc; border: 1px solid #cbd5e1; border-radius: 10px; padding: 18px 20px; margin: 20px 0;">
          <div style="margin-bottom: 12px;">
            <span style="font-size: 11px; font-weight: 700; text-transform: uppercase; letter-spacing: 0.8px; color: #64748b; display: block; margin-bottom: 4px;">Email Address</span>
            <span style="font-size: 15px; font-weight: 600; color: #1e293b; font-family: monospace;">$cleanRecipient</span>
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
            For your security, you will be required to set a new password the first time you log in.
          </p>
        </div>

        <p style="font-size: 12px; color: #64748b; margin-top: 16px;">Please keep these credentials secure. Do not share your temporary password with unauthorized individuals.</p>
        <hr style="border: none; border-top: 1px solid #e2e8f0; margin: 18px 0;" />
        <p style="font-size: 11px; color: #94a3b8; margin: 0; text-align: center;">Eduardo Barretto Sr. Integrated School — ClassRealm</p>
      </div>
    ''';

    return await sendEmail(
      to: cleanRecipient,
      subject: 'Welcome to ClassRealm - Student Account Credentials',
      html: htmlTemplate,
      skipBounceCheck: skipBounceCheck,
    );
  }

  /// Send student credentials (backward-compatible wrapper)
  static Future<void> sendStudentCredentials({
    required String recipientEmail,
    required String studentName,
    required String studentId,
    required String tempPassword,
  }) async {
    await EmailService.instance.sendStudentWelcomeEmail(
      recipientEmail: recipientEmail,
      studentName: studentName,
      tempPassword: tempPassword,
    );
  }

  /// Send teacher verification code
  Future<bool> sendTeacherVerificationCode({
    required String recipientEmail,
    required String teacherName,
    required String code,
  }) async {
    final String htmlTemplate =
        '''
      <div style="font-family: Arial, sans-serif; max-width: 500px; margin: 20px auto; padding: 24px; border: 1px solid #e2e8f0; border-radius: 12px; background: #ffffff;">
        <h2 style="color: #1e3a5f; margin-top: 0;">Teacher Account Verification</h2>
        <p>Hello <strong>$teacherName</strong>,</p>
        <p>Your 6-digit verification OTP code for ClassRealm teacher setup is:</p>
        <div style="background: #f1f5f9; padding: 18px; text-align: center; font-size: 32px; font-weight: bold; letter-spacing: 8px; color: #2563eb; border-radius: 8px; margin: 20px 0;">
          $code
        </div>
        <div style="background: #fef3c7; border: 1px solid #f59e0b; border-radius: 8px; padding: 12px 16px; margin: 20px 0;">
          <p style="margin: 0; color: #92400e; font-size: 13px; font-weight: bold;">
            ⏳ Notice: This verification OTP code is valid for 5 minutes only.
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
      subject: 'ClassRealm - Teacher Verification Code (Valid for 5 minutes)',
      html: htmlTemplate,
    );
  }

  /// Send teacher temporary credentials welcome email
  Future<bool> sendTeacherWelcomeEmail({
    required String recipientEmail,
    required String teacherName,
    required String tempPassword,
  }) async {
    final String htmlTemplate =
        '''
      <div style="font-family: Arial, sans-serif; max-width: 520px; margin: 20px auto; padding: 26px; border: 1px solid #e2e8f0; border-radius: 12px; background: #ffffff;">
        <h2 style="color: #1e3a5f; margin-top: 0; font-size: 22px; font-weight: bold;">Welcome to ClassRealm!</h2>
        <p style="font-size: 15px; color: #334155; margin-bottom: 8px;">Hello <strong>$teacherName</strong>,</p>
        <p style="font-size: 14px; color: #475569; line-height: 1.6; margin-top: 0;">Your teacher account for <strong>Eduardo Barretto Sr. Integrated School</strong> is ready. Use these credentials to log in:</p>
        
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
            For your security, you will be required to set a new password the first time you log in.
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

  /// Send system maintenance alerts (60-30-10 Minimalist UI/UX Design, Strictly Teacher & Student Gmail Accounts)
  Future<void> sendSystemMaintenanceAlertEmail({
    required List<String> recipientEmails,
    required bool isEnabled,
  }) async {
    final currentYear = DateTime.now().year;
    final String subject = isEnabled
        ? 'ClassRealm Advisory: Scheduled System Maintenance Active'
        : 'ClassRealm Advisory: System Maintenance Complete — Back Online';

    final String htmlTemplate = isEnabled
        ? '''
      <!DOCTYPE html>
      <html lang="en">
      <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Scheduled System Maintenance Active</title>
      </head>
      <body style="margin: 0; padding: 0; background-color: #F8FAFC; font-family: 'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; color: #0F172A; -webkit-font-smoothing: antialiased;">
        <table width="100%" border="0" cellspacing="0" cellpadding="0" style="background-color: #F8FAFC; padding: 36px 16px;">
          <tr>
            <td align="center">
              <table width="100%" border="0" cellspacing="0" cellpadding="0" style="max-width: 580px; background-color: #FFFFFF; border-radius: 14px; border: 1px solid #E2E8F0; overflow: hidden; box-shadow: 0 4px 12px rgba(15, 23, 42, 0.04);">
                <!-- 10% Accent Top Bar (Amber for Maintenance Active) -->
                <tr>
                  <td style="background-color: #F59E0B; height: 5px; line-height: 5px; font-size: 5px;">&nbsp;</td>
                </tr>
                <!-- 30% Brand Header (#3A6B88 Steel-Blue) -->
                <tr>
                  <td style="background-color: #3A6B88; padding: 22px 28px;">
                    <table width="100%" border="0" cellspacing="0" cellpadding="0">
                      <tr>
                        <td>
                          <div style="color: #FFFFFF; font-size: 18px; font-weight: 800; letter-spacing: 0.4px;">CLASSREALM</div>
                          <div style="color: #E0F2FE; font-size: 11px; font-weight: 600; text-transform: uppercase; letter-spacing: 0.8px; margin-top: 2px;">Teacher &amp; Student Portal Advisory</div>
                        </td>
                        <td align="right">
                          <span style="display: inline-block; background-color: #FEF3C7; color: #92400E; border: 1px solid #FDE68A; font-size: 11px; font-weight: 700; padding: 4px 10px; border-radius: 999px; letter-spacing: 0.3px;">
                            MAINTENANCE ACTIVE
                          </span>
                        </td>
                      </tr>
                    </table>
                  </td>
                </tr>
                <!-- Main Body Content -->
                <tr>
                  <td style="padding: 32px 28px; color: #334155;">
                    <h2 style="margin: 0 0 12px 0; color: #0F172A; font-size: 20px; font-weight: 800; letter-spacing: -0.2px;">
                      Scheduled System Maintenance Active
                    </h2>
                    <p style="font-size: 14px; line-height: 1.6; color: #475569; margin: 0 0 20px 0;">
                      Hello Teacher / Student,
                    </p>
                    <p style="font-size: 14px; line-height: 1.65; color: #334155; margin: 0 0 20px 0;">
                      ClassRealm is currently undergoing scheduled maintenance to improve system speed and reliability. While our team applies these updates, access to the Teacher and Student portals is temporarily paused.
                    </p>

                    <!-- Status Summary Box -->
                    <table width="100%" border="0" cellspacing="0" cellpadding="0" style="background-color: #FFFBEB; border: 1px solid #FDE68A; border-left: 4px solid #F59E0B; border-radius: 8px; margin-bottom: 22px;">
                      <tr>
                        <td style="padding: 14px 16px;">
                          <div style="font-size: 12px; font-weight: 700; color: #92400E; text-transform: uppercase; letter-spacing: 0.4px; margin-bottom: 6px;">
                            What You Need to Know
                          </div>
                          <div style="font-size: 13px; color: #78350F; line-height: 1.55;">
                            &bull; <strong>Portal Status:</strong> Temporarily paused for updates<br>
                            &bull; <strong>Your Records:</strong> All grades, attendance logs, and classwork are safely saved<br>
                            &bull; <strong>Next Update:</strong> You will receive an email as soon as the portal is back online
                          </div>
                        </td>
                      </tr>
                    </table>

                    <p style="font-size: 13.5px; line-height: 1.6; color: #64748B; margin: 0;">
                      Thank you for your patience while we keep ClassRealm running smoothly for your classes.
                    </p>
                  </td>
                </tr>
                <!-- Footer -->
                <tr>
                  <td style="background-color: #F8FAFC; padding: 18px 28px; border-top: 1px solid #E2E8F0; text-align: center;">
                    <p style="margin: 0; font-size: 11.5px; color: #64748B; line-height: 1.5;">
                      &copy; $currentYear ClassRealm Academic Portal &bull; Eduardo Barretto Sr. Integrated School<br>
                      This is an automated system advisory sent to registered Teacher and Student accounts.
                    </p>
                  </td>
                </tr>
              </table>
            </td>
          </tr>
        </table>
      </body>
      </html>
    '''
        : '''
      <!DOCTYPE html>
      <html lang="en">
      <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>System Maintenance Complete</title>
      </head>
      <body style="margin: 0; padding: 0; background-color: #F8FAFC; font-family: 'Inter', -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; color: #0F172A; -webkit-font-smoothing: antialiased;">
        <table width="100%" border="0" cellspacing="0" cellpadding="0" style="background-color: #F8FAFC; padding: 36px 16px;">
          <tr>
            <td align="center">
              <table width="100%" border="0" cellspacing="0" cellpadding="0" style="max-width: 580px; background-color: #FFFFFF; border-radius: 14px; border: 1px solid #E2E8F0; overflow: hidden; box-shadow: 0 4px 12px rgba(15, 23, 42, 0.04);">
                <!-- 10% Accent Top Bar (Emerald for System Online) -->
                <tr>
                  <td style="background-color: #059669; height: 5px; line-height: 5px; font-size: 5px;">&nbsp;</td>
                </tr>
                <!-- 30% Brand Header (#3A6B88 Steel-Blue) -->
                <tr>
                  <td style="background-color: #3A6B88; padding: 22px 28px;">
                    <table width="100%" border="0" cellspacing="0" cellpadding="0">
                      <tr>
                        <td>
                          <div style="color: #FFFFFF; font-size: 18px; font-weight: 800; letter-spacing: 0.4px;">CLASSREALM</div>
                          <div style="color: #E0F2FE; font-size: 11px; font-weight: 600; text-transform: uppercase; letter-spacing: 0.8px; margin-top: 2px;">Teacher &amp; Student Portal Advisory</div>
                        </td>
                        <td align="right">
                          <span style="display: inline-block; background-color: #ECFDF5; color: #065F46; border: 1px solid #A7F3D0; font-size: 11px; font-weight: 700; padding: 4px 10px; border-radius: 999px; letter-spacing: 0.3px;">
                            SYSTEM ONLINE
                          </span>
                        </td>
                      </tr>
                    </table>
                  </td>
                </tr>
                <!-- Main Body Content -->
                <tr>
                  <td style="padding: 32px 28px; color: #334155;">
                    <h2 style="margin: 0 0 12px 0; color: #0F172A; font-size: 20px; font-weight: 800; letter-spacing: -0.2px;">
                      System Maintenance Complete — Back Online
                    </h2>
                    <p style="font-size: 14px; line-height: 1.6; color: #475569; margin: 0 0 20px 0;">
                      Hello Teacher / Student,
                    </p>
                    <p style="font-size: 14px; line-height: 1.65; color: #334155; margin: 0 0 20px 0;">
                      Scheduled maintenance is now complete and ClassRealm is back online. All Teacher and Student portal features have been restored and are ready for use.
                    </p>

                    <!-- Status Summary Box -->
                    <table width="100%" border="0" cellspacing="0" cellpadding="0" style="background-color: #ECFDF5; border: 1px solid #A7F3D0; border-left: 4px solid #059669; border-radius: 8px; margin-bottom: 22px;">
                      <tr>
                        <td style="padding: 14px 16px;">
                          <div style="font-size: 12px; font-weight: 700; color: #065F46; text-transform: uppercase; letter-spacing: 0.4px; margin-bottom: 6px;">
                            All Features Restored
                          </div>
                          <div style="font-size: 13px; color: #047857; line-height: 1.55;">
                            &bull; <strong>Portal Status:</strong> Online and ready for login<br>
                            &bull; <strong>Available Services:</strong> Gradebook, Performance Analytics, Attendance, and Classwork<br>
                            &bull; <strong>Data Integrity:</strong> All records and recent updates are synced and intact
                          </div>
                        </td>
                      </tr>
                    </table>

                    <p style="font-size: 13.5px; line-height: 1.6; color: #64748B; margin: 0;">
                      Thank you for your patience. You may now sign in to ClassRealm and continue your activities as normal.
                    </p>
                  </td>
                </tr>
                <!-- Footer -->
                <tr>
                  <td style="background-color: #F8FAFC; padding: 18px 28px; border-top: 1px solid #E2E8F0; text-align: center;">
                    <p style="margin: 0; font-size: 11.5px; color: #64748B; line-height: 1.5;">
                      &copy; $currentYear ClassRealm Academic Portal &bull; Eduardo Barretto Sr. Integrated School<br>
                      This is an automated system advisory sent to registered Teacher and Student accounts.
                    </p>
                  </td>
                </tr>
              </table>
            </td>
          </tr>
        </table>
      </body>
      </html>
    ''';

    // Dispatch emails silently to Teacher & Student Gmail accounts
    for (final email in recipientEmails) {
      if (email.trim().isNotEmpty &&
          email.contains('@') &&
          email.trim().toLowerCase() != 'parent' &&
          email.trim().toLowerCase() != 'teacher' &&
          email.trim().toLowerCase() != 'student') {
        try {
          await sendEmail(to: email, subject: subject, html: htmlTemplate);
          // Slight delay to prevent rate limit spikes
          await Future.delayed(const Duration(milliseconds: 50));
        } catch (e) {
          debugPrint('[MaintenanceEmail] Failed to send to $email: $e');
        }
      }
    }
  }
}
