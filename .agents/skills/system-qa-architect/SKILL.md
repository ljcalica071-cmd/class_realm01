---
name: system-qa-architect
description: Use when the user asks for detailed Question and Answer (Q&A) documentation, thesis/capstone defense preparation, technical walkthroughs, or stakeholder workflow guides about the ClassRealm system or any of its modules.
---

# System Q&A Architect (ClassRealm)

## Overview

Generate deep, codebase-verified, multi-perspective Question and Answer (Q&A) documentation for **ClassRealm** (Integrated SHS Management System). Every answer must be grounded in actual workspace files, database migrations, and runtime architecture—never guessed from memory.

## Core Principles

1. **Codebase-First Verification (Zero Guessing):**
   - Before drafting any Q&A, inspect the relevant code and schema.
   - If `graphify-out/graph.json` exists, run `graphify query "<topic>"` first to locate key files, then read the specific Dart files, repositories, services, and `supabase/migrations/*.sql` files.
   - Only cite file paths, class/function names, Supabase tables, Drift local tables, and RPCs/policies that were directly observed in the current workspace.
   - Match the user's preferred language (English, Filipino, or Taglish), keeping exact code symbols, table names, and file paths in backticks.

2. **Depth Requirement (Ano / Paano / Bakit):**
   - **Ano (What):** Identify the exact feature, UI screen/widget, service, repository, and database table(s) involved.
   - **Paano (How):** Trace the step-by-step data flow, business logic, state transitions, and sync/API calls from UI action to persistence and back.
   - **Bakit (Why):** Explain the architectural rationale—design decisions, security boundaries (e.g., RLS, `AuthGuard`, `AppRoutes.isRouteAllowedForRole`), offline-first resilience, or performance/efficiency trade-offs.

---

## Mandatory Multi-Perspective Structure

Every Q&A set MUST be organized into two complementary sections:

### Section 1: Technical / Panelist Questions
Focus on engineering depth, defense-ready scrutiny, and system internals:
- **System Architecture & Platform Strategy:** Cross-platform behavior (Flutter Web online-first vs. Native Drift SQLite offline-first via `SyncCoordinator.isLocalDbSupported`), Firebase Auth + Supabase PostgreSQL integration, startup sequence (`main.dart`).
- **Database & Security:** Supabase schema, Row Level Security (RLS) policies, `AuthGuard` & `AppRoutes` horizontal/vertical role isolation, maintenance mode enforcement, rate limiting, and privacy controls.
- **Local Storage & Offline Syncing:** Drift SQLite (`AppDatabase`, `tables.dart`), `OfflineSyncQueue` retry/status lifecycle (`pending` -> `syncing` -> `failed`/`synced`), `LocalStorageService`, and conflict resolution.
- **Hardware-Software & Realtime Integration:** ESP32 + RFID/NFC attendance pipeline (`rfid_pending_scans`, `nfc_manager`, `LocalAttendanceCutoffs`), Supabase Realtime channels (live exam proctoring via `teacher_proctor_channel_service.dart`, anti-cheating).
- **AI & Domain Engines:** DepEd grading computation (`deped_grading_engine.dart`), ILAW AI lesson plan generation (`google_generative_ai`, `ilaw_lesson_plan_validator.dart`), and system limitations/trade-offs.

### Section 2: User / Stakeholder Questions
Focus on real-world operations, role workflows, and troubleshooting:
- **Role-Based Portal Workflows:**
  - **Admin:** Teacher account provisioning, system settings/maintenance mode, broadcasts, activity analytics.
  - **Teacher:** Academic setup wizard, classroom setup, RFID assignment, attendance & cutoffs, classwork/assessments, live proctoring, DepEd gradebook, ILAW lesson planning, learning materials, parent management.
  - **Student:** First-login onboarding, schedule, attendance status, taking assessments/quizzes, submitting classwork attachments, viewing grades/performance & privacy controls.
  - **Parent:** Linked child monitoring, attendance & absence warning notifications, grades, schedule, alerts.
- **Common Errors & Operational Resolution:** How users recover from common issues (e.g., invalid/expired OTP, first-login lock, failed file upload MIME/size limits, RFID scan not linked, offline sync backlog, maintenance mode lockout).

---

## Mandatory Per-Question Answer Format

Every single Q&A item MUST strictly follow this 3-part template:

```markdown
### Q<N>: <Question>

- **Direct Summary:** <One clear, standalone sentence directly answering the question.>
- **Technical Walkthrough:** <Step-by-step explanation of how it works internally—explaining the What, How, and Why, and explicitly naming exact modules, classes/functions, Drift/Supabase tables, or migrations.>
- **Edge Cases / Fallback:** <How the system handles failures: network loss/offline mode, invalid input/validation, concurrency/duplicate scans, RLS/permission denial, or service timeouts.>
```

---

## Execution Checklist (Before Responding)

1. Identify the target module, feature, or cross-cutting concern requested by the user.
2. Query `graphify-out/` (if available) and read the exact source files and SQL migrations for that scope.
3. Verify all symbol names, table/column names, and error-handling paths against the files read.
4. Draft balanced Q&As covering both **Technical / Panelist** and **User / Stakeholder** perspectives.
5. Verify every answer contains **Direct Summary**, **Technical Walkthrough**, and **Edge Cases / Fallback**, and explains the **Ano**, **Paano**, and **Bakit**.

