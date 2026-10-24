# ClassRealm: Unbroken End-to-End System Flow & Requirements Checklist

This document details the master architectural workflow of ClassRealm. It is structured to ensure that data flows seamlessly and logically from the System Administrator all the way down to the Parent without any broken links or isolated features.

---

## 🏛️ Act 1: The System Administrator (Foundation & Control)
**The Objective:** Establish a controlled environment, monitor live system usage, and manage authorized faculty access.

### Requirements Checklist:
- [x] **Dashboard Overview:** High-level summary of active users and system health.
- [x] **Teacher Management (Account Creation):** Secure generation of Teacher accounts using auto-generated passwords sent via SMTP.
- [x] **Teacher Management (Account Recovery):** Secure capability to update emails (Typo Fixes) and perform Full Account Resets (bypassing lost email locks while keeping user IDs intact).
- [x] **Activity Analytics (Real-Time):** Live tracking of Online Teachers, interactive duration graphs, ghost-session cleanup, and real-time offline/online donut charts.
- [x] **Broadcasts & Maintenance Control:** Real-time push announcements targeting specific roles (filtering out mock accounts) and a secure lockdown mechanism requiring exactly 15-character type-to-confirm validation.

---

## 👨‍🏫 Act 2: The Teacher (The Academic Engine)
**The Objective:** Setup the academic environment, plan lessons, encode raw scores, and track attendance. The data inputted here acts as the source of truth for the entire system.

### Requirements Checklist:
- [x] **First Login / Onboarding:** Mandatory security gateway to set a personalized password upon first entry.
- [x] **Classroom Setup (The Foundation):** Automated DepEd SSHS Subject Selection mapping (Core, Applied, Specialized) matching exact grading weights (WW, PT, EX) and term block logic to prevent computation errors.
- [x] **Student Management (Enrollment):** Unified system for accepting students into created sections via Invite Codes/Links.
- [x] **My Schedule (Time Plotting):** Plotting of subjects into specific time slots, enabling the Attendance feature to trigger at the right time.
- [x] **Lesson Planning (AI Integration):** Gemini AI generation of highly structured **iLAW Format** lesson plans (Intended Learning Outcomes, Learning Content, Assessment, Work Experiences).
- [x] **Attendance Tracking (Manual):** Teacher interface to manually mark students as Present, Absent, or Late.
- [ ] **Attendance Tracking (RFID Integration):** Automated attendance logging mapped to student profiles.
- [ ] **Teacher Classwork Workspace (CRITICAL BOTTLENECK):** Central hub for assigning tasks, split into four progressive phases:
  - **Phase 1: Performance Tasks (PT):** Support for both *In-Person/Manual Recording* (for physical outputs) and *Online Submissions* (file/text uploads).
  - **Phase 2: Written Works (WW - Activity / Assignment):** General assignments directly tied to WW weight component.
  - **Phase 3: Quizzes (Short Quizzes):** Digital quiz creation and auto-recording in the system.
  - **Phase 4: Major Examinations (EX):** Comprehensive test recording (ST1, ST2, Term Exams) including advanced feature for **Item Analysis** to pinpoint learning gaps based on student answers.
- [ ] **Gradebook Computation:** Automated computation from Raw Scores (from Classwork) -> Percentage -> Weighted -> Initial Grade -> Transmuted Final Grade (DO 15, s. 2026). *UI is built but waiting for Classwork raw data.*

---

## 🎓 Act 3: The Student (The Learner)
**The Objective:** Consume the academic data provided by the teacher to track standing, pending tasks, and attendance.

### Requirements Checklist:
- [ ] **Student Dashboard:** Real-time visibility of their daily schedule and school/teacher broadcasts.
- [ ] **Task & Activity Tracker:** A kanban or list view showing Pending, Submitted, and Overdue activities to help the student know exactly what they are missing (*"Mga Kulang Ko"*).
- [ ] **Grade Viewer:** A transparent, read-only view of their computed grades per subject and term.
- [ ] **Attendance Record:** Personal tracker of their accumulated absences and lates.

---

## 👨‍👩‍👦 Act 4: The Parent (The Guardian)
**The Objective:** Provide guardians with immediate, transparent access to their child’s academic health and physical safety without waiting for term-end meetings.

### Requirements Checklist:
- [ ] **Parent-Student Linking:** Secure registration and linking to a student's profile via code.
- [ ] **Safety Monitor (Real-Time Attendance):** Push notifications or timeline view of when the student tapped their RFID / entered the classroom.
- [ ] **Academic Health Check:** High-level summary of the student's failing grades or pending/missing Performance Tasks to allow early parental intervention.

---

## 🚨 Current System Status & Priority Bottleneck

The system flows perfectly from **Admin -> Teacher Setup**. However, the chain breaks at the exact moment the Teacher needs to input scores because the **Classwork Feature** is missing. 

Without the Classwork Feature, there are no raw scores. Without raw scores, the Gradebook cannot compute. Without computed grades and tasks, the Student and Parent portals have no data to consume.

**Next Immediate Development Focus:** Building the `TeacherClassworkTab` and integrating it with the `TeacherClassworkRepository`.
