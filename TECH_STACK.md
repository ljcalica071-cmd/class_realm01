# ClassRealm Tech Stack Documentation

This document serves as the official reference for the technologies and architecture used in the ClassRealm System.

---

## 1. Frontend & Backend Framework
* **Flutter + Dart (100% Unified Stack)**
  * **Platforms:** Web (for Admin, Teacher, and Student portals) and Mobile App (for Student and Parent).
  * **Architecture:** 100% Pure Dart application layer. Zero reliance on external TypeScript (`.ts`) Edge Functions. All business logic, validations, CRUD operations, caching, and background sync are managed natively in Dart.
  * **Purpose:** Single codebase for a seamless, blazing-fast, and responsive user experience across all devices.

---

## 2. Authentication
* **Firebase Authentication**
  * **Purpose:** Secure user authentication, password management, and session handling across Web and Mobile.
  * **Role:** Issues secure user tokens and identity validation. Integrated seamlessly with Supabase database permissions and user profiles.

---

## 3. Main Database (Cloud)
* **Supabase (PostgreSQL)**
  * **Purpose:** The central cloud PostgreSQL database serving as the ultimate source of truth when online.
  * **Direct Dart Integration:** Flutter communicates directly via `supabase_flutter` PostgREST client and Supabase Storage for materials.
  * **Usage:** Stores master records including user profiles, student information, class schedules, enrolled subjects, assignments, and finalized attendance records.

---

## 4. Local-First Engine & 0ms Caching Architecture (Fully Implemented)
* **Drift + SQLite (Active Local-First Database)**
  * **Implementation:** `lib/data/datasources/local/app_database.dart` using `drift` and `drift_flutter`.
  * **Storage Platforms:**
    * **Web:** High-performance WebAssembly (Wasm) backed by browser IndexedDB.
    * **Mobile & Desktop:** Native high-speed SQLite database engine.
  * **0ms Instant Load:** On app launch and tab switching, all views (Classroom Setup, Gradebook, Student Directory, Parent Directory, Attendance, and Dashboard) read immediately from Drift SQLite (0 milliseconds render time). Zero blank loading screens or blocking spinners.
  * **SyncCoordinator (Active):** A background sync coordinator (`lib/core/services/sync_coordinator.dart`) runs every 45 seconds, silently fetching incremental cloud updates and flushing the local offline mutation queue (`offline_sync_queue`) without interrupting the user.
* **SharedPreferences (Lightweight UI Preferences)**
  * **Usage:** Storing simple key-value UI state such as Remember-Me preference, active theme (Dark/Light mode), and local filter selections.

---

## 5. Pure Dart Email & Notification Engine
* **Cloud Email Delivery (Pure Dart HTTPS API)**
  * **Implementation:** `lib/core/services/email_service.dart`.
  * **Delivery Mechanism:** Direct HTTPS REST API request (compatible across Web, Android, iOS, Windows, macOS). Zero serverless cold-boot delay and zero raw TCP socket restrictions on web browsers.
  * **Features:**
    1. **6-Digit OTP Verification:** Secure client-generated OTP with expiration timer for first-time logins and password resets.
    2. **Student & Parent Welcome Credentials:** Automated delivery of LRN, temporary password, and portal login instructions.
    3. **Teacher Verification & Administrative Alerts:** Fast, durable notifications with styled ClassRealm HTML templates.

---

## 6. Hardware & IoT Integration
* **USB Keyboard-Wedge RFID Reader & ESP32 Microcontroller + RC522 Scanner Module**
* **13.56MHz RFID Cards / Tags (for students)**
  * **Purpose:** Plug-and-play classroom hardware for instant student attendance tapping, paired with a manual teacher roster fallback.
  * **Pure Dart + PostgreSQL RPC (Zero `.ts` Edge Functions):** USB Keyboard-Wedge readers stream UID keystrokes directly into the Flutter desktop/web workspace, while ESP32 + RC522 units call PostgreSQL RPCs (`record_rfid_attendance`, `record_rfid_attendance_batch`), persisting offline scans to Drift SQLite (`offline_sync_queue`) when internet is unavailable and running end-of-day auto-absent reconciliation natively via PostgreSQL `pg_cron` (`fn_trigger_daily_auto_absent`).

---

## 7. Performance & Offline Guidelines
* **Cache-First Always:** Render locally cached SQLite data immediately; refresh in the background silently.
* **Layout Shell Preservation:** Navigation bars, headers, action buttons, and table frameworks must never collapse or white-out during network requests. Background operations show a subtle 3px top linear progress indicator instead of full-page spinners.
* **Offline Resilience:** Every mutation (creating attendance, updating students, editing grades) writes to the local SQLite transaction first, ensuring zero data loss during network dropouts.
