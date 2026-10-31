## 2026-10-30T23:12:57Z
You are an expert Flutter codebase Explorer.
Your working directory is: c:\Users\Admin\AndroidStudioProjects\class_realm01\.agents\teamwork\explorer_survey_gradebook_dir\

MANDATORY FIRST STEP:
Read the authoritative request file:
c:\Users\Admin\AndroidStudioProjects\class_realm01\.agents\teamwork\ORIGINAL_REQUEST.md

YOUR OBJECTIVE:
Thoroughly explore, inspect, and survey the codebase for Requirements R1 and R2:
1. R1: Gradebook Optimization and Crash/Duplication Fixes:
   - Identify where Gradebook column rendering occurs in `teacher_gradebook_tab.dart` or related files.
   - Trace the exact cause of the Flutter crash caused by duplicate keys: `Duplicate keys found. Column(direction: vertical...) has multiple children with key [gradebook-row-zV0ZGShD46TGOcXrfsLIX1Jd45j2-true]`.
   - Trace the exact cause of assertion failure `_elements.contains(element) is not true` and column duplication bug when toggling gender filters ('All', 'Male', 'Female'), where sticky/header columns duplicate or repeat '# LEARNERS NAMES' horizontally across the table.
   - Examine how default score column slots (currently 10 per assessment category) are defined and rendered. Design the fix to reduce to 5 default slots with an inline '+' button on subsequent columns up to 10 slots (hiding when 10 slots reached) to eliminate UI lag.
2. R2: Manage Students and Manage Parents UI Polish:
   - Locate Manage Students and Manage Parents tables (`teacher_manage_students_tab.dart`, `teacher_manage_parents_tab.dart`, or equivalent files).
   - Standardize learner name text sizes in Manage Students and parent name text sizes in Manage Parents to an equal, legible, and consistent size.
   - In Manage Parents directory table:
     * Remove the checkbox column adjacent to '#'.
     * Replace 'SECTION' column with 'BIRTHDAY' column (inspect data model to see how parent/student birthday or child birthday is retrieved/displayed).
     * Remove 'All Subjects' option from the subject filter dropdown so teachers select only specific assigned subjects.
     * Identify and fix table header horizontal overflow rendering artifacts.

OUTPUT REQUIREMENTS:
- Write your complete findings, root cause explanations, exact file paths, line numbers, and proposed implementation steps into `c:\Users\Admin\AndroidStudioProjects\class_realm01\.agents\teamwork\explorer_survey_gradebook_dir\handoff.md`.
- Update your `progress.md` with timestamps.
- When finished, send a message back to the orchestrator summarizing your findings and linking to `handoff.md`. Do NOT modify source code.
