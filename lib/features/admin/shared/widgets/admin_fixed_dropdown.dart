import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Item definition for [AdminFixedDropdown] and [AdminFixedDropdownFormField].
class AdminDropdownItem<T> {
  final T value;
  final String label;
  final Widget? icon;
  final Widget? customChild;
  final bool enabled;

  const AdminDropdownItem({
    required this.value,
    required this.label,
    this.icon,
    this.customChild,
    this.enabled = true,
  });
}

/// A fixed-position dropdown widget for Admin screens.
///
/// Unlike standard [DropdownButton] which dynamically shifts its vertical
/// position to align the selected item with the button, [AdminFixedDropdown]
/// utilizes [MenuAnchor] so the menu ALWAYS opens anchored directly below
/// the trigger at a fixed position, regardless of which item is selected.
class AdminFixedDropdown<T> extends StatefulWidget {
  final List<AdminDropdownItem<T>> items;
  final T? value;
  final ValueChanged<T?>? onChanged;
  final String? hintText;
  final Widget? icon;
  final double? menuWidth;
  final double? menuMaxHeight;
  final bool isExpanded;
  final EdgeInsetsGeometry? padding;
  final BoxDecoration? decoration;
  final Widget Function(
    BuildContext context,
    MenuController controller,
    AdminDropdownItem<T>? selectedItem,
  )? builder;

  const AdminFixedDropdown({
    super.key,
    required this.items,
    required this.value,
    required this.onChanged,
    this.hintText,
    this.icon,
    this.menuWidth,
    this.menuMaxHeight = 280,
    this.isExpanded = false,
    this.padding,
    this.decoration,
    this.builder,
  });

  @override
  State<AdminFixedDropdown<T>> createState() => _AdminFixedDropdownState<T>();
}

