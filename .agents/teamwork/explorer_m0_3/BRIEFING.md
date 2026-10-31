# BRIEFING — 2026-10-30T11:40:00Z

## Mission
Investigate and verify the CLASSREALM codebase architecture, tech stack truth, database schemas, hardware attendance integration, backend services, and portal workflows.

## 🔒 My Identity
- Archetype: explorer
- Roles: investigation, synthesis
- Working directory: c:\Users\Admin\AndroidStudioProjects\class_realm01\.agents\teamwork\explorer_m0_3
- Original parent: be6c7746-a315-4fe1-98b4-411ff3dd0be1
- Milestone: M0-3 Codebase Architecture & Tech Stack Truth Verification

## 🔒 Key Constraints
- Read-only investigation — do NOT implement
- Verify Drift/SQLite local persistence, ESP32/RC522 hardware attendance, Supabase/Firebase backend, supported portals/workflows, and establish architectural baseline for diagrams/documentation.

## Current Parent
- Conversation ID: be6c7746-a315-4fe1-98b4-411ff3dd0be1
- Updated: 2026-10-30T11:40:00Z

## Investigation State
- **Explored paths**:
  - `pubspec.yaml`
  - `lib/data/datasources/local/tables.dart`, `app_database.dart`
  - `lib/core/services/sync_coordinator.dart`, `supabase_service.dart`, `firebase_auth_admin_service.dart`, `gemini_service.dart`, `session_activity_tracker.dart`
  - `lib/core/utils/deped_grading_engine.dart`
  - `lib/data/repositories/` (`auth_repository.dart`, `supabase_attendance_repository.dart`, `supabase_student_repository.dart`, `supabase_parent_repository.dart`, `supabase_teacher_classwork_repository.dart`, `supabase_learning_material_repository.dart`, `student_dashboard_repository.dart`, `subject_repository.dart`)
  - `docs/ESP32_RFID_BUILD_GUIDE.md`, `docs/ATTENDANCE_REDESIGN_IMPLEMENTATION_PLAN.md`, `docs/ATTENDANCE_VALIDATION_MATRIX.md`
  - `supabase/migrations/001_initial_schema.sql`, `002_supabas.sql`
  - `lib/features/` (admin, teacher, student, parent, auth)
  - `lib/routes/app_routes.dart`, `lib/main.dart`, `PROJECT.md`
- **Key findings**:
  - Drift + SQLite persistence on native/mobile: 14 schema tables, durable `OfflineSyncQueue`, 45-second periodic synchronization in `SyncCoordinator`.
  - ESP32 hardware attendance: ESP32 DevKit V1 + RC522 SPI (3.3V) / PN532 I2C, FreeRTOS dual-core task segregation (Core 1 20Hz polling, Core 0 LittleFS append-only JSONL ring buffer + HTTPS batch POST to Supabase RPC `record_rfid_attendance_batch`).
  - Cloud backend: Supabase PostgreSQL (42+ relational tables, RLS isolation policies per role, 9 Realtime WebSocket channels, storage buckets `classwork-materials` and `learning_materials`).
  - Firebase Authentication: Identity platform with email/password authentication, REST admin provisioning via service account OAuth2, progressive rate limiting, and session tracking in `user_session_logs`.
  - Portal role division verified in code: Admin is strictly restricted to provisioning and year transitions (cannot touch sections, subjects, rosters, attendance, grades); Teachers manage their classroom, attendance, ECR, DepEd DO 15 grading, and Gemini ILAW lesson plans; Students and Parents have strictly scoped view-only mobile dashboards.
- **Unexplored areas**: None. Entire codebase architecture and tech stack truth verified.

## Key Decisions Made
- All architecture diagrams (DFD Level 0, DFD Level 1s, ERD, Class Diagram, Object Diagram, IPSO, IPO) must reflect the exact verified hybrid stack: Firebase Auth + Supabase + Drift/SQLite + ESP32/RC522.

## Artifact Index
- DISPATCH.md — incoming instructions and status pings
- BRIEFING.md — working memory and identity
- progress.md — liveness and step progress
- handoff.md — final comprehensive 5-component report
