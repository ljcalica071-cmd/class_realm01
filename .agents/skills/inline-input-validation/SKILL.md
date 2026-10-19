---
name: inline-input-validation
description: Use when creating, modifying, or reviewing form inputs, text fields, or validation logic. Enforces inline error messages directly underneath input fields with red borders, strictly prohibiting bottom SnackBars, banners, or floating toasts for form and input validation errors.
---

# Inline Input Validation Standard

## Core Rule
**Never use bottom SnackBars, banners, or floating toast notifications for form and input validation errors.**

Validation errors must ALWAYS be presented **inline**:
1. **Red Border Outline**: The input container or box border turns red (`Color(0xFFDC2626)` or `Colors.red.shade600`) when an error is present.
2. **Inline Error Message**: The error message appears directly **underneath** the corresponding input field in a clear, 12-13px red font with optional warning icon (`Icons.error_outline`).
3. **Live Error Clearing**: As soon as the user starts typing or edits the invalid field, clear the inline error immediately.
4. **All English Messages**: All validation error messages, helper text, and labels must be written in grammatically correct, professional English.

---

## Why Bottom Banners Are Prohibited For Validation
- Bottom SnackBars cover UI buttons (e.g. submit button, navigation bar).
- Bottom SnackBars disconnect the error message from the specific field that caused it.
- Mobile and web users expect input errors to highlight the exact invalid field directly in place.

---

## Implementation Patterns

### Pattern 1: Flutter `TextFormField` with Built-in `validator`
When using `Form` and `TextFormField`, utilize Flutter's built-in validation with custom error border decoration:

```dart
InputDecoration(
  labelText: 'Full Name',
  hintText: 'e.g. Karen Gonzaga',
  filled: true,
  fillColor: isDark ? Colors.white10 : Colors.grey.shade100,
  border: OutlineInputBorder(
    borderRadius: BorderRadius.circular(10),
    borderSide: BorderSide(color: isDark ? Colors.white24 : Colors.grey.shade300),
  ),
  enabledBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(10),
    borderSide: BorderSide(color: isDark ? Colors.white12 : Colors.grey.shade300),
  ),
  focusedBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(10),
    borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.5),
  ),
  errorBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(10),
    borderSide: const BorderSide(color: Color(0xFFDC2626), width: 1.5),
  ),
  focusedErrorBorder: OutlineInputBorder(
    borderRadius: BorderRadius.circular(10),
    borderSide: const BorderSide(color: Color(0xFFDC2626), width: 2.0),
  ),
  errorStyle: const TextStyle(
    color: Color(0xFFDC2626),
    fontSize: 12,
    fontWeight: FontWeight.w500,
  ),
)
```

### Pattern 2: Explicit State-Driven Inline Validation (`TextField`)
When using stateful `TextField` without `FormState`:

```dart
// 1. Declare state variable
String? _titleError;

// 2. Clear error on input change
_titleController.addListener(() {
  if (_titleError != null) {
    setState(() => _titleError = null);
  }
});

// 3. Validate on submit
void _handleSubmit() {
  final text = _titleController.text.trim();
  if (text.length < 3) {
    setState(() => _titleError = 'Title must be at least 3 characters long.');
    return;
  }
  // Proceed with submission...
}

// 4. Render with inline error decoration
TextField(
  controller: _titleController,
  decoration: InputDecoration(
    labelText: 'Announcement Title',
    errorText: _titleError,
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: Color(0xFFDC2626), width: 1.5),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: Color(0xFFDC2626), width: 2.0),
    ),
    errorStyle: const TextStyle(
      color: Color(0xFFDC2626),
      fontSize: 12,
      fontWeight: FontWeight.w500,
    ),
  ),
)
```

### Pattern 3: Custom Field Container with Dedicated Error Widget
If rendering custom input containers or selectors (dropdowns, date pickers, OTP fields):

```dart
Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: hasError ? const Color(0xFFDC2626) : normalBorderColor,
          width: hasError ? 1.5 : 1.0,
        ),
      ),
      child: customFieldWidget,
    ),
    if (errorMessage != null) ...[
      const SizedBox(height: 5),
      Row(
        children: [
          const Icon(Icons.error_outline, size: 14, color: Color(0xFFDC2626)),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              errorMessage!,
              style: const TextStyle(
                color: Color(0xFFDC2626),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    ],
  ],
)
```

---

## Checklist for Reviewing Code
- [ ] Are any `ScaffoldMessenger.of(context).showSnackBar` calls used for form or field validation? **If YES, remove them.**
- [ ] Does the invalid field box highlight with a red border?
- [ ] Is the error message positioned directly underneath the input box?
- [ ] Does typing into the field immediately clear the error message?
- [ ] Is the error message phrased in clear, professional English?