class _AdminFixedDropdownState<T> extends State<AdminFixedDropdown<T>> {
  final GlobalKey _buttonKey = GlobalKey();
  double? _buttonWidth;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _measureButton());
  }

  @override
  void didUpdateWidget(AdminFixedDropdown<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) => _measureButton());
  }

  void _measureButton() {
    if (!mounted) return;
    final renderBox =
        _buttonKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox != null && renderBox.hasSize) {
      final width = renderBox.size.width;
      if (width > 0 && width != _buttonWidth) {
        setState(() {
          _buttonWidth = width;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    AdminDropdownItem<T>? selectedItem;
    for (final item in widget.items) {
      if (item.value == widget.value) {
        selectedItem = item;
        break;
      }
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final double? calculatedWidth = widget.menuWidth ??
            (widget.isExpanded
                ? (constraints.maxWidth.isFinite && constraints.maxWidth > 0
                    ? constraints.maxWidth
                    : _buttonWidth)
                : _buttonWidth);

        final double minWidth = calculatedWidth ?? 0;
        final double maxWidth = widget.isExpanded
            ? (calculatedWidth ?? double.infinity)
            : math.max(calculatedWidth ?? 380, 380);

        return MenuAnchor(
          alignmentOffset: const Offset(0, 4),
          style: MenuStyle(
            backgroundColor: WidgetStatePropertyAll(
              isDark ? const Color(0xFF1E293B) : Colors.white,
            ),
            surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
            elevation: const WidgetStatePropertyAll(8),
            shadowColor: WidgetStatePropertyAll(
              Colors.black.withValues(alpha: isDark ? 0.4 : 0.14),
            ),
            padding: const WidgetStatePropertyAll(
              EdgeInsets.symmetric(vertical: 4),
            ),
            minimumSize: minWidth > 0
                ? WidgetStatePropertyAll(Size(minWidth, 0))
                : null,
            maximumSize: WidgetStatePropertyAll(
              Size(maxWidth, widget.menuMaxHeight ?? 280),
            ),
            side: WidgetStatePropertyAll(
              BorderSide(
                color: isDark ? Colors.white12 : const Color(0xFFCBD5E1),
              ),
            ),
            shape: WidgetStatePropertyAll(
              RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          menuChildren: widget.items.map((item) {
            final isSelected = item.value == widget.value;
            final isEnabled = item.enabled && widget.onChanged != null;

            Widget content;
            if (item.customChild != null) {
              content = item.customChild!;
            } else if (widget.isExpanded) {
              content = Row(
                children: [
                  if (item.icon != null) ...[
                    item.icon!,
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Text(
                      item.label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w500,
                        color: !isEnabled
                            ? Colors.grey
                            : (isSelected
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurface),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isSelected) ...[
                    const SizedBox(width: 8),
                    Icon(
                      Icons.check,
                      size: 16,
                      color: theme.colorScheme.primary,
                    ),
                  ],
                ],
              );
            } else {
              content = Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (item.icon != null) ...[
                    item.icon!,
                    const SizedBox(width: 8),
                  ],
                  Flexible(
                    child: Text(
                      item.label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w500,
                        color: !isEnabled
                            ? Colors.grey
                            : (isSelected
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurface),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (isSelected) ...[
                    const SizedBox(width: 12),
                    Icon(
                      Icons.check,
                      size: 16,
                      color: theme.colorScheme.primary,
                    ),
                  ],
                ],
              );
            }

            final menuItem = MenuItemButton(
              onPressed: isEnabled
                  ? () {
                      widget.onChanged?.call(item.value);
                    }
                  : null,
              style: ButtonStyle(
                padding: const WidgetStatePropertyAll(
                  EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
                backgroundColor: WidgetStateProperty.resolveWith((states) {
                  if (isSelected) {
                    return theme.colorScheme.primary.withValues(alpha: 0.10);
                  }
                  if (states.contains(WidgetState.hovered) && isEnabled) {
                    return isDark
                        ? Colors.white.withValues(alpha: 0.05)
                        : const Color(0xFFF1F5F9);
                  }
                  return Colors.transparent;
                }),
              ),
              child: content,
            );

            if (widget.isExpanded && calculatedWidth != null) {
              return SizedBox(
                width: calculatedWidth,
                child: menuItem,
              );
            }

            return menuItem;
          }).toList(),
          builder: (context, controller, child) {
            if (widget.builder != null) {
              return KeyedSubtree(
                key: _buttonKey,
                child: widget.builder!(context, controller, selectedItem),
              );
            }

            final isOpen = controller.isOpen;
            return InkWell(
              key: _buttonKey,
              borderRadius: BorderRadius.circular(10),
              onTap: widget.onChanged == null
                  ? null
                  : () {
                      _measureButton();
                      if (controller.isOpen) {
                        controller.close();
                      } else {
                        controller.open();
                      }
                    },
              child: Container(
                padding: widget.padding ??
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: widget.decoration ??
                    BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isOpen
                            ? theme.colorScheme.primary
                            : (isDark
                                ? Colors.white12
                                : const Color(0xFFCBD5E1)),
                        width: isOpen ? 1.4 : 1.0,
                      ),
                    ),
                child: Row(
                  mainAxisSize:
                      widget.isExpanded ? MainAxisSize.max : MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (selectedItem?.icon != null) ...[
                      selectedItem!.icon!,
                      const SizedBox(width: 8),
                    ],
                    Flexible(
                      child: selectedItem?.customChild ??
                          Text(
                            selectedItem?.label ??
                                widget.hintText ??
                                'Select...',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: selectedItem != null
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                              color: selectedItem != null
                                  ? theme.colorScheme.onSurface
                                  : theme.colorScheme.onSurface
                                      .withValues(alpha: 0.4),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                    ),
                    const SizedBox(width: 8),
                    widget.icon ??
                        Icon(
                          isOpen
                              ? LucideIcons.chevronUp
                              : LucideIcons.chevronDown,
                          size: 16,
                          color:
                              isDark ? Colors.white70 : const Color(0xFF475569),
                        ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

/// A form field variant of [AdminFixedDropdown] with standard input decoration
/// and inline error validation support.
class AdminFixedDropdownFormField<T> extends FormField<T> {
  AdminFixedDropdownFormField({
    super.key,
    super.initialValue,
    super.validator,
    super.autovalidateMode,
    required List<AdminDropdownItem<T>> items,
    ValueChanged<T?>? onChanged,
    String? hintText,
    bool isDark = false,
    double? menuMaxHeight = 280,
  }) : super(
          builder: (FormFieldState<T> state) {
            final context = state.context;
            final theme = Theme.of(context);
            final effectiveIsDark =
                isDark || theme.brightness == Brightness.dark;

            AdminDropdownItem<T>? selectedItem;
            for (final item in items) {
              if (item.value == state.value) {
                selectedItem = item;
                break;
              }
            }

            return LayoutBuilder(
              builder: (context, constraints) {
                final menuWidth = constraints.maxWidth;

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    MenuAnchor(
                      alignmentOffset: const Offset(0, 4),
                      style: MenuStyle(
                        backgroundColor: WidgetStatePropertyAll(
                          effectiveIsDark
                              ? const Color(0xFF1E293B)
                              : Colors.white,
                        ),
                        surfaceTintColor:
                            const WidgetStatePropertyAll(Colors.transparent),
                        elevation: const WidgetStatePropertyAll(8),
                        shadowColor: WidgetStatePropertyAll(
                          Colors.black
                              .withValues(alpha: effectiveIsDark ? 0.4 : 0.14),
                        ),
                        padding: const WidgetStatePropertyAll(
                          EdgeInsets.symmetric(vertical: 4),
                        ),
                        minimumSize: WidgetStatePropertyAll(Size(menuWidth, 0)),
                        maximumSize: WidgetStatePropertyAll(
                          Size(menuWidth, menuMaxHeight ?? 280),
                        ),
                        side: WidgetStatePropertyAll(
                          BorderSide(
                            color: effectiveIsDark
                                ? Colors.white12
                                : const Color(0xFFCBD5E1),
                          ),
                        ),
                        shape: WidgetStatePropertyAll(
                          RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      menuChildren: items.map((item) {
                        final isSelected = item.value == state.value;
                        final isEnabled = item.enabled && onChanged != null;

                        return SizedBox(
                          width: menuWidth,
                          child: MenuItemButton(
                            onPressed: isEnabled
                                ? () {
                                    state.didChange(item.value);
                                    onChanged(item.value);
                                  }
                                : null,
                            style: ButtonStyle(
                              padding: const WidgetStatePropertyAll(
                                EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                              ),
                              backgroundColor:
                                  WidgetStateProperty.resolveWith((states) {
                                if (isSelected) {
                                  return theme.colorScheme.primary
                                      .withValues(alpha: 0.10);
                                }
                                if (states.contains(WidgetState.hovered) &&
                                    isEnabled) {
                                  return effectiveIsDark
                                      ? Colors.white.withValues(alpha: 0.05)
                                      : const Color(0xFFF1F5F9);
                                }
                                return Colors.transparent;
                              }),
                            ),
                            trailingIcon: isSelected
                                ? Icon(
                                    Icons.check,
                                    size: 16,
                                    color: theme.colorScheme.primary,
                                  )
                                : null,
                            child: item.customChild ??
                                Text(
                                  item.label,
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                    color: !isEnabled
                                        ? Colors.grey
                                        : (isSelected
                                            ? theme.colorScheme.primary
                                            : theme.colorScheme.onSurface),
                                  ),
                                ),
                          ),
                        );
                      }).toList(),
                      builder: (context, controller, child) {
                        final isOpen = controller.isOpen;
                        final hasError = state.hasError;

                        return InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: onChanged == null
                              ? null
                              : () {
                                  if (controller.isOpen) {
                                    controller.close();
                                  } else {
                                    controller.open();
                                  }
                                },
                          child: Container(
                            height: 48,
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            decoration: BoxDecoration(
                              color: effectiveIsDark
                                  ? Colors.white.withValues(alpha: 0.05)
                                  : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: hasError
                                    ? theme.colorScheme.error
                                    : (isOpen
                                        ? theme.colorScheme.primary
                                        : (effectiveIsDark
                                            ? Colors.white24
                                            : Colors.grey.shade300)),
                                width: (isOpen || hasError) ? 1.5 : 1.0,
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  selectedItem?.label ??
                                      hintText ??
                                      'Select...',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: selectedItem != null
                                        ? FontWeight.w500
                                        : FontWeight.w400,
                                    color: selectedItem != null
                                        ? theme.colorScheme.onSurface
                                        : theme.colorScheme.onSurface
                                            .withValues(alpha: 0.4),
                                  ),
                                ),
                                Icon(
                                  isOpen
                                      ? LucideIcons.chevronUp
                                      : LucideIcons.chevronDown,
                                  size: 18,
                                  color: effectiveIsDark
                                      ? Colors.white70
                                      : const Color(0xFF64748B),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    if (state.hasError) ...[
                      const SizedBox(height: 6),
                      Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: Text(
                          state.errorText ?? '',
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.error,
                          ),
                        ),
                      ),
                    ],
                  ],
                );
              },
            );
          },
        );
}
