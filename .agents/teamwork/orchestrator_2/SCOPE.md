# Scope: CLASSREALM Chapters 1 & 2 Revision and Alignment

## Overview
Revise and align Chapters 1 and 2 for CLASSREALM, an integrated Senior High School educational management system (RFID attendance with manual fallback, assessments, automated grade computation, lesson plan guide generator, and learning materials organizer) for client Ma'am Karen P. Gonzaga at Eduardo Barreto Sr. High School. All output compiled directly into `INTEGRATED SENIOR HIGH SCHOOL ATTENDANCE.docx`.

## Milestones
| # | Name | Scope | Dependencies | Status |
|---|------|-------|-------------|--------|
| M0 | Survey & Analysis | Deep survey of adviser evaluation, previous drafts, target doc structure, and 10 empirical research studies | None | DONE |
| M1 | Authoring Chapters 1 & 2 | Comprehensive authoring of Chapter 1 & Chapter 2 satisfying all R1 & R2 requirements | M0 | DONE |
| M2 | Document Compilation | Formatting and compiling revised Chapters 1 & 2 directly into target Word doc (`INTEGRATED SENIOR HIGH SCHOOL ATTENDANCE.docx`) | M1 | DONE |
| M3 | Review, Challenge & Audit Gate | 2 Reviewers (APPROVE), 2 Challengers (APPROVE), and 1 Forensic Auditor (CLEAN) for strict verification | M2 | DONE |

## Key Requirements & Boundaries Verified
1. Pilot institution: Eduardo Barreto Sr. High School (single 't', Sr. High School).
2. Client: Ma'am Karen P. Gonzaga, Senior High School Mathematics Teacher.
3. Supported roles: Admin, Teacher (web and responsive app), Student (app), Parent (app).
4. System Admin limitation: Assigned to client teacher solely for academic year transitions and teacher provisioning. Admin cannot manage sections, subjects, schedules, attendance, activities, requirements, quizzes, examinations, grading percentages, lesson plans, learning materials, or student academic records.
5. Teachers self-manage sections, subjects, and students after receiving class rosters from registrar/school.
6. Excluded roles: Registrar and Principal.
7. Excluded workflows: Transfer student, transfer section, dropping student.
8. Preserved features: Student grade record preservation and downloading/exporting (PDF, CSV, Excel).
9. Attendance: RFID attendance + permanent manual teacher fallback. Offline sync, duplicate prevention (100% idempotent).
10. Measurable, dated SMART criteria for attendance, assessment, and submission workflows for SY 2026-2027.
11. Operational definitions: 9 system-tailored IT definitions for ESP32, RFID, Firebase Authentication, Supabase, Row-Level Security (RLS), Admin Portal, Teacher Portal, Student Portal, Parent Portal.
12. Chapter 2 Literature: Exactly 10 empirical studies (5 Philippine, 5 Foreign, 2021-2026) with valid DOIs/URLs, methods, samples, empirical findings across attendance, grading, lesson planning, and learning materials.
13. Synthesis matrix: 11 rows x 6 columns covering all 10 studies without unsupported blanket "lacks" claims.
14. DeLone & McLean (2003) Information Systems Success Model as theoretical foundation with embedded Figure 1.
15. 4-part IPSO Conceptual Framework (Input - Process - System - Output) diagram and narrative with embedded Figure 2.
16. Target Document: Directly populated `INTEGRATED SENIOR HIGH SCHOOL ATTENDANCE.docx` (1,093,259 bytes, 170 paragraphs, margins 1.6"/1.6"/1.2"/1.4", Arial 12/11).
