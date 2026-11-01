import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppTextField extends StatelessWidget {
  final String label;
  final String? hint;
  final TextStyle? hintStyle;
  final TextEditingController? controller;
  final bool obscureText;
  final bool readOnly;
  final bool enabled;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final String? Function(String?)? validator;
  final int maxLines;
  final int? maxLength;
  final bool showCounter;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final List<TextInputFormatter>? inputFormatters;
  final void Function(String)? onChanged;
  final AutovalidateMode? autovalidateMode;

  const AppTextField({
    super.key,
    required this.label,
    this.hint,
    this.hintStyle,
    this.controller,
    this.obscureText = false,
    this.readOnly = false,
    this.enabled = true,
    this.prefixIcon,
    this.suffixIcon,
    this.validator,
    this.maxLines = 1,
    this.maxLength,
    this.showCounter = false,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.inputFormatters,
    this.onChanged,
    this.autovalidateMode,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveHintStyle = hintStyle ??
        TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.normal,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.38),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label.isNotEmpty) ...[
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 6),
        ],
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          readOnly: readOnly,
          enabled: enabled,
          maxLines: maxLines,
          maxLength: maxLength,
          buildCounter: showCounter
              ? (
                  context, {
                  required currentLength,
                  required isFocused,
                  required maxLength,
                }) =>
                    Text(
                      '$currentLength/$maxLength',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: currentLength >= (maxLength ?? 0)
                            ? const Color(0xFFEF4444)
                            : theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    )
              : (maxLength != null
                  ? (context, {required currentLength, required isFocused, required maxLength}) => null
                  : null),
          keyboardType: keyboardType,
          textCapitalization: textCapitalization,
          inputFormatters: inputFormatters,
          onChanged: onChanged,
          validator: validator,
          autovalidateMode: autovalidateMode,
          style: TextStyle(fontSize: 14, color: theme.colorScheme.onSurface),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: effectiveHintStyle,
            errorMaxLines: 3,
            prefixIcon: prefixIcon != null ? Icon(prefixIcon, size: 20, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)) : null,
            suffixIcon: suffixIcon,
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFEF4444), width: 1.5),
            ),
            errorStyle: const TextStyle(
              fontSize: 12,
              color: Color(0xFFEF4444),
            ),
          ),
        ),
      ],
    );
  }
}
