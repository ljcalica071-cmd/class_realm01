import 'package:flutter/material.dart';
import 'package:class_realm/core/theme/app_theme.dart';
import 'package:class_realm/models/user_model.dart';
import 'package:class_realm/data/repositories/auth_repository.dart';
import 'package:class_realm/utils/formatters.dart';
import 'package:class_realm/shared/widgets/shimmer_loading.dart';
import 'package:flutter/services.dart';

class TeacherProfileTab extends StatefulWidget {
  const TeacherProfileTab({super.key});

  @override
  State<TeacherProfileTab> createState() => _TeacherProfileTabState();
}

class _TeacherProfileTabState extends State<TeacherProfileTab> {
  late UserModel _teacher;
  bool _isEditing = false;
  final bool _isLoading = false;

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

  void _loadTeacherData() {
    _teacher = AuthRepository.instance.currentUser ??
        const UserModel(
          id: 'T001',
          username: 'teacher',
          fullName: 'Teacher',
          email: 'teacher@classrealm.edu',
          role: UserRole.teacher,
        );

    _subjectSpecializationCtrl = TextEditingController(text: _teacher.subjectSpecialization ?? _teacher.departmentOrSection);
    _facebookLinkCtrl = TextEditingController(text: _teacher.facebookLink);
    _phoneCtrl = TextEditingController(text: _teacher.contactNumber);
    _consultationHoursCtrl = TextEditingController(text: _teacher.consultationHours);
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
    if (today.month < birthday.month || (today.month == birthday.month && today.day < birthday.day)) {
      age--;
    }
    return age;
  }

