import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class GradebookGridCell extends StatefulWidget {
  final String value;
  final ValueChanged<String> onChanged;
  final bool isHpsCell;
  final double? columnHps;
  final bool isEnabled;
  final bool isInvalidValue;
  final double width;
  final Color backgroundColor;
  final Color borderColor;
  final Color textColor;
  final String disabledTooltip;

  const GradebookGridCell({
    super.key,
    required this.value,
    required this.onChanged,
    required this.isHpsCell,
    required this.columnHps,
    required this.isEnabled,
    this.isInvalidValue = false,
    required this.width,
    required this.backgroundColor,
    required this.borderColor,
    required this.textColor,
    this.disabledTooltip =
        'Set Highest Possible Score (HPS) for this column first.',
  });

  @override
  State<GradebookGridCell> createState() => _GradebookGridCellState();
}

class _GradebookGridCellState extends State<GradebookGridCell> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
    _focusNode = FocusNode()..addListener(_handleFocusChange);
  }

  @override
  void didUpdateWidget(covariant GradebookGridCell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_focusNode.hasFocus && oldWidget.value != widget.value) {
      _controller.value = TextEditingValue(
        text: widget.value,
        selection: TextSelection.collapsed(offset: widget.value.length),
      );
    }
  }

  @override
  void dispose() {
    _focusNode
      ..removeListener(_handleFocusChange)
      ..dispose();
    _controller.dispose();
    super.dispose();
  }

  void _handleFocusChange() {
    if (mounted) setState(() {});
  }

  void _showRangeWarning() {
    final hps = widget.columnHps;
    final message = widget.isHpsCell
        ? 'Highest Possible Score must be between 1 and 100.'
        : 'Score cannot exceed Highest Possible Score (${hps?.toInt() ?? 100}).';
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final focused = _focusNode.hasFocus;
    final disabledBackground = theme.brightness == Brightness.dark
        ? const Color(0xFF1E293B)
        : const Color(0xFFE2E8F0);
    final backgroundColor = widget.isInvalidValue
        ? theme.colorScheme.error.withValues(alpha: 0.12)
        : !widget.isEnabled
        ? disabledBackground
        : focused
        ? theme.colorScheme.primary.withValues(alpha: 0.08)
        : widget.backgroundColor;
    final border = focused
        ? Border.all(color: theme.colorScheme.primary, width: 1.5)
        : Border(
            right: BorderSide(
              color: widget.isInvalidValue
                  ? theme.colorScheme.error
                  : widget.borderColor,
              width: widget.isInvalidValue ? 1 : 0.5,
            ),
          );
    final tooltip = widget.isInvalidValue
        ? 'Invalid entry: reduce the score or restore the column HPS.'
        : widget.isEnabled
        ? ''
        : widget.disabledTooltip;
    final cell = Container(
      width: widget.width,
      height: 34,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(2),
        border: border,
      ),
      alignment: Alignment.center,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.isEnabled ? () => _focusNode.requestFocus() : null,
        child: SizedBox.expand(
          child: Center(
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              enabled: widget.isEnabled,
              onChanged: widget.onChanged,
              textAlign: TextAlign.center,
              textAlignVertical: TextAlignVertical.center,
              keyboardType: TextInputType.number,
              inputFormatters: [
                _ScoreRangeTextInputFormatter(
                  isHpsCell: widget.isHpsCell,
                  columnHps: widget.columnHps,
                  onRejected: _showRangeWarning,
                ),
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(3),
              ],
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: widget.isInvalidValue
                    ? theme.colorScheme.error
                    : widget.textColor,
              ),
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ),
      ),
    );
    return tooltip.isEmpty ? cell : Tooltip(message: tooltip, child: cell);
  }
}

class _ScoreRangeTextInputFormatter extends TextInputFormatter {
  final bool isHpsCell;
  final double? columnHps;
  final VoidCallback onRejected;

  const _ScoreRangeTextInputFormatter({
    required this.isHpsCell,
    required this.columnHps,
    required this.onRejected,
  });

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    if (text.isEmpty) return newValue;
    if (text.length > 3) {
      onRejected();
      return oldValue;
    }

    final value = int.tryParse(text);
    if (value == null) {
      onRejected();
      return oldValue;
    }
    if (isHpsCell) {
      if (value < 1 || value > 100) {
        onRejected();
        return oldValue;
      }
      return newValue;
    }

    final maximum = columnHps == null ? 100 : columnHps!.floor().clamp(0, 100);
    if (value > maximum) {
      onRejected();
      return oldValue;
    }
    return newValue;
  }
}
