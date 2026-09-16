# Implementation Plan - Manage Students UI Redesign

Redesign the teacher's Student management feature to precisely match the reference web portal design (as shown in the screenshots).

## Proposed Changes

### Teacher Dashboard (`teacher_dashboard_screen.dart`)
- Update sidebar nav label from "Students" to "Manage Students".
- Update header title to "Manage Students" with class filter dropdown ("— Select a class —") and search bar ("Search by name or LRN...").
- Add top action buttons: "Export Excel" and "Add Students".
- Redesign student management view into a comprehensive table with exact columns:
  1. Checkbox (Multi-select / Select All)
  2. `#` (Index)
  3. `LAST NAME` (Sortable)
  4. `FIRST NAME` (Sortable)
  5. `LRN` (with ID badge style)
  6. `GENDER`
  7. `BIRTHDATE` (with calculated Age in parentheses e.g. `2026-08-25 (0)`)
  8. `PARENT`
  9. `EMAIL`
  10. `CONTACT NO.`
  11. `REMARKS`
  12. `FILES` (with "Upload" button / attachment icon)
  13. `STATUS` (Active / Pending / Deactivated badge)
  14. `ACTIONS` (Edit, Archive/Delete, Transfer Section)
- Implement floating multi-selection action bar ("X selected", "Clear", "Remove Selected").

## Verification Plan
- Verify build & manual verification of Manage Students table and columns.
