# ClassRealm — Database Architecture & Optimization Rules

> **Document Type:** System Architecture & Best Practices
> **Project:** ClassRealm (Hybrid: Supabase PostgreSQL + Firebase)
> **Target Audience:** Backend Developers & Database Administrators

---

## 1. Hybrid Storage Strategy
1. **Relational Data goes to Supabase:** Use PostgreSQL for structured data with relationships (Users, Enrollments, Grades, Schedules, Attendance).
2. **Authentication goes to Firebase Auth:** Handle all login, session tokens, and password hashing via Firebase. Use Firebase UID as the primary key reference in Supabase.
3. **Binary Files go to Firebase Storage:** Profile pictures, PDF modules, and image submissions must be stored in Firebase Storage. Only save the download URL in Supabase.
4. **Offline Queue via Local Storage:** Use Hive/SQLite for offline caching. Hardware (RFID) or mobile apps must write locally first, then sync to Supabase when online.

## 2. Table Design & Normalization (3NF)
5. **Enforce 3NF (Third Normal Form):** Eliminate duplicate data. Do not store student names in the `grades` table; only store the `student_id` and `subject_id`.
6. **Use UUIDs as Primary Keys:** All tables should use UUID `gen_random_uuid()` instead of auto-incrementing integers to prevent ID-guessing attacks and make offline syncing easier.
7. **Soft Deletes Only:** Never use `DELETE`. Add an `is_archived` (boolean) column to tables like `sections` and `subjects`. This preserves historical grading data.
8. **Audit Trails:** Every major table must have `created_at` and `updated_at` timestamps. Update `updated_at` automatically via PostgreSQL triggers.

## 3. Data Integrity & Constraints
9. **Foreign Key Cascades:** Be careful with `ON DELETE CASCADE`. Only use it for dependent child data (e.g., deleting a quiz deletes its quiz_items). For critical records (students/teachers), use `ON DELETE RESTRICT`.
10. **Unique Constraints:** Prevent duplicates. The `lrn` column in the students table must be `UNIQUE`. The combination of `teacher_id`, `subject_id`, and `section_id` in schedules must be `UNIQUE`.
11. **Check Constraints:** Use constraints to prevent bad data (e.g., `CHECK (grade >= 0 AND grade <= 100)` or `CHECK (hps > 0)` for Highest Possible Score).

## 4. Query Optimization & Indexing
12. **Index Frequent Lookups:** Add B-Tree indexes on columns used in `WHERE` and `JOIN` clauses (e.g., `student_id`, `section_id`, `teacher_id`).
13. **Avoid SELECT *:** Always specify the exact columns needed (`SELECT id, name FROM users`) to reduce bandwidth and memory usage, especially for mobile clients.
14. **Pagination for Large Lists:** Use `LIMIT` and `OFFSET` for lists like attendance logs or system notifications to avoid crashing the app with massive payloads.

## 5. Security & Access Control
15. **Enable Row Level Security (RLS):** Supabase RLS must be enabled on ALL tables. A student should only be able to `SELECT` their own grades. A teacher can only `SELECT` students in their assigned sections.
16. **No Client-Side Trust:** Never trust computations sent from the frontend. If the frontend says the grade is 95, the backend must recalculate the WW, PT, and EX scores to verify.
17. **Role-Based Access Control (RBAC):** Create a `roles` enum (`admin`, `teacher`, `student`, `parent`) and use it in RLS policies to restrict `INSERT` and `UPDATE` commands.

## 6. Offline & Hardware Syncing
18. **Idempotency for Sync:** When the RFID ESP32 hardware uploads offline attendance logs, ensure the endpoint is idempotent. If it sends the same log twice, the database should gracefully ignore the duplicate using `ON CONFLICT DO NOTHING`.
19. **Batch Processing:** When syncing offline data, use batch inserts instead of looping single inserts to reduce database round-trips.

## 7. Performance Monitoring
20. **Monitor Table Bloat:** Regularly run `VACUUM` on highly updated tables (like real-time attendance or live assessment monitoring) to reclaim space and maintain query speed.
