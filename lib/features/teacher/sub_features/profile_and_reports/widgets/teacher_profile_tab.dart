import 'package:flutter/material.dart';
import 'package:class_realm/core/utils/validators.dart';
import 'package:class_realm/models/user_model.dart';
import 'package:class_realm/data/repositories/auth_repository.dart';
import 'package:class_realm/utils/formatters.dart';
import 'package:class_realm/shared/widgets/shared_widgets.dart';
import 'package:class_realm/shared/widgets/shimmer_loading.dart';
import 'package:class_realm/features/teacher/sub_features/profile_and_reports/widgets/edit_teacher_profile_dialog.dart';
import 'package:flutter/services.dart';

class TeacherProfileTab extends StatefulWidget {
  final int initialTab;

  const TeacherProfileTab({super.key, this.initialTab = 0});

  @override
  State<TeacherProfileTab> createState() => _TeacherProfileTabState();
}

class _TeacherProfileTabState extends State<TeacherProfileTab> {
  late UserModel _teacher;
  late int _selectedTab = widget.initialTab;
  final bool _isEditing = false;
  final bool _isLoading = false;
  bool _controllersInitialized = false;

  late TextEditingController _subjectSpecializationCtrl;
  late TextEditingController _facebookLinkCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _consultationHoursCtrl;

  bool _isFacebookPublic = false;
  bool _isPhonePublic = false;

  @override
  void initState() {
    super.initState();
    _loadTeacherData();
  }

