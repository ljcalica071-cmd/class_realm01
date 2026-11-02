import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:class_realm/core/theme/app_theme.dart';
import 'package:class_realm/models/user_model.dart';
import 'package:class_realm/widgets/common/app_buttons.dart';
import 'package:class_realm/widgets/common/app_modals.dart';
import 'package:class_realm/widgets/common/app_text_field.dart';
import 'package:class_realm/widgets/common/app_date_picker_field.dart';
import 'package:class_realm/core/utils/validators.dart';
import 'package:class_realm/core/utils/parent_credential_helper.dart';
import 'package:class_realm/data/repositories/supabase_parent_repository.dart';

class AddParentDialog extends StatefulWidget {
  final VoidCallback onParentCreated;
  final List<UserModel>? students;
  final String? filterSection;
  final String? filterSubject;

  const AddParentDialog({
    super.key,
    required this.onParentCreated,
    this.students,
    this.filterSection,
    this.filterSubject,
  });

  static Future<void> show(
    BuildContext context, {
    required VoidCallback onParentCreated,
    List<UserModel>? students,
    String? filterSection,
    String? filterSubject,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AddParentDialog(
        onParentCreated: onParentCreated,
        students: students,
        filterSection: filterSection,
        filterSubject: filterSubject,
      ),
    );
  }

  @override
  State<AddParentDialog> createState() => _AddParentDialogState();
}

