import 'package:flutter/material.dart';
import 'package:class_realm/core/utils/validators.dart';

/// Reusable checklist showing real-time password requirements.
class PasswordRequirementsChecklist extends StatelessWidget {
  final bool hasMinLength;
  final bool hasUpper;
  final bool hasLower;
  final bool hasNumber;
  final bool? passwordsMatch;

  const PasswordRequirementsChecklist({
    super.key,
    required this.hasMinLength,
    required this.hasUpper,
    required this.hasLower,
    required this.hasNumber,
    this.passwordsMatch,
  });

  factory PasswordRequirementsChecklist.fromResult(
    PasswordValidationResult result, {
    Key? key,
    bool includeMatch = false,
  }) {
    return PasswordRequirementsChecklist(
      key: key,
      hasMinLength: result.hasMinLength,
      hasUpper: result.hasUpper,
      hasLower: result.hasLower,
      hasNumber: result.hasNumber,
      passwordsMatch: includeMatch ? result.passwordsMatch : null,
    );
  }

  Widget _buildRow(String text, bool isValid) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(
            isValid ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
            size: 16,
            color: isValid ? const Color(0xFF16A34A) : const Color(0xFF94A3B8),
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: isValid ? const Color(0xFF15803D) : const Color(0xFF475569),
              fontWeight: isValid ? FontWeight.w500 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildRow('At least 8 characters', hasMinLength),
          _buildRow('At least one uppercase letter', hasUpper),
          _buildRow('At least one lowercase letter', hasLower),
          _buildRow('At least one number', hasNumber),
          if (passwordsMatch != null)
            _buildRow('Passwords match', passwordsMatch!),
        ],
      ),
    );
  }
}