  void _saveProfile() {
    // Update local state and mock database
    setState(() {
      _teacher = _teacher.copyWith(
        subjectSpecialization: _subjectSpecializationCtrl.text.trim(),
        facebookLink: _facebookLinkCtrl.text.trim(),
        contactNumber: _phoneCtrl.text.trim(),
        consultationHours: _consultationHoursCtrl.text.trim(),
        isFacebookPublic: _isFacebookPublic,
        isPhonePublic: _isPhonePublic,
      );
      _isEditing = false;
    });

    // In a real application, you would call your repository here to update the Supabase 'teacher_profile' table.
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile updated successfully.')),
    );
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
          children: [
            // --- HEADER (Cover & Profile Pic) ---
            Container(
              color: theme.colorScheme.surface,
              child: Column(
                children: [
                  // Cover Photo (Gradient Placeholder)
                  Container(
                    height: 300,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          theme.colorScheme.primary,
                          theme.colorScheme.tertiary,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                  ),
                  
                  // Profile Content (Avatar, Name, Edit Button)
                  Container(
                    constraints: const BoxConstraints(maxWidth: 1000),
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        // Avatar
                        Positioned(
                          top: -60,
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: theme.colorScheme.surface, width: 4),
                            ),
                            child: CircleAvatar(
                              radius: 80,
                              backgroundColor: AppTheme.catPurple,
                              backgroundImage: _teacher.profileImage != null ? NetworkImage(_teacher.profileImage!) : null,
                              child: _teacher.profileImage == null
                                  ? Text(
                                      _teacher.fullName.isNotEmpty ? _teacher.fullName[0].toUpperCase() : 'T',
                                      style: const TextStyle(fontSize: 48, color: Colors.white, fontWeight: FontWeight.bold),
                                    )
                                  : null,
                            ),
                          ),
                        ),
                        
                        // Name and Edit Button
                        Padding(
                          padding: const EdgeInsets.only(top: 110, bottom: 24),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _teacher.fullName,
                                    style: TextStyle(
                                      fontSize: 32,
                                      fontWeight: FontWeight.bold,
                                      color: theme.colorScheme.onSurface,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    _teacher.subjectSpecialization ?? 'Educator',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                                    ),
                                  ),
                                ],
                              ),
                              ElevatedButton.icon(
                                onPressed: () {
                                  if (_isEditing) {
                                    _saveProfile();
                                  } else {
                                    setState(() => _isEditing = true);
                                  }
                                },
                                icon: Icon(_isEditing ? Icons.save : Icons.edit, size: 18),
                                label: Text(_isEditing ? 'Save Changes' : 'Edit Profile'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _isEditing ? AppTheme.catGreen : theme.colorScheme.primary,
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  // Facebook-style tabs could go here (e.g., Posts, About, Friends)
                  // For this app, we'll just show "About" selected.
                  Container(
                    constraints: const BoxConstraints(maxWidth: 1000),
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    alignment: Alignment.centerLeft,
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            border: Border(bottom: BorderSide(color: theme.colorScheme.primary, width: 3)),
                          ),
                          child: Text(
                            'About',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            // --- ABOUT SECTION ---
            Container(
              constraints: const BoxConstraints(maxWidth: 1000),
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left side (Basic Info)
                  Expanded(
                    flex: 1,
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Basic Information', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface)),
                          const SizedBox(height: 24),
                          _buildInfoRow(theme, Icons.person, 'First Name', _teacher.firstName ?? ''),
                          if (_teacher.middleName != null && _teacher.middleName!.isNotEmpty)
                            _buildInfoRow(theme, Icons.person_outline, 'Middle Name', _teacher.middleName!),
                          _buildInfoRow(theme, Icons.person, 'Last Name', _teacher.lastName ?? ''),
                          _buildInfoRow(theme, Icons.cake, 'Birthday', _teacher.birthday != null ? '${_teacher.birthday!.year}-${_teacher.birthday!.month.toString().padLeft(2, '0')}-${_teacher.birthday!.day.toString().padLeft(2, '0')}' : 'Not provided'),
                          _buildInfoRow(theme, Icons.timelapse, 'Age', _teacher.birthday != null ? '${_calculateAge(_teacher.birthday)} years old' : 'Unknown'),
                          _buildInfoRow(theme, Icons.wc, 'Gender', _teacher.gender ?? 'Not specified'),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 24),
                  
                  // Right side (Contact & Optional Info)
                  Expanded(
                    flex: 2,
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Contact & Professional Info', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface)),
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
                            _buildInfoRow(theme, Icons.science, 'Subject Specialization', _teacher.subjectSpecialization != null && _teacher.subjectSpecialization!.isNotEmpty ? _teacher.subjectSpecialization! : 'Not specified'),
                            _buildInfoRow(theme, Icons.schedule, 'Consultation Hours', _teacher.consultationHours != null && _teacher.consultationHours!.isNotEmpty ? _teacher.consultationHours! : 'Not specified'),
                            _buildInfoRow(
                              theme, 
                              Icons.facebook, 
                              'Facebook', 
                              _teacher.facebookLink != null && _teacher.facebookLink!.isNotEmpty ? _teacher.facebookLink! : 'Not linked',
                              privacyBadge: _buildPrivacyBadge(theme, _teacher.isFacebookPublic),
                            ),
                            _buildInfoRow(
                              theme, 
                              Icons.phone, 
                              'Phone', 
                              _teacher.contactNumber != null && _teacher.contactNumber!.isNotEmpty ? _teacher.contactNumber! : 'Not provided',
                              privacyBadge: _buildPrivacyBadge(theme, _teacher.isPhonePublic),
                            ),
                          ]
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 60), // bottom padding
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(ThemeData theme, IconData icon, String label, String value, {Widget? privacyBadge}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: theme.colorScheme.onSurface.withValues(alpha: 0.5), size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        value, 
                        style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 15),
                      ),
                    ),
                    if (privacyBadge != null) ...[
                      const SizedBox(width: 12),
                      privacyBadge,
                    ]
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
      message: isPublic ? 'Visible to Students and Parents' : 'Private (Only visible to you and Admin)',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isPublic ? theme.colorScheme.primary.withValues(alpha: 0.1) : theme.colorScheme.onSurface.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(isPublic ? Icons.public : Icons.lock, size: 12, color: isPublic ? theme.colorScheme.primary : theme.colorScheme.onSurface.withValues(alpha: 0.6)),
            const SizedBox(width: 4),
            Text(
              isPublic ? 'Public' : 'Private',
              style: TextStyle(
                fontSize: 10, 
                fontWeight: FontWeight.bold, 
                color: isPublic ? theme.colorScheme.primary : theme.colorScheme.onSurface.withValues(alpha: 0.6)
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditField(ThemeData theme, IconData icon, String label, TextEditingController controller, String hint) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Icon(icon, color: theme.colorScheme.onSurface.withValues(alpha: 0.5), size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextField(
                controller: controller,
                style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 14),
                inputFormatters: [
                  LengthLimitingTextInputFormatter(30),
                  StrictInputFormatter(),
                ],
                decoration: InputDecoration(
                  hintText: hint,
                  hintStyle: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.4), fontSize: 14),
                  isDense: true,
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: theme.colorScheme.onSurface.withValues(alpha: 0.15)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: theme.colorScheme.onSurface.withValues(alpha: 0.15)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: theme.colorScheme.primary),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEditFieldWithToggle(ThemeData theme, IconData icon, String label, TextEditingController controller, String hint, bool isPublic, ValueChanged<bool?> onToggle) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Icon(icon, color: theme.colorScheme.onSurface.withValues(alpha: 0.5), size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(label, style: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.6), fontSize: 13, fontWeight: FontWeight.w600)),
                  Row(
                    children: [
                      Icon(isPublic ? Icons.public : Icons.lock, size: 14, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                      const SizedBox(width: 8),
                      Text('Make Public', style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.8))),
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
                style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 14),
                inputFormatters: [
                  LengthLimitingTextInputFormatter(30),
                  StrictInputFormatter(),
                ],
                decoration: InputDecoration(
                  hintText: hint,
                  hintStyle: TextStyle(color: theme.colorScheme.onSurface.withValues(alpha: 0.4), fontSize: 14),
                  isDense: true,
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.2),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: theme.colorScheme.onSurface.withValues(alpha: 0.15)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: theme.colorScheme.onSurface.withValues(alpha: 0.15)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: theme.colorScheme.primary),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  isPublic 
                    ? 'Anyone in your classes can see this.' 
                    : 'Only you can see this. If made public, students and parents can view this.',
                  style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurface.withValues(alpha: 0.5), fontStyle: FontStyle.italic),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