  @override
  void didUpdateWidget(covariant TeacherProfileTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTab != widget.initialTab) {
      setState(() {
        _selectedTab = widget.initialTab;
      });
    }
  }

  void _loadTeacherData() {
    _teacher =
        AuthRepository.instance.currentUser ??
        const UserModel(
          id: 'T001',
          username: 'teacher',
          fullName: 'Teacher',
          email: 'teacher@classrealm.edu',
          role: UserRole.teacher,
        );

    final specText =
        _teacher.subjectSpecialization ?? _teacher.departmentOrSection ?? '';
    final fbText = _teacher.facebookLink ?? '';
    final phoneText = _teacher.contactNumber ?? '';
    final consultText = _teacher.consultationHours ?? '';

    if (!_controllersInitialized) {
      _subjectSpecializationCtrl = TextEditingController(text: specText);
      _facebookLinkCtrl = TextEditingController(text: fbText);
      _phoneCtrl = TextEditingController(text: phoneText);
      _consultationHoursCtrl = TextEditingController(text: consultText);
      _controllersInitialized = true;
    } else {
      _subjectSpecializationCtrl.text = specText;
      _facebookLinkCtrl.text = fbText;
      _phoneCtrl.text = phoneText;
      _consultationHoursCtrl.text = consultText;
    }
    _isFacebookPublic = _teacher.isFacebookPublic;
    _isPhonePublic = _teacher.isPhonePublic;
  }

  @override
  void dispose() {
    _subjectSpecializationCtrl.dispose();
    _facebookLinkCtrl.dispose();
    _phoneCtrl.dispose();
    _consultationHoursCtrl.dispose();
    super.dispose();
  }

  int _calculateAge(DateTime? birthday) {
    if (birthday == null) return 0;
    final today = DateTime.now();
    int age = today.year - birthday.year;
    if (today.month < birthday.month ||
        (today.month == birthday.month && today.day < birthday.day)) {
      age--;
    }
    return age;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const ShimmerProfileSkeleton();
    }

    final theme = Theme.of(context);

    // Facebook-style layout usually has a light grey background
    return Container(
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- HEADER (Avatar, Name, Edit Button) ---
            Container(
              color: theme.colorScheme.surface,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1040),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 24,
                        ),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final isNarrow = constraints.maxWidth < 650;

                            final avatarWidget = Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: theme.colorScheme.primary.withValues(
                                    alpha: 0.18,
                                  ),
                                  width: 3,
                                ),
                              ),
                              child: CircleAvatar(
                                radius: 46,
                                backgroundColor: theme.colorScheme.primary,
                                backgroundImage: _teacher.profileImage != null
                                    ? NetworkImage(_teacher.profileImage!)
                                    : null,
                                child: _teacher.profileImage == null
                                    ? Text(
                                        _teacher.fullName.isNotEmpty
                                            ? _teacher.fullName[0].toUpperCase()
                                            : 'T',
                                        style: const TextStyle(
                                          fontSize: 34,
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      )
                                    : null,
                              ),
                            );

                            final nameAndRoleWidget = Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Wrap(
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  spacing: 10,
                                  runSpacing: 4,
                                  children: [
                                    Text(
                                      _teacher.fullName,
                                      style: TextStyle(
                                        fontSize: 26,
                                        fontWeight: FontWeight.bold,
                                        color: theme.colorScheme.onSurface,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.primary.withValues(
                                          alpha: 0.1,
                                        ),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        'FACULTY',
                                        style: TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.8,
                                          color: theme.colorScheme.primary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _teacher.subjectSpecialization != null &&
                                          _teacher.subjectSpecialization!.isNotEmpty
                                      ? _teacher.subjectSpecialization!
                                      : 'Educator',
                                  style: TextStyle(
                                    fontSize: 14.5,
                                    color: theme.colorScheme.onSurface.withValues(
                                      alpha: 0.65,
                                    ),
                                  ),
                                ),
                              ],
                            );

                            final editBtn = ElevatedButton.icon(
                              onPressed: () {
                                EditTeacherProfileDialog.show(
                                  context,
                                  teacher: _teacher,
                                  onProfileUpdated: (updatedTeacher) {
                                    if (mounted) {
                                      setState(() {
                                        _teacher = updatedTeacher;
                                        _loadTeacherData();
                                      });
                                    }
                                  },
                                );
                              },
                              icon: const Icon(Icons.edit_outlined, size: 17),
                              label: const Text('Edit Profile'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: theme.colorScheme.primary,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 18,
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            );

                            if (isNarrow) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      avatarWidget,
                                      const SizedBox(width: 16),
                                      Expanded(child: nameAndRoleWidget),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  SizedBox(width: double.infinity, child: editBtn),
                                ],
                              );
                            }

                            return Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: Row(
                                    children: [
                                      avatarWidget,
                                      const SizedBox(width: 20),
                                      Expanded(child: nameAndRoleWidget),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 16),
                                editBtn,
                              ],
                            );
                          },
                        ),
                      ),
                      const Divider(height: 1),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        alignment: Alignment.centerLeft,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              _buildProfileTab(
                                index: 0,
                                label: 'About',
                                icon: Icons.person_outline_rounded,
                                theme: theme,
                              ),
                              const SizedBox(width: 8),
                              _buildProfileTab(
                                index: 1,
                                label: 'Settings',
                                icon: Icons.settings_outlined,
                                theme: theme,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // --- TAB CONTENT (ABOUT or SETTINGS) ---
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1040),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, animation) {
                    final isSettings = child.key == const ValueKey<int>(1);
                    final offset = Tween<Offset>(
                      begin: isSettings
                          ? const Offset(0.04, 0)
                          : const Offset(-0.04, 0),
                      end: Offset.zero,
                    ).animate(animation);
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(position: offset, child: child),
                    );
                  },
                  child: _selectedTab == 0
                      ? _buildAboutSection(theme)
                      : _buildSettingsSection(theme),
                ),
              ),
            ),
            const SizedBox(height: 60), // bottom padding
          ],
        ),
      ),
    );
  }

  Widget _buildProfileTab({
    required int index,
    required String label,
    required IconData icon,
    required ThemeData theme,
  }) {
    final isSelected = _selectedTab == index;
    return InkWell(
      onTap: () {
        if (_selectedTab != index) {
          setState(() {
            _selectedTab = index;
          });
        }
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected
                  ? theme.colorScheme.primary
                  : Colors.transparent,
              width: 3,
            ),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                color: isSelected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAboutSection(ThemeData theme) {
    return Container(
      key: const ValueKey<int>(0),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isStacked = constraints.maxWidth < 850;

          final basicInfoCard = Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Basic Information',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 24),
                _buildInfoRow(
                  theme,
                  Icons.person,
                  'First Name',
                  _teacher.firstName ?? '',
                ),
                if (_teacher.middleName != null &&
                    _teacher.middleName!.isNotEmpty)
                  _buildInfoRow(
                    theme,
                    Icons.person_outline,
                    'Middle Initial',
                    AppValidators.formatMiddleInitial(_teacher.middleName),
                  ),
                _buildInfoRow(
                  theme,
                  Icons.person,
                  'Last Name',
                  _teacher.lastName ?? '',
                ),
                _buildInfoRow(
                  theme,
                  Icons.cake,
                  'Birthday',
                  _teacher.birthday != null
                      ? '${_teacher.birthday!.year}-${_teacher.birthday!.month.toString().padLeft(2, '0')}-${_teacher.birthday!.day.toString().padLeft(2, '0')}'
                      : 'Not provided',
                ),
                _buildInfoRow(
                  theme,
                  Icons.timelapse,
                  'Age',
                  _teacher.birthday != null
                      ? '${_calculateAge(_teacher.birthday)} years old'
                      : 'Unknown',
                ),
                _buildInfoRow(
                  theme,
                  Icons.wc,
                  'Gender',
                  _teacher.gender ?? 'Not specified',
                ),
              ],
            ),
          );

          final contactInfoCard = Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Contact & Professional Info',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 24),

                // Email is always visible and uneditable here
                _buildInfoRow(theme, Icons.email, 'Email', _teacher.email),
                const Divider(height: 32),

                // Optional Fields
                if (_isEditing) ...[
                  _buildEditField(
                    theme,
                    Icons.science,
                    'Subject Specialization',
                    _subjectSpecializationCtrl,
                    'e.g. General Mathematics',
                  ),
                  const SizedBox(height: 24),
                  _buildEditField(
                    theme,
                    Icons.schedule,
                    'Consultation Hours',
                    _consultationHoursCtrl,
                    'e.g. Mon & Wed 3:00 PM - 5:00 PM',
                  ),
                  const SizedBox(height: 24),
                  _buildEditFieldWithToggle(
                    theme,
                    Icons.facebook,
                    'Facebook Profile Link',
                    _facebookLinkCtrl,
                    'e.g. https://facebook.com/karen.gonzaga',
                    _isFacebookPublic,
                    (val) => setState(() => _isFacebookPublic = val ?? false),
                  ),
                  const SizedBox(height: 24),
                  _buildEditFieldWithToggle(
                    theme,
                    Icons.phone,
                    'Phone Number',
                    _phoneCtrl,
                    'e.g. 09123456789',
                    _isPhonePublic,
                    (val) => setState(() => _isPhonePublic = val ?? false),
                  ),
                ] else ...[
                  _buildInfoRow(
                    theme,
                    Icons.science,
                    'Subject Specialization',
                    _teacher.subjectSpecialization != null &&
                            _teacher.subjectSpecialization!.isNotEmpty
                        ? _teacher.subjectSpecialization!
                        : 'Not specified',
                  ),
                  _buildInfoRow(
                    theme,
                    Icons.schedule,
                    'Consultation Hours',
                    _teacher.consultationHours != null &&
                            _teacher.consultationHours!.isNotEmpty
                        ? _teacher.consultationHours!
                        : 'Not specified',
                  ),
                  _buildInfoRow(
                    theme,
                    Icons.facebook,
                    'Facebook',
                    _teacher.facebookLink != null &&
                            _teacher.facebookLink!.isNotEmpty
                        ? _teacher.facebookLink!
                        : 'Not linked',
                    privacyBadge: _buildPrivacyBadge(
                      theme,
                      _teacher.isFacebookPublic,
                    ),
                  ),
                  _buildInfoRow(
                    theme,
                    Icons.phone,
                    'Phone',
                    _teacher.contactNumber != null &&
                            _teacher.contactNumber!.isNotEmpty
                        ? _teacher.contactNumber!
                        : 'Not provided',
                    privacyBadge: _buildPrivacyBadge(
                      theme,
                      _teacher.isPhonePublic,
                    ),
                  ),
                ],
              ],
            ),
          );

          if (isStacked) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                basicInfoCard,
                const SizedBox(height: 24),
                contactInfoCard,
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 1, child: basicInfoCard),
              const SizedBox(width: 24),
              Expanded(flex: 2, child: contactInfoCard),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSettingsSection(ThemeData theme) {
    return Container(
      key: const ValueKey<int>(1),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: theme.colorScheme.outlineVariant.withValues(
                  alpha: 0.3,
                ),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.settings_outlined,
                    color: theme.colorScheme.primary,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Settings & Privacy',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Manage your account security, passwords, and view official ClassRealm legal policies.',
                        style: TextStyle(
                          fontSize: 13,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.65,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const PortalSettingsContent(portalLabel: 'Teacher'),
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    ThemeData theme,
    IconData icon,
    String label,
    String value, {
    Widget? privacyBadge,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            size: 24,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        value,
                        style: TextStyle(
                          color: theme.colorScheme.onSurface,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    if (privacyBadge != null) ...[
                      const SizedBox(width: 12),
                      privacyBadge,
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrivacyBadge(ThemeData theme, bool isPublic) {
    return Tooltip(
      message: isPublic
          ? 'Visible to Students and Parents'
          : 'Private (Only visible to you and Admin)',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isPublic
              ? theme.colorScheme.primary.withValues(alpha: 0.1)
              : theme.colorScheme.onSurface.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isPublic ? Icons.public : Icons.lock,
              size: 12,
              color: isPublic
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
            const SizedBox(width: 4),
            Text(
              isPublic ? 'Public' : 'Private',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: isPublic
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditField(
    ThemeData theme,
    IconData icon,
    String label,
    TextEditingController controller,
    String hint,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Icon(
            icon,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            size: 24,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: controller,
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontSize: 14,
                ),
                inputFormatters: [
                  LengthLimitingTextInputFormatter(30),
                  StrictInputFormatter(),
                ],
                decoration: InputDecoration(
                  hintText: hint,
                  hintStyle: TextStyle(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                    fontSize: 14,
                  ),
                  isDense: true,
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.2),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: 0.15,
                      ),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: 0.15,
                      ),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: theme.colorScheme.primary),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEditFieldWithToggle(
    ThemeData theme,
    IconData icon,
    String label,
    TextEditingController controller,
    String hint,
    bool isPublic,
    ValueChanged<bool?> onToggle,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Icon(
            icon,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            size: 24,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Row(
                    children: [
                      Icon(
                        isPublic ? Icons.public : Icons.lock,
                        size: 14,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.6,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Make Public',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.8,
                          ),
                        ),
                      ),
                      Switch(
                        value: isPublic,
                        onChanged: onToggle,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 4),
              TextField(
                controller: controller,
                style: TextStyle(
                  color: theme.colorScheme.onSurface,
                  fontSize: 14,
                ),
                inputFormatters: [
                  LengthLimitingTextInputFormatter(30),
                  StrictInputFormatter(),
                ],
                decoration: InputDecoration(
                  hintText: hint,
                  hintStyle: TextStyle(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                    fontSize: 14,
                  ),
                  isDense: true,
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.2),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: 0.15,
                      ),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: 0.15,
                      ),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: theme.colorScheme.primary),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  isPublic ? 'Anyone in your classes can see this.' : 'Only you can see this. If made public, students and parents can view this.',
                  style: TextStyle(
                    fontSize: 11,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
