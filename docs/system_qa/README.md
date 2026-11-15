# ClassRealm • System Architecture & Defense Q&A Documentation Hub

Welcome to the official **ClassRealm System Q&A & Technical Architecture Hub**. This repository of technical walkthroughs, panelist defense questions, and stakeholder operational guides is designed for **Capstones, Thesis Defense, Practical Exams, and System Maintenance**.

All documentation in this folder is strictly grounded in the **ClassRealm** codebase, Supabase database schemas, and Flutter cross-platform architecture.

---

## Master Documentation Index

| Document | Scope & Focus Areas | Target Audience |
| :--- | :--- | :--- |
| **[01_STUDENT_ENROLLMENT_AND_IDENTITY_QA.md](file:///c:/Users/Admin/AndroidStudioProjects/class_realm01/docs/system_qa/01_STUDENT_ENROLLMENT_AND_IDENTITY_QA.md)** | • Bulk Spreadsheet Upload Pipeline (`.xlsx` / `.csv`)<br>• In-Memory Format & Syntax Engine<br>• 4 Status Categories: **Issues**, **New Students**, **Existing**, **Enrolled**<br>• LRN Name Mismatch & Account Hijacking Protection<br>• Section Capacity Limits & DepEd Senior High Identity | Panelists, Lead Developers, Teachers, System Administrators |
| **[02_CORE_SYSTEM_FLOWS_AND_FEATURES_QA.md](file:///c:/Users/Admin/AndroidStudioProjects/class_realm01/docs/system_qa/02_CORE_SYSTEM_FLOWS_AND_FEATURES_QA.md)** | • Cross-Platform Engine (Web Online-First vs Native Drift SQLite Offline-First)<br>• Hardware Integration (ESP32 + RFID Scanner Attendance & Cutoffs)<br>• DepEd Senior High School Grading Engine (WW, PT, QA)<br>• Realtime Assessment Proctoring & Tab-Switch Anti-Cheating<br>• RBAC, RLS Security, and Horizontal/Vertical Route Isolation | Thesis Panel, Technical Evaluators, Defense Team |

---

## Visual Architecture Diagrams

- **Bulk Enrollment Pipeline & Name Mismatch Flowchart (High-Res PNG):**  
  [student_enrollment_logic_flowchart.png](file:///c:/Users/Admin/AndroidStudioProjects/class_realm01/student_enrollment_logic_flowchart.png)

---

## Defense Quick Reference Summary

```
ClassRealm Architecture Stack:
├── Presentation Layer: Flutter 3.x (Web, Windows Desktop, Android)
├── State & Coordination: AsyncNotifier / Riverpod / ChangeNotifier Architecture
├── Data Persistence:
│   ├── Cloud: Supabase (PostgreSQL 15+, Auth, Realtime WebSockets, Storage)
│   ├── Local Offline: Drift SQLite (AppDatabase, OfflineSyncQueue, LocalAttendanceCutoffs)
│   └── Local Cache: SharedPreferences / LocalStorageService
├── Hardware Layer: ESP32 Microcontroller + RC522 RFID Module / NFC
└── Domain Engines: DepEd SHS Grading Engine, In-Memory Excel Parser, Gemini ILAW AI Planner
```
