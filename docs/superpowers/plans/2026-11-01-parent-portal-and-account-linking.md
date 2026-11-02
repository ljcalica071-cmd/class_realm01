# Parent Management, Sibling Linking, First Login & Child Switcher Redesign

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Provide an end-to-end parent management and portal experience where teachers create and link parent accounts to students, prevent duplicate accounts through sibling linking and birthday matching (no contact numbers required), enforce secure first-login identity verification using child LRN and parent birthday, and offer an intuitive top-right Child Switcher dropdown for parents with 2 or more children.

**Architecture:** 
1. **Teacher Manage Parents (`AddParentDialog` & `SupabaseParentRepository`)**: Single point of parent provisioning with two modes: "New Parent" and "Link to Existing Parent", checking duplicates via `first_name`, `last_name`, and `birthday` (without contact numbers).
2. **Parent First Login (`login_screen.dart` & `first_login_screen.dart`)**: Routes `pendingFirstLogin` parents to `FirstLoginScreen` where they verify identity via Parent Birthday and Child's 12-digit LRN (last 4 digits), then set their private password.
3. **Parent Portal Redesign (`parent_home_screen.dart` & `parent_student_overview_tab.dart`)**: Replaces horizontal chips with an elegant top-right `ChildSwitcherDropdown` in the app bar that supports 1 to 5+ children seamlessly, automatically updating attendance, grades, and subjects.

**Tech Stack:** Flutter, Dart, Supabase (PostgreSQL), Firebase Authentication, Shimmer Loading, Lucide / Material Icons.

---

## Global Constraints
- Do NOT ask for or require a parent phone/contact number; use Parent Birthday for verification and matching.
- Do NOT add a "Link Parent" button in Manage Students; parent creation and linking must remain solely within `TeacherParentManagementTab`.
- Synthetic parent login credentials format: Email `[sanitizedLastName]@classrealm.com` (or `[sanitizedLastName][index]@classrealm.com` on collision) and Temporary Password `[sanitizedLastName][YYYYMMDD]`.
- Child Switcher in Parent Portal must be a clean dropdown in the top-right corner, cleanly supporting 3+ children without cluttering the screen.
- Follow `/ui-ux-pro-max` and 60-30-10 color harmony.

---

## Tasks

### Task 1: Refactor Parent Creation & Sibling Linking in Supabase Repository
**Files:**
- Modify: `lib/data/repositories/supabase_parent_repository.dart`

**Changes:**
1. Remove all dependencies on `contactNumber` for parent account creation and duplicate detection.
2. In `createParentAccount`, match existing parents strictly using `first_name`, `last_name`, and `birthday`.
3. Add `searchExistingParents({required String query})` to allow teachers to search existing parents in the school by parent name or linked child LRN/name.
4. Add `linkStudentsToExistingParent({required String parentId, required List<String> studentIds, required String relationship})` to link a student to an already-registered parent without creating duplicate login credentials.

---

### Task 2: Enhance Teacher `AddParentDialog` with "New Parent" vs "Link to Existing Parent"
**Files:**
- Modify: `lib/features/teacher/sub_features/class_management/widgets/add_parent_dialog.dart`

**Changes:**
1. Remove contact number input completely.
2. Add a two-mode segmented toggle at the top of the dialog:
   - **Mode 1: "New Parent" (Bagong Parent)**: Input First, Middle, Last Name, Birthday, Relationship, and select student(s) from teacher's roster.
   - **Mode 2: "Link to Existing Parent" (I-link sa Rehistradong Magulang)**: Search bar for existing parents. Displays matching parents with their currently linked children (e.g. *"Maria Santos - Parent of Juan Santos (Grade 7 - Section 1)"*), with a multi-select for students under this teacher and a "Link Student" button.
3. When creating a new parent, if a duplicate is detected (exact name and birthday), display a confirmation dialog offering to link the student directly to the existing account rather than generating duplicate credentials.

---

### Task 3: Fix Parent First-Login Routing and Security Verification
**Files:**
- Modify: `lib/features/auth/screens/login_screen.dart`
- Modify: `lib/features/auth/screens/first_login_screen.dart`

**Changes:**
1. In `login_screen.dart` (`_routeUser`), fix the routing bug: When a parent logs in with status `pendingFirstLogin` or `pending`, route them to `AppRoutes.studentFirstLogin` (which renders `FirstLoginScreen`).
2. In `first_login_screen.dart`, enhance the parent-specific verification flow:
   - Challenge 1: **Parent's Registered Birthday** (via Date Picker).
   - Challenge 2: **Last 4 Digits of Linked Child's 12-digit LRN**.
   - Challenge 3: **New Private Password** + **Confirm Password** (enforcing complexity rules).
3. Upon successful verification and password update, set `status = 'active'` in `parent_profiles` and navigate cleanly to `AppRoutes.parentHome`.

---

### Task 4: Redesign Child Switcher in Parent Portal (Top-Right Dropdown)
**Files:**
- Modify: `lib/features/parent/screens/parent_home_screen.dart`
- Modify: `lib/features/parent/sub_features/children_overview/widgets/parent_student_overview_tab.dart`

**Changes:**
1. In `parent_home_screen.dart` AppBar `actions`:
   - Replace the single cycle icon and banner with a dedicated **`ChildSwitcherDropdown`** widget.
   - For parents with 1 child: Displays a clean badge or indicator with the child's name.
   - For parents with 2 or more children: Displays an interactive dropdown button with child's name, avatar, and chevron icon.
   - Tapping it opens a sleek popup menu showing all linked children:
     - Avatar circle with initials.
     - Student Full Name (`LASTNAME, Firstname M.`).
     - LRN & Section/Grade badge.
     - Active indicator / checkmark.
   - Selecting a child triggers `_switchChild(index)`, instantly reloading attendance, grades, and overview for the selected child.
2. In `parent_student_overview_tab.dart`:
   - Remove the clunky horizontal wrap chips (`allChildren != null && allChildren!.length > 1`) from the body so the screen remains clean and focused on performance analytics.
