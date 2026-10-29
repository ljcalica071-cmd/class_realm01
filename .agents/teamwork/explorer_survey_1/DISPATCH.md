## 2026-10-29T08:58:08Z
You are teamwork_explorer assigned to Survey Phase (Backend & Database Architecture).
Your Working Directory is: c:\Users\Admin\AndroidStudioProjects\class_realm01\.agents\teamwork\explorer_survey_1
Original Request path: c:\Users\Admin\AndroidStudioProjects\class_realm01\.agents\teamwork\ORIGINAL_REQUEST.md

MANDATORY INSTRUCTIONS:
1. You MUST read c:\Users\Admin\AndroidStudioProjects\class_realm01\.agents\teamwork\ORIGINAL_REQUEST.md first before anything else.
2. Objective: Investigate the codebase for:
   - Existing Supabase database schemas, tables, migrations, RLS policies, especially regarding attendance, students, classes/sections, schedules, teachers, and parents.
   - Current data models in Flutter/Dart (e.g. AttendanceRecord, Student, Schedule, ClassSession, User/Profile).
   - How schedules are defined, plotted, and queried.
   - Any existing cron jobs, edge functions, or scheduled tasks.
   - Required additions or schema evolutions needed for R2 (RFID assignment, unique constraints, recording method attribute 'RFID' vs 'Manual'), R3 (schedule-bound auto-status, cutoffs, 23:59 auto-absent trigger), and R6 (RLS scoping for Student & Parent apps).
3. Scope boundaries: You are READ-ONLY. Do NOT modify any files in the codebase. Write only your analysis, progress, and handoff files within your working directory: c:\Users\Admin\AndroidStudioProjects\class_realm01\.agents\teamwork\explorer_survey_1\
4. Output requirements:
   - Maintain progress.md as your heartbeat.
   - Write your comprehensive survey report to `handoff.md` in your working directory.
   - The report must include: Table schemas (current vs required additions), SQL/RLS policies, Model definitions, schedule-checking logic, cutoff validation rules, and the 23:59 cron/Edge Function logic.
5. Completion criteria: Complete handoff.md with verified file citations and send a completion message with the path to handoff.md to your parent via send_message.


## 2026-10-29T09:06:37Z
**Context**: Survey Phase Status Check
**Content**: Heartbeat check on your backend/schema survey investigation. How is your survey progressing regarding Supabase tables, migrations, RLS policies, schedule models, and edge function cron?
**Action**: Please reply with your current status or estimated time to deliver handoff.md.

