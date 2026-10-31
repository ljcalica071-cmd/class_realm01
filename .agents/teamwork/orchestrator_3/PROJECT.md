# Project: CLASSREALM Capstone 1 & Activities Consolidation

## Architecture
- Capstone 1 Documentation: Academic manuscript covering Chapters 1, 2, and 3 formatted in strict compliance with Laguna University / IT Capstone format standards.
- Activities Document: Consolidated document containing Activity #2 (Process Modeling: Context DFD, Level 1 DFDs, Process Specifications) and Activity #4 (Integrated UML & Data Modeling: ERD, Use Case Diagram, Class Diagram, Object Diagram).
- Diagrams Architecture: Vector/high-res raster diagrams strictly representing CLASSREALM tech stack:
  * Local DB: Drift + SQLite (mobile offline persistence)
  * Hardware: ESP32 microcontroller + RC522 RFID reader module
  * Cloud Backend: Supabase (PostgreSQL, Realtime, Storage, RLS) + Firebase Authentication
  * Entities: Admin, Teacher (web/mobile), Student (mobile), Parent (mobile), RC522 RFID Scanner, Firebase Auth, Supabase.

## Feature Inventory
| # | Feature | Description | Milestone | Source |
|---|---------|-------------|-----------|--------|
| 1 | IT Capstone 1 Document Revision | Single consolidated DOCX containing Chapters 1 to 3 based on master template | M2 | R1 |
| 2 | Chapter 1 Condensation | Condensed sections 1.1, 1.2, 1.4.1, 1.4.2 strictly spanning 9–11 pages total | M2 | R1 |
| 3 | Chapter 2 Condensation | Condensed 2.1.1, 2.1.2, 2.1.4, Table 1 matrix, 2.3 theoretical framework, 2.4 conceptual framework | M2 | R1 |
| 4 | Chapter 3 Methodology Clarification | Purposive sampling for teacher/parent in Agile Scrum framework | M2 | R1 |
| 5 | Natural Academic Tone | Removal of fancy/flowery vocabulary, concise direct academic English | M2 | R1 |
| 6 | Figure 1: IPSO Diagram | Clean, balanced Input-Process-Storage-Output diagram of CLASSREALM | M1 | R2 |
| 7 | Figure 2: IPO Diagram | Side-column aligned boxes mapped to system components | M1 | R2 |
| 8 | Figure 3: Agile Scrum Framework | Clear typography, no clipped boxes, proportional sprint phases | M1 | R2 |
| 9 | Figure 5: Context DFD (Level 0) | Central CLASSREALM, 4 users, RC522, Firebase Auth, Supabase, labeled directed flows | M1 | R2 |
| 10 | Tech Stack Truth | Verified Drift + SQLite, ESP32 + RC522 RFID, Supabase / Firebase Auth | M0, M1 | R2 |
| 11 | Consolidated Activities Document | Single DOCX containing Activity #2 and Activity #4 for CLASSREALM | M3 | R3 |
| 12 | Activity #2 Process Modeling | Context DFD, Level 1 DFDs, and detailed process specifications | M3 | R3 |
| 13 | Activity #4 UML & Data Modeling | ERD, Use Case Diagram, Class Diagram, and Object Diagram | M3 | R3 |
| 14 | Formatting Rule Compliance | Strict adherence to margins, typography, spacing, unsevered tables | M2, M3 | R1, R3 |

## Milestones
| # | Name | Scope | Dependencies | Status |
|---|------|-------|-------------|--------|
| M0 | Reference & Architecture Survey | 3 parallel Explorers: Master Docs/Formats, Activities/Diagrams, Codebase Stack | None | DONE |
| M1 | Accurate System Diagrams Generation | Generate all high-res diagrams (Figures 1, 2, 3, 5 + Activity 2 & 4 diagrams) | M0 | DONE |
| M2 | Chapters 1-3 Revision & DOCX Compilation | Revise, condense, and compile single DOCX for Chapters 1-3 (9-11 pages Ch 1) | M0, M1 | DONE |
| M3 | Consolidated Activities DOCX Compilation | Compile single DOCX for Activity #2 & Activity #4 | M0, M1 | DONE |
| M4 | Comprehensive Review & Audit Gate | 2 Reviewers, 2 Challengers, 1 Forensic Auditor across both deliverables | M2, M3 | DONE |

## Code & Artifact Layout
- Master Deliverable 1: `c:\Users\Admin\AndroidStudioProjects\class_realm01\CLASSREALM_Capstone1_Chapters_1_to_3.docx` (or updating target)
- Master Deliverable 2: `c:\Users\Admin\AndroidStudioProjects\class_realm01\CLASSREALM_Activities_2_and_4.docx`
- Generated Diagrams: `c:\Users\Admin\AndroidStudioProjects\class_realm01\docs\diagrams\`
