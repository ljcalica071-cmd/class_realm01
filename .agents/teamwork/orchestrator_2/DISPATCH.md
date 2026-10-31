# Dispatch Log

## 2026-10-29T23:00:33Z
Revise and align Chapters 1 and 2 for CLASSREALM, an integrated Senior High School educational management system (RFID attendance with manual fallback, assessments, automated grade computation, lesson plan guide generator, and learning materials organizer) for client Ma'am Karen P. Gonzaga at Eduardo Barreto Sr. High School.

Working directory: c:\Users\Admin\AndroidStudioProjects\class_realm01
Integrity mode: development

## Reference Material
- Target Word Document: `c:\Users\Admin\AndroidStudioProjects\class_realm01\INTEGRATED SENIOR HIGH SCHOOL ATTENDANCE.docx`
- Adviser Evaluation Notes & Rubrics: `c:\Users\Admin\AndroidStudioProjects\class_realm01\SAD_FR_Thesis_Finals-Activity1_Chapter3.pdf`
- Previous Chapters 1 & 2 Draft: `c:\Users\Admin\AndroidStudioProjects\class_realm01\Group#20_Calica_Sanjuan_chapter1and2.docx (2) (1).pdf`
- Previous Activities Draft: `c:\Users\Admin\AndroidStudioProjects\class_realm01\Group#20_Calica_Sanjuan_Activities.docx (1).pdf`
- System Overview Presentation: `c:\Users\Admin\Downloads\CLASSREALM_Presentation_Overview.pptx`
- Reference Samples (Structure only): `c:\Users\Admin\Downloads\Activity#1_Chapter1.docx`, `c:\Users\Admin\Downloads\Acitivity#3_Chapter2.docx`

## Requirements

### R1. Chapter 1 Revision, Scope Formalization, and Technical Definitions
Revise Chapter 1 (Introduction, Problem Statement, General and Specific Objectives, Scope and Limitations, Definition of Terms) according to the adviser's evaluation and project specifications:
- Writing tone: Formal capstone prose that is concise, direct to the point, and easy to understand, avoiding flowery or unnecessarily verbose phrasing.
- Explicitly name the pilot institution as Eduardo Barreto Sr. High School and the client as Ma’am Karen P. Gonzaga, Senior High School Mathematics Teacher.
- Detail the supported roles: Admin, Teacher (web and responsive app), Student (app), and Parent (app).
- Formally establish system boundaries and limitations in the narrative:
  - System Admin account is assigned to the client teacher solely for academic year transitions and teacher provisioning. Admin has no access to manage sections, subjects, schedules, attendance, activities, requirements, quizzes, examinations, grading percentages, lesson plans, learning materials, or student academic records.
  - Teachers self-manage sections, subjects, and students after receiving class rosters from the registrar/school.
  - The system excludes registrar and principal roles.
  - Transfer student, transfer section, and dropping student workflows are excluded from system management.
  - System must preserve academic records and allow downloading/exporting student grade records.
- Establish measurable, dated SMART evaluation targets for attendance tracking, submission handling, and assessment evaluation.
- Preserve manual attendance recording as a permanent operational fallback alongside RFID scanning.
- Define parent authorization, offline synchronization / duplicate attendance policies, and test thresholds.
- Definition of Terms: Construct operational, IT-oriented technical definitions directly tailored to ClassRealm's architecture rather than generic dictionary definitions. Specifically include and define: ESP32, RFID, Firebase Authentication, Supabase, Row-Level Security (RLS), Admin Portal, Teacher Portal, Student Portal, and Parent Portal (without copying any prompt example verbatim).

### R2. Chapter 2 Review of Related Literature (RRL) and Theoretical/Conceptual Framework
Revise Chapter 2 to fulfill all adviser recommendations:
- Identify and develop literature themes, concepts, and variables directly aligned with the research title and statement of the problem across attendance tracking, assessment and grading, lesson planning, and learning materials management.
- Sourced literature requirement: Include exactly 10 empirical studies published between 2021 and 2026 (5 Philippine local studies in English, 5 foreign/international studies in English) with valid, authentic sources, working URLs or DOIs, explicit methodologies, participant/sample groups, and actual empirical findings.
- Expand the synthesis matrix to encompass all 10 domain sources; eliminate unsupported blanket statements claiming prior works simply "lack" features.
- Provide direct literature and empirical evidence supporting the teacher lesson-planning and learning-materials workflow components.
- Present an explicit 4-part IPSO (Input - Process - System - Output) diagram and narrative for the Conceptual Framework.
- Incorporate DeLone & McLean (2003) Information Systems Success Model as foundational supporting theory, including its complete citation and publication year (2003).

### R3. Word Document Compilation and Formatting
Directly populate, update, and format the revised Chapters 1 and 2 within the provided Word template: `c:\Users\Admin\AndroidStudioProjects\class_realm01\INTEGRATED SENIOR HIGH SCHOOL ATTENDANCE.docx`.
- Maintain a direct, formal capstone writing style free of filler content.
- Replace outdated or contradictory sections with the corrected text, maintaining uniform typography, heading hierarchy, margins, and caption standards conforming to `SAD_FR_Thesis_Finals-Activity1_Chapter3.pdf`.
- Ensure consistency between Chapter 1 objectives, scope limitations, and Chapter 2 conceptual framework variables.

## Acceptance Criteria

### Chapter 1 Compliance & Definitions
- [ ] Eduardo Barreto Sr. High School is explicitly identified as the pilot school, and Ma'am Karen P. Gonzaga is explicitly identified as the client.
- [ ] Scope and Limitations section explicitly limits Admin to academic year transitions and teacher provisioning, while designating student roster entry to teachers.
- [ ] Exclusions of registrar and principal user accounts and transfer/drop workflows are documented, and student grade record preservation and downloading capabilities are specified.
- [ ] Attendance specifications include both RFID and manual teacher fallback.
- [ ] Quantifiable, dated SMART criteria are documented for attendance, assessment, and submission workflows.
- [ ] Parent authorization policies, offline synchronization, duplicate attendance detection, and test thresholds are defined.
- [ ] Definition of Terms contains operational, system-specific IT definitions for ESP32, RFID, Firebase Authentication, Supabase, Row-Level Security (RLS), Admin Portal, Teacher Portal, Student Portal, and Parent Portal.
- [ ] Phrasing across Chapter 1 is concise, formal, and free of overly flowery filler text.

### Chapter 2 & Literature Synthesis
- [ ] Literature review includes exactly 10 empirical studies (5 Philippine local, 5 international) published between 2021 and 2026 with verifiable citations and DOIs/URLs.
- [ ] Literature review matrix contains all 10 studies with distinct columns for author/year, methodology, sample size/profile, and specific empirical findings, without unsupported blanket "lacks" statements.
- [ ] Specific literature evidence directly addresses teacher lesson planning and learning materials management workflows.
- [ ] DeLone & McLean (2003) is cited with complete year and established as foundational theory.
- [ ] Conceptual framework diagram and narrative explicitly follow the 4-part IPSO stages.

### Document Quality & Verification
- [ ] The deliverable is compiled directly into `c:\Users\Admin\AndroidStudioProjects\class_realm01\INTEGRATED SENIOR HIGH SCHOOL ATTENDANCE.docx`.
- [ ] All itemized deficiencies cited in the adviser evaluation record (Mpbomilc review) for Chapter 1 and Chapter 2 are resolved and verified against `SAD_FR_Thesis_Finals-Activity1_Chapter3.pdf`.