class _AddParentDialogState extends State<AddParentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameCtrl = TextEditingController();
  final _middleNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _customRelationshipCtrl = TextEditingController();
  final _studentSearchCtrl = TextEditingController();
  final _quickSearchCtrl = TextEditingController();

  String? _relationship;
  DateTime? _birthday;
  final List<UserModel> _selectedStudents = [];
  String _studentSearchQuery = '';
  bool _isSubmitting = false;

  // Real-time Existing Parent Auto-Detection
  Map<String, dynamic>? _detectedExistingParent;
  bool _isCheckingExisting = false;
  Timer? _detectionDebounce;
  String? _ignoredParentId;

  // Optional Quick Autofill Search
  bool _showQuickSearch = false;
  List<Map<String, dynamic>> _quickSearchResults = [];
  bool _isQuickSearching = false;
  Timer? _quickSearchDebounce;

  @override
  void initState() {
    super.initState();
    _firstNameCtrl.addListener(_onNameOrBirthdayChanged);
    _lastNameCtrl.addListener(_onNameOrBirthdayChanged);
  }

  void _onNameOrBirthdayChanged() {
    if (mounted) setState(() {});

    final first = _firstNameCtrl.text.trim();
    final last = _lastNameCtrl.text.trim();

    if (first.length >= 2 && last.length >= 2) {
      _detectionDebounce?.cancel();
      _detectionDebounce = Timer(const Duration(milliseconds: 350), () async {
        if (!mounted) return;
        setState(() => _isCheckingExisting = true);
        try {
          final results = await SupabaseParentRepository().searchExistingParents(
            query: '$first $last',
          );
          if (!mounted) return;

          Map<String, dynamic>? match;
          for (final r in results) {
            final rFirst = (r['firstName'] ?? '').toString().toLowerCase().trim();
            final rLast = (r['lastName'] ?? '').toString().toLowerCase().trim();
            if (rFirst == first.toLowerCase() && rLast == last.toLowerCase()) {
              match = r;
              break;
            }
          }
          match ??= results.isNotEmpty ? results.first : null;

          setState(() {
            if (match != null && match['parentId'] != _ignoredParentId) {
              _detectedExistingParent = match;
            } else {
              _detectedExistingParent = null;
            }
            _isCheckingExisting = false;
          });
        } catch (_) {
          if (mounted) setState(() => _isCheckingExisting = false);
        }
      });
    } else {
      if (_detectedExistingParent != null) {
        setState(() => _detectedExistingParent = null);
      }
    }
  }

  void _onQuickSearchChanged(String query) {
    _quickSearchDebounce?.cancel();
    if (query.trim().isEmpty) {
      setState(() {
        _quickSearchResults = [];
        _isQuickSearching = false;
      });
      return;
    }
    setState(() => _isQuickSearching = true);
    _quickSearchDebounce = Timer(const Duration(milliseconds: 300), () async {
      try {
        final results = await SupabaseParentRepository()
            .searchExistingParents(query: query);
        if (mounted) {
          setState(() {
            _quickSearchResults = results;
            _isQuickSearching = false;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isQuickSearching = false);
        }
      }
    });
  }

  void _autofillFromExistingParent(Map<String, dynamic> parent) {
    setState(() {
      _firstNameCtrl.text = parent['firstName']?.toString() ?? '';
      _middleNameCtrl.text = parent['middleName']?.toString() ?? '';
      _lastNameCtrl.text = parent['lastName']?.toString() ?? '';
      if (parent['birthday'] is DateTime) {
        _birthday = parent['birthday'] as DateTime;
      }
      _detectedExistingParent = parent;
      _ignoredParentId = null;
      _showQuickSearch = false;
      _quickSearchCtrl.clear();
      _quickSearchResults = [];
    });
  }

  @override
  void dispose() {
    _detectionDebounce?.cancel();
    _quickSearchDebounce?.cancel();
    _firstNameCtrl.removeListener(_onNameOrBirthdayChanged);
    _lastNameCtrl.removeListener(_onNameOrBirthdayChanged);
    _firstNameCtrl.dispose();
    _middleNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _customRelationshipCtrl.dispose();
    _studentSearchCtrl.dispose();
    _quickSearchCtrl.dispose();
    super.dispose();
  }

  void _submitLinkToExistingParent() async {
    if (_detectedExistingParent == null) return;
    if (_selectedStudents.isEmpty) {
      AppModals.showErrorDialog(
        context: context,
        title: 'Student Required',
        message: 'Please select at least one student to link to this parent.',
      );
      return;
    }
    if (_relationship == null || _relationship!.isEmpty) {
      AppModals.showErrorDialog(
        context: context,
        title: 'Relationship Required',
        message: 'Please select the relationship (e.g. Father, Mother, Guardian).',
      );
      return;
    }

    setState(() => _isSubmitting = true);
    final parentId = _detectedExistingParent!['parentId'].toString();
    final parentName = _detectedExistingParent!['fullName'].toString();
    final rel = _relationship == 'Other'
        ? _customRelationshipCtrl.text.trim()
        : _relationship!;

    try {
      await SupabaseParentRepository().linkStudentsToExistingParent(
        parentId: parentId,
        studentIds: _selectedStudents.map((s) => s.id).toList(),
        relationship: rel,
      );

      if (mounted) {
        setState(() => _isSubmitting = false);
        Navigator.of(context).pop();
        widget.onParentCreated();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Successfully linked ${_selectedStudents.map((s) => s.fullName).join(", ")} to $parentName!',
            ),
            backgroundColor: AppTheme.catGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        AppModals.showErrorDialog(
          context: context,
          title: 'Linking Failed',
          message: e.toString().replaceAll('Exception: ', ''),
        );
      }
    }
  }

  void _submitNewParent() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedStudents.isEmpty) {
      AppModals.showErrorDialog(
        context: context,
        title: 'Student Required',
        message: 'Please link at least one student to this parent.',
      );
      return;
    }
    if (_selectedStudents.length > 15) {
      AppModals.showErrorDialog(
        context: context,
        title: 'Limit Exceeded',
        message: 'Too many students to link in one parent account (max 15).',
      );
      return;
    }
    if (_birthday == null) {
      AppModals.showErrorDialog(
        context: context,
        title: 'Birthday Required',
        message: "Please select the parent's birthday.",
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final firstName = _firstNameCtrl.text.trim();
    final middleName = AppValidators.normalizeMiddleInitial(_middleNameCtrl.text);
    final lastName = _lastNameCtrl.text.trim();
    final fullName = [firstName, ?middleName, lastName].join(' ');

    final relationship = _relationship == 'Other'
        ? _customRelationshipCtrl.text.trim()
        : _relationship!;

    final tempPassword = ParentCredentialHelper.generateTempPassword(
      lastName,
      _birthday!,
    );
    final parentEmail = ParentCredentialHelper.generateEmail(lastName);

    UserModel? createdUser;
    try {
      final repo = SupabaseParentRepository();
      createdUser = await repo.createParentAccount(
        firstName: firstName,
        middleName: middleName,
        lastName: lastName,
        contactNumber: '',
        birthday: _birthday!,
        relationship: relationship,
        studentIds: _selectedStudents.map((s) => s.id).toList(),
        email: parentEmail,
        tempPassword: tempPassword,
      );
    } catch (e) {
      debugPrint('Notice saving to supabase parent: $e');
      if (mounted) {
        setState(() => _isSubmitting = false);
        AppModals.showErrorDialog(
          context: context,
          title: 'Account Creation Failed',
          message: e.toString().replaceAll('Exception: ', ''),
        );
        return;
      }
    }

    final finalEmail = createdUser?.email ?? parentEmail;

    if (mounted) {
      setState(() => _isSubmitting = false);
      Navigator.of(context).pop();
      widget.onParentCreated();

      _showConfirmationDialog(
        context: context,
        fullName: fullName,
        email: finalEmail,
        tempPassword: tempPassword,
        linkedStudentName: _selectedStudents.map((s) => s.fullName).join(', '),
      );
    }
  }

  static void _showConfirmationDialog({
    required BuildContext context,
    required String fullName,
    required String email,
    required String tempPassword,
    required String linkedStudentName,
  }) {
    final credentialsText =
        '[CLASSREALM PARENT ACCESS SLIP]\n'
        'Parent Name: $fullName\n'
        'Linked Student: $linkedStudentName\n'
        'Login Email: $email\n'
        'Temporary Password: $tempPassword\n\n'
        'Instructions:\n'
        '1. Open ClassRealm.\n'
        '2. Log in using your Parent Email and Temporary Password.\n'
        '3. Set your new private password on first login.\n';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.all(28),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.catGreen.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_outline,
                  color: AppTheme.catGreen,
                  size: 40,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Parent Account Created!',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Account for $fullName has been created and linked to $linkedStudentName.',
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(ctx).colorScheme.onSurface.withValues(alpha: 0.65),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(ctx).colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(ctx).colorScheme.outline.withValues(alpha: 0.2),
                  ),
                ),
                child: Column(
                  children: [
                    _CredentialRow(label: 'Login Email', value: email),
                    _CredentialRow(label: 'Temporary Password', value: tempPassword),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: AppSecondaryButton(
                      label: 'Copy Credentials',
                      icon: Icons.copy,
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: credentialsText));
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(
                            content: Text('Access slip copied to clipboard!'),
                            backgroundColor: AppTheme.catGreen,
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AppPrimaryButton(
                      label: 'Done',
                      onPressed: () => Navigator.of(ctx).pop(),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      titlePadding: const EdgeInsets.fromLTRB(28, 28, 28, 0),
      contentPadding: const EdgeInsets.fromLTRB(28, 16, 28, 0),
      actionsPadding: const EdgeInsets.fromLTRB(28, 16, 28, 24),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.group_add_outlined,
              color: theme.colorScheme.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Add Parent / Guardian',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Register parent account and link to student records',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    fontWeight: FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 620,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.75,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(right: 4),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Optional Quick Search / Autofill Header
                  _buildQuickSearchSection(theme),

                  const SizedBox(height: 8),
                  const _SectionLabel('Parent Name'),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 4,
                        child: AppTextField(
                          label: 'First Name *',
                          controller: _firstNameCtrl,
                          inputFormatters: [
                            ...AppValidators.nameFormatters,
                            LengthLimitingTextInputFormatter(30),
                          ],
                          validator: (v) =>
                              AppValidators.validateName(v, 'First name'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: AppTextField(
                          label: 'Middle Initial',
                          controller: _middleNameCtrl,
                          textCapitalization: TextCapitalization.characters,
                          validator: AppValidators.validateMiddleInitial,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 4,
                        child: AppTextField(
                          label: 'Last Name *',
                          controller: _lastNameCtrl,
                          inputFormatters: [
                            ...AppValidators.nameFormatters,
                            LengthLimitingTextInputFormatter(30),
                          ],
                          validator: (v) =>
                              AppValidators.validateName(v, 'Last name'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const _SectionLabel('Contact & Relationship'),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 3,
                        child: AppDatePickerField(
                          label: 'Birthday *',
                          initialDate: _birthday,
                          showAgeHeader: false,
                          firstDate: BirthdayValidator.getMinDate(),
                          lastDate: BirthdayValidator.getMaxDate('parent'),
                          onDateSelected: (d) {
                            setState(() => _birthday = d);
                            _onNameOrBirthdayChanged();
                          },
                          validator: (d) {
                            if (d == null) return 'Birthday is required.';
                            final now = DateTime.now();
                            int age = now.year - d.year;
                            if (now.month < d.month ||
                                (now.month == d.month && now.day < d.day)) {
                              age--;
                            }
                            if (age < 18) {
                              return 'Parent/Guardian must be at least 18 years old.';
                            }
                            return null;
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(flex: 2, child: _buildAgeField(theme)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _buildRelationshipField(theme)),
                    ],
                  ),
                  if (_relationship == 'Other') ...[
                    const SizedBox(height: 16),
                    AppTextField(
                      label: 'Specify Relationship *',
                      controller: _customRelationshipCtrl,
                      inputFormatters: [
                        ...AppValidators.nameFormatters,
                        LengthLimitingTextInputFormatter(30),
                      ],
                      validator: (v) {
                        if (_relationship != 'Other') return null;
                        if (v == null || v.trim().isEmpty) {
                          return 'Specify relationship is required.';
                        }
                        if (v.trim().length < 2) {
                          return 'Specify relationship must be at least 2 characters.';
                        }
                        if (v.trim().length > 30) {
                          return 'Specify relationship cannot exceed 30 characters.';
                        }
                        return null;
                      },
                    ),
                  ],
                  const SizedBox(height: 16),

                  // Dynamic Card: Auto-Detected Existing Parent OR Live Credential Preview
                  if (_isCheckingExisting)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Checking for existing parent account...',
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    )
                  else if (_detectedExistingParent != null)
                    _buildExistingParentDetectedCard(theme)
                  else
                    _buildCredentialPreviewCard(theme),

                  const SizedBox(height: 16),
                  _SectionLabel(
                    'Link Students *',
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.filterSection != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: theme.colorScheme.primary.withValues(alpha: 0.25),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.groups_outlined,
                                  size: 12,
                                  color: theme.colorScheme.primary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  widget.filterSection!,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${_selectedStudents.length} linked',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildLinkStudentSection(theme),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ),
      ),
      actions: [
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            AppSecondaryButton(
              label: 'Cancel',
              width: 140,
              height: 44,
              onPressed: () => Navigator.of(context).pop(),
            ),
            const SizedBox(width: 12),
            AppPrimaryButton(
              label: _detectedExistingParent != null
                  ? 'Link to Existing Parent'
                  : 'Create Parent Account',
              icon: _detectedExistingParent != null
                  ? Icons.link_rounded
                  : Icons.person_add_alt_1,
              isLoading: _isSubmitting,
              onPressed: _isSubmitting
                  ? null
                  : (_detectedExistingParent != null
                      ? _submitLinkToExistingParent
                      : _submitNewParent),
              width: 220,
              height: 44,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickSearchSection(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _showQuickSearch = !_showQuickSearch),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Icon(
                    _showQuickSearch ? Icons.keyboard_arrow_down : Icons.search,
                    size: 16,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _showQuickSearch
                        ? 'Hide search'
                        : 'Already know this parent is registered? Search to autofill',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_showQuickSearch) ...[
            const SizedBox(height: 8),
            TextField(
              controller: _quickSearchCtrl,
              onChanged: _onQuickSearchChanged,
              decoration: InputDecoration(
                hintText: 'Search parent name or child LRN to autofill...',
                hintStyle: TextStyle(
                  fontSize: 12.5,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
                prefixIcon: const Icon(Icons.search, size: 18),
                suffixIcon: _quickSearchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 16),
                        onPressed: () {
                          _quickSearchCtrl.clear();
                          _onQuickSearchChanged('');
                        },
                      )
                    : null,
                filled: true,
                fillColor: theme.colorScheme.surface,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(
                    color: theme.colorScheme.outline.withValues(alpha: 0.3),
                  ),
                ),
              ),
            ),
            if (_isQuickSearching) ...[
              const SizedBox(height: 6),
              const LinearProgressIndicator(minHeight: 2),
            ],
            if (_quickSearchResults.isNotEmpty) ...[
              const SizedBox(height: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 140),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _quickSearchResults.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 4),
                  itemBuilder: (context, idx) {
                    final p = _quickSearchResults[idx];
                    final fullName = p['fullName']?.toString() ?? 'Parent';
                    final email = p['email']?.toString() ?? '';
                    final children = (p['linkedChildren'] as List? ?? []);
                    final childNames = children
                        .map((c) => c['fullName']?.toString() ?? '')
                        .where((n) => n.isNotEmpty)
                        .join(', ');

                    return InkWell(
                      onTap: () => _autofillFromExistingParent(p),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: theme.colorScheme.outline.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 14,
                              backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                              child: Text(
                                fullName.isNotEmpty ? fullName[0].toUpperCase() : 'P',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    fullName,
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    '$email ${childNames.isNotEmpty ? "• Child: $childNames" : ""}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              'Autofill',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  Widget _buildExistingParentDetectedCard(ThemeData theme) {
    final parent = _detectedExistingParent!;
    final fullName = parent['fullName']?.toString() ?? 'Registered Parent';
    final email = parent['email']?.toString() ?? '${parent['lastName']?.toString().toLowerCase()}@classrealm.com';
    final children = (parent['linkedChildren'] as List? ?? []);
    final childNames = children
        .map((c) => c['fullName']?.toString() ?? '')
        .where((n) => n.isNotEmpty)
        .join(', ');

    return Container(
      margin: const EdgeInsets.only(top: 4, bottom: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF16A34A).withValues(alpha: 0.4),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.verified_user_outlined,
                color: Color(0xFF16A34A),
                size: 20,
              ),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'EXISTING PARENT ACCOUNT DETECTED',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                    color: Color(0xFF15803D),
                  ),
                ),
              ),
              InkWell(
                onTap: () {
                  setState(() {
                    _ignoredParentId = parent['parentId']?.toString();
                    _detectedExistingParent = null;
                  });
                },
                child: const Text(
                  'Register as New',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2563EB),
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFBBF7D0)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      fullName,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF14532D),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCFCE7),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        email,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF166534),
                        ),
                      ),
                    ),
                  ],
                ),
                if (childNames.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Currently linked student(s): $childNames',
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: Color(0xFF15803D),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'This parent is already registered in the school directory. Submitting will link the selected student(s) to this account without creating duplicate login credentials.',
            style: TextStyle(
              fontSize: 11.5,
              color: Color(0xFF166534),
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCredentialPreviewCard(ThemeData theme) {
    final rawLastName = _lastNameCtrl.text.trim();
    final sanitizedLastName = rawLastName.isNotEmpty
        ? ParentCredentialHelper.sanitizeLastName(rawLastName)
        : 'lastname';
    final previewEmail = ParentCredentialHelper.generateEmail(
      rawLastName.isNotEmpty ? rawLastName : 'lastname',
    );
    final previewPassword = _birthday != null
        ? ParentCredentialHelper.generateTempPassword(
            rawLastName.isNotEmpty ? rawLastName : 'lastname',
            _birthday!,
          )
        : '$sanitizedLastName[YYYYMMDD]';

    return Container(
      margin: const EdgeInsets.only(top: 4, bottom: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.badge_outlined,
                size: 16,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'LIVE CREDENTIAL PREVIEW',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Login Email',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: theme.colorScheme.outline.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Text(
                        previewEmail,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.primary,
                          fontFamily: 'monospace',
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Temporary Password',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: theme.colorScheme.outline.withValues(alpha: 0.25),
                        ),
                      ),
                      child: Text(
                        previewPassword,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: _birthday != null
                              ? AppTheme.catGreen
                              : theme.colorScheme.onSurface.withValues(alpha: 0.5),
                          fontFamily: 'monospace',
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRelationshipField(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Relationship *',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          initialValue: _relationship,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          decoration: InputDecoration(
            filled: true,
            fillColor: theme.colorScheme.surface,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: theme.colorScheme.outline.withValues(alpha: 0.4),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: theme.colorScheme.outline.withValues(alpha: 0.4),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: theme.colorScheme.primary,
                width: 2,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: theme.colorScheme.error),
            ),
          ),
          items: const [
            'Mother',
            'Father',
            'Guardian',
            'Other',
          ].map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
          onChanged: (val) {
            setState(() {
              _relationship = val;
              if (val != 'Other') {
                _customRelationshipCtrl.clear();
              }
            });
          },
          validator: (v) => v == null ? 'Relationship is required.' : null,
        ),
      ],
    );
  }

  int? get _calculatedAge {
    if (_birthday == null) return null;
    final now = DateTime.now();
    int age = now.year - _birthday!.year;
    if (now.month < _birthday!.month ||
        (now.month == _birthday!.month && now.day < _birthday!.day)) {
      age--;
    }
    return age;
  }

  Widget _buildAgeField(ThemeData theme) {
    final ageText = _calculatedAge != null ? '$_calculatedAge yrs old' : '—';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Age',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: theme.colorScheme.outline.withValues(alpha: 0.4),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.cake_outlined,
                size: 18,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  ageText,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: _calculatedAge != null
                        ? FontWeight.w600
                        : FontWeight.normal,
                    color: _calculatedAge != null
                        ? theme.colorScheme.onSurface
                        : theme.colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLinkStudentSection(ThemeData theme) {
    final candidateStudents = widget.students ?? const <UserModel>[];

    final query = _studentSearchQuery.trim().toLowerCase();
    final matchingStudents = query.isEmpty
        ? <UserModel>[]
        : candidateStudents
            .where((u) {
              final nameMatch = u.fullName.toLowerCase().contains(query);
              final lrnMatch = (u.lrn ?? '').toLowerCase().contains(query);
              final isAlreadySelected = _selectedStudents.any(
                (s) => s.id == u.id,
              );
              return !isAlreadySelected && (nameMatch || lrnMatch);
            })
            .take(6)
            .toList();

    return FormField<List<UserModel>>(
      initialValue: _selectedStudents,
      validator: (_) {
        if (_selectedStudents.isEmpty) {
          return 'Please select at least one student to link.';
        }
        return null;
      },
      builder: (field) {
        final hasError = field.hasError;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _studentSearchCtrl,
              onChanged: (val) => setState(() => _studentSearchQuery = val),
              decoration: InputDecoration(
                hintText: widget.filterSection != null
                    ? 'Search student in ${widget.filterSection} by name or LRN...'
                    : 'Search student by name or LRN...',
                hintStyle: TextStyle(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  fontSize: 13,
                ),
                prefixIcon: Icon(
                  Icons.search,
                  size: 20,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
                suffixIcon: _studentSearchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _studentSearchCtrl.clear();
                          setState(() => _studentSearchQuery = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: theme.colorScheme.surface,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: theme.colorScheme.outline.withValues(alpha: 0.4),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: hasError
                        ? theme.colorScheme.error
                        : theme.colorScheme.outline.withValues(alpha: 0.4),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: hasError
                        ? theme.colorScheme.error
                        : theme.colorScheme.primary,
                    width: 2,
                  ),
                ),
              ),
            ),
            if (_studentSearchQuery.trim().isNotEmpty) ...[
              const SizedBox(height: 6),
              Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: theme.colorScheme.primary.withValues(alpha: 0.3),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: matchingStudents.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.all(16),
                        child: Center(
                          child: Text(
                            widget.filterSection != null
                                ? 'No matching students found in ${widget.filterSection} for "$_studentSearchQuery"'
                                : 'No matching students found for "$_studentSearchQuery"',
                            style: TextStyle(
                              fontSize: 13,
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.6,
                              ),
                            ),
                          ),
                        ),
                      )
                    : Column(
                        children: matchingStudents.map((s) {
                          return InkWell(
                            onTap: () {
                              setState(() {
                                if (!_selectedStudents.any((sel) => sel.id == s.id)) {
                                  _selectedStudents.add(s);
                                  field.didChange(_selectedStudents);
                                }
                                _studentSearchCtrl.clear();
                                _studentSearchQuery = '';
                              });
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 16,
                                    backgroundColor: theme.colorScheme.primary
                                        .withValues(alpha: 0.1),
                                    child: Text(
                                      s.fullName.isNotEmpty
                                          ? s.fullName[0].toUpperCase()
                                          : 'S',
                                      style: TextStyle(
                                        color: theme.colorScheme.primary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          s.fullName,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Text(
                                          'LRN: ${s.lrn ?? s.studentId ?? "N/A"} • ${s.departmentOrSection ?? "Enrolled"}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: theme.colorScheme.onSurface
                                                .withValues(alpha: 0.6),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.primary
                                          .withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.add,
                                          size: 14,
                                          color: theme.colorScheme.primary,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Link',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: theme.colorScheme.primary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
              ),
            ],
            const SizedBox(height: 12),
            if (_selectedStudents.isEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: theme.colorScheme.outline.withValues(alpha: 0.22),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 18,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'No students linked yet. Search and select up to 15 students to link.',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (hasError)
                Padding(
                  padding: const EdgeInsets.only(top: 8, left: 4),
                  child: Row(
                    children: [
                      Icon(
                        Icons.error_outline_rounded,
                        size: 15,
                        color: theme.colorScheme.error,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        field.errorText ?? 'Please select at least one student to link.',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.error,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
            ] else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _selectedStudents.map((student) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: theme.colorScheme.primary.withValues(alpha: 0.25),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.school_outlined,
                          size: 16,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              student.fullName,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            Text(
                              'LRN: ${student.lrn ?? "N/A"} • ${student.departmentOrSection ?? "Enrolled"}',
                              style: TextStyle(
                                fontSize: 10.5,
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 10),
                        InkWell(
                          onTap: () => setState(() {
                            _selectedStudents.remove(student);
                            field.didChange(_selectedStudents);
                          }),
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: Colors.redAccent.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              size: 14,
                              color: Colors.redAccent,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
          ],
        );
      },
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  final Widget? trailing;
  const _SectionLabel(this.label, {this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Divider(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            trailing!,
          ],
        ],
      ),
    );
  }
}

class _CredentialRow extends StatelessWidget {
  final String label;
  final String value;
  const _CredentialRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      value,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        fontFamily: label.contains('Password') ? 'monospace' : null,
                      ),
                    ),
                  ),
                  if (label.contains('Password'))
                    InkWell(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: value));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Password copied to clipboard')),
                        );
                      },
                      child: Icon(
                        Icons.copy,
                        size: 16,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
