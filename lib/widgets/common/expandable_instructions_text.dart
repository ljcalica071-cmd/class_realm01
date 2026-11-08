import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:class_realm/core/utils/validators.dart';

/// Displays classwork/assessment instructions clamped to [collapsedMaxLines] (default 2)
/// with an interactive "See more" / "See less" toggle when the text exceeds 2 lines.
/// Used across both Teacher View and Student View (Online & In-Person).
class ExpandableInstructionsText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final int collapsedMaxLines;
  final Color? toggleColor;

  const ExpandableInstructionsText({
    super.key,
    required this.text,
    this.style,
    this.collapsedMaxLines = 2,
    this.toggleColor,
  });

  @override
  State<ExpandableInstructionsText> createState() =>
      _ExpandableInstructionsTextState();
}

class _ExpandableInstructionsTextState
    extends State<ExpandableInstructionsText> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final trimmed = widget.text.trim();
    if (trimmed.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final effectiveStyle =
        widget.style ??
        theme.textTheme.bodyMedium ??
        TextStyle(
          fontSize: 13,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
        );
    final linkColor = widget.toggleColor ?? theme.colorScheme.primary;

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : 420.0;
        final textPainter = TextPainter(
          text: TextSpan(text: trimmed, style: effectiveStyle),
          maxLines: widget.collapsedMaxLines,
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout(maxWidth: maxWidth);

        final exceedsLines =
            textPainter.didExceedMaxLines ||
            '\n'.allMatches(trimmed).length >= widget.collapsedMaxLines ||
            trimmed.length > 110;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              trimmed,
              maxLines: _isExpanded ? null : widget.collapsedMaxLines,
              overflow: _isExpanded
                  ? TextOverflow.visible
                  : TextOverflow.ellipsis,
              style: effectiveStyle,
            ),
            if (exceedsLines)
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: InkWell(
                  onTap: () => setState(() => _isExpanded = !_isExpanded),
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 1),
                    child: Text(
                      _isExpanded ? 'See less' : 'See more',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: linkColor,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// A 0/1000 instructions input field that stays compact at 2 lines by default
/// and provides a "See more" / "See less" toggle when long text is entered,
/// plus inline validation requiring 2 to 1,000 non-space characters.
class ExpandableInstructionsInputField extends StatefulWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final String? errorText;
  final FormFieldValidator<String>? validator;
  final ValueChanged<String>? onChanged;
  final AutovalidateMode? autovalidateMode;

  const ExpandableInstructionsInputField({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
    this.errorText,
    this.validator,
    this.onChanged,
    this.autovalidateMode,
  });

  @override
  State<ExpandableInstructionsInputField> createState() =>
      _ExpandableInstructionsInputFieldState();
}

class _ExpandableInstructionsInputFieldState
    extends State<ExpandableInstructionsInputField> {
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleControllerChanged);
  }

  @override
  void didUpdateWidget(covariant ExpandableInstructionsInputField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_handleControllerChanged);
      widget.controller.addListener(_handleControllerChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleControllerChanged);
    super.dispose();
  }

  void _handleControllerChanged() {
    if (mounted) setState(() {});
  }

  bool get _canExpand {
    final text = widget.controller.text;
    return text.length > 85 || '\n'.allMatches(text).length >= 2;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final charCount = widget.controller.text.length;
    final canExpand = _canExpand;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                widget.label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
            if (canExpand)
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: InkWell(
                  onTap: () => setState(() => _isExpanded = !_isExpanded),
                  borderRadius: BorderRadius.circular(4),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 2,
                    ),
                    child: Text(
                      _isExpanded ? 'See less' : 'See more',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                ),
              ),
            Text(
              '$charCount/${AppValidators.maxClassworkInstructionsLength}',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: charCount > AppValidators.maxClassworkInstructionsLength
                    ? const Color(0xFFDC2626)
                    : theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: widget.controller,
          minLines: 2,
          maxLines: (_isExpanded && canExpand) ? 6 : 2,
          maxLength: AppValidators.maxClassworkInstructionsLength,
          autovalidateMode: widget.autovalidateMode,
          inputFormatters: [
            LengthLimitingTextInputFormatter(
              AppValidators.maxClassworkInstructionsLength,
            ),
          ],
          buildCounter:
              (
                _, {
                required currentLength,
                required isFocused,
                maxLength,
              }) => const SizedBox.shrink(),
          onChanged: (val) {
            widget.onChanged?.call(val);
            setState(() {});
          },
          validator: widget.validator,
          style: const TextStyle(fontSize: 13),
          decoration: InputDecoration(
            hintText: widget.hint,
            hintStyle: TextStyle(
              fontSize: 13,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.38),
            ),
            filled: true,
            fillColor: theme.colorScheme.surface,
            contentPadding: const EdgeInsets.all(12),
            errorText: widget.errorText,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: widget.errorText != null
                    ? const Color(0xFFDC2626)
                    : theme.colorScheme.outline.withValues(alpha: 0.3),
                width: widget.errorText != null ? 1.5 : 1.0,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide(
                color: widget.errorText != null
                    ? const Color(0xFFDC2626)
                    : theme.colorScheme.primary,
                width: 1.5,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(
                color: Color(0xFFDC2626),
                width: 1.5,
              ),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(
                color: Color(0xFFDC2626),
                width: 2.0,
              ),
            ),
            errorStyle: const TextStyle(
              fontSize: 12,
              color: Color(0xFFDC2626),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
