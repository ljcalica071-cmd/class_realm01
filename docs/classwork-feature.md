# Classwork Feature — End-to-End Plan

## Purpose

This document defines the intended end-to-end behavior of Teacher Classwork and
its connections to Student, Parent, and Gradebook workflows. Delivery is strictly
sequenced into four sequential phases:

1. **Phase 1: Performance Tasks (PT)**
2. **Phase 2: Written Works: Activity / Assignment (WW)**
3. **Phase 3: Quizzes (Short Quizzes)**
4. **Phase 4: Major Examinations (EX: ST1, ST2, Term Exam / TE)**

This is a product and implementation plan, not an implementation record. No
code, database, or Supabase project is changed by this document.

## Core decision: two ways to complete classwork

Every classwork item has a **completion mode**. The mode describes where the
student performs and submits the work; it does not change which class, students,
grading category, or Gradebook column the work belongs to.

### Online in ClassRealm

The teacher assigns the work through ClassRealm and the student completes it
using the app.

- For activities, assignments, and performance tasks, the student opens the
  published item and submits the allowed response in the app, such as text,
  file, or both, according to the teacher's settings.
- For a digital quiz or exam, the student answers the assessment in the app.
- The system records the student's submission or attempt, timestamp, status,
  and, where applicable, answers and score.
- The teacher reviews, grades, returns, or releases the result through the app.

### In person / manual record

The teacher assigns the work through ClassRealm so the student can see what the
task is, but the student performs and hands it in **outside the system**—for
example, on paper, as a classroom presentation, demonstration, project, or
physical output.

- The student does not upload or submit the physical work through ClassRealm.
- The teacher uses ClassRealm to record the student's completion or
  participation, score, feedback, and grading state.
- The student can then see the published task and the released score/feedback
  in the app. The app record is a gradebook and communication record, not proof
  that the work itself was submitted digitally.
- A missing manual score must not silently mean zero. The teacher records an
  explicit state such as not yet graded, completed, absent, excused, or not
  submitted, then enters a score when grading is appropriate.

The UI must use clear language such as **“Submit in ClassRealm”** and
**“Complete in person; teacher records the result”**. Do not label the second
mode as an online submission or show the student an upload button for it.

## Non-negotiable data ownership and isolation

### A class is identified by its offering, not its display name

All Classwork must point to one unique `subject_offering_id`. That offering is
the authoritative connection between teacher, subject, section, school year,
and term. Subject names and section names are display labels only; they are
never sufficient identifiers.

This prevents two teachers who teach a subject with the same name, or sections
with the same label, from seeing or changing each other's activities, student
lists, submissions, or scores.

### Authorization is enforced by the database/backend

Every list, create, edit, publish, archive, grade, and delete operation must
verify on the trusted backend that:

- the authenticated user is an active teacher;
- the teacher owns the selected, active subject offering;
- the classwork item belongs to that offering;
- every targeted student is enrolled in that offering;
- the requesting student is the student whose submission/attempt is being
  accessed; and
- any parent access is limited to students linked to that parent.

Hiding another teacher's offering in a dropdown is useful UX, but is not
authorization. Flutter must not be trusted to enforce ownership by itself.

### Stable identity and history

Classwork, recipients, submissions/attempts, grades, and Gradebook cells must
be joined by database IDs:

`teacher_id → subject_offering_id → classwork_id → student_id → term/category/column`

Names may change; IDs and historical relationships must remain stable. Archive
is the normal way to remove work from active views. Do not hard-delete an item
that already has submissions, attempts, grades, or released results.

## Shared teacher creation and management flow

This common workflow applies to all three phases, with phase-specific fields
and assessment behavior.

1. **Open a category.** The teacher opens Classwork and chooses PT, WW, or EX.
2. **Choose the class.** Show only the signed-in teacher's active offerings for
   the current school year and term. Identify each option using subject,
   grade/strand where applicable, section, and school year. Never combine
   offerings solely because their section names match.
3. **Choose recipients.** By default, target all currently enrolled students
   in the selected offering. If individual targeting is supported, only allow
   students enrolled in that offering and show the selected recipient count.
4. **Choose completion mode.** Offer online-in-app or in-person/manual where
   the category supports both. Explain the student experience before
   confirming.
5. **Enter task/assessment details.** Validate title, instructions, points,
   schedule/deadline, and any category-specific configuration. Show a preview
   of offering, audience, mode, term, category, points, and Gradebook mapping.
6. **Save as draft or publish.** A draft is teacher-only and creates no student
   task requiring action. Publish makes the item visible to its intended
   students only after the database confirms the write and recipient setup.
7. **Monitor and manage.** The teacher sees the item under its category and
   offering, with lifecycle state and per-student progress. Edit, return,
   release, close, or archive operations must retain history and report errors
   explicitly.
8. **Student and parent visibility.** Students see work only for their active
   enrollments. A parent sees only the linked child's published work and
   released results, never private teacher notes or another student's data.
9. **Gradebook synchronization.** The final approved score is associated with
   the same offering, term, grading category, and reserved column as the
   classwork item. A score must not be copied into a different teacher's or
   term's Gradebook.

### Scheduling Models, Section Isolation & Special Accommodations (iLearnU Style)

Classwork scheduling employs two distinct models tailored to assessment type, while enforcing strict section-level privacy and student make-up accommodations:

1. **Model A: Quizzes and Examinations (Synchronous Single-Day Testing Window):**
   - Built for in-class or live online assessments.
   - Requires setting:
     - `exam_date`: The specific calendar day the assessment takes place.
     - `start_time`: The exact time the assessment unlocks for students (e.g., 9:00 AM).
     - `end_time`: The hard cutoff time on that same day (e.g., 10:30 AM).
   - **Strict Same-Day Boundary:** The `start_time` and `end_time` MUST fall within the same calendar day. Students cannot open, answer, or submit questions outside this window.
2. **Model B: Activities, Assignments & Performance Tasks (Asynchronous Windowed Deadlines):**
   - Modeled after flexible LMS assignment flows (such as iLearnU):
     - `available_from` (Start Date & Time): When students can start viewing instructions, attachments, and preparing their submissions.
     - `due_date` (Standard Deadline): The targeted deadline.
     - `allow_late_submission` (Toggle): When enabled by the teacher, students who miss the deadline can still hand in their work. Submissions uploaded after `due_date` are automatically stamped with an amber `'LATE'` badge and duration, allowing the teacher to apply late policies at their discretion.
3. **Strict Section-Level Isolation:**
   - Every classwork item belongs strictly to its unique `subject_offering_id` (Section).
   - Students in Section A (e.g., Diamond) CANNOT see, access, or preview a quiz, exam, or activity created for Section B (e.g., Emerald), even if both sections are taught by the exact same teacher and share the same subject name.
   - During multi-section batch authoring, independent schedule rows are generated per section (e.g., Section Diamond quiz on Monday 8:00–9:30 AM; Section Emerald quiz on Tuesday 1:00–2:30 PM).
4. **Make-up / Special Accommodation Workflow (For Absent or Missed Students):**
   - For students who were absent, sick, or suffered connectivity loss during the scheduled quiz/exam window or missed an activity deadline:
     - The teacher can create a **"Special / Make-up Schedule"** targeted specifically to the individual learner(s).
     - This opens an exclusive time window for the absent student without re-opening or disrupting the already completed submissions and grades of the rest of the class.

### Publication and enrollment changes

- At publish time, create an explicit recipient/roster record for the students
  who are assigned the work. This makes the assigned count and historical
  audience understandable.
- Recommended rule: a student enrolled after publication is added to an
  active assignment for that offering, unless the teacher chose a fixed
  recipient list. A student who withdraws keeps historical records, but no
  longer receives new work for that offering.
- Before implementing this rule, finalize whether the system uses a publish-time
  roster snapshot, dynamic enrollment, or a combination. The recommended
  approach is a snapshot with explicit handling of later enrollment changes.
- Reassigning a student, moving a student between sections, or changing an
  offering must not silently move old scores. Preserve the original offering
  and roster context in the historical record.

## Gradebook integration rules

1. Every graded classwork item is assigned one category (`ww`, `pt`, or `ex`),
   term number, and stable Gradebook column index within its offering.
2. A column is reserved before publishing. If the relevant category has no free
   column, block publication and explain why; never overwrite another item.
3. The item stores the Gradebook mapping. Reordering or editing a title must not
   change the mapping.
4. The classwork score record is the authoritative per-item score. Gradebook
   reads those scores and computes category totals/weighted grades. If the
   existing JSON Gradebook sheet remains in use, synchronization must be
   reliable, ownership-checked, retryable, and reconcilable; the same score
   must not be independently edited in two competing stores.
5. Store the maximum points/HPS with the item. Validate each score as
   `0 <= score <= max_score`. Preserve decimals if allowed by the policy.
6. Keep separate states for not assigned, not yet submitted, submitted, late,
   not yet graded, returned, graded, excused, absent, and released as needed.
   A null score is not zero. A zero score is an explicit teacher-entered grade.
7. The teacher may correct a grade, but record who changed it, when, the old
   value, and the reason where required. Keep released grades visible until a
   correction is deliberately saved and re-released.
8. **Strict Column Capacity Ceiling (Max 10 Items — Absolute Hard Limit):**
   - In accordance with the official DepEd E-Class Record standard (`TEMPLATE - E-Class Record.xlsx`),
     each term has a strict maximum of 10 columns for Written Works (`WW 1` – `WW 10`)
     and 10 columns for Performance Tasks (`PT 1` – `PT 10`), plus 3 slots for
     Examinations (`ST 1`, `ST 2`, `TE`).
   - **Absolute Hard Limit:** Creating an 11th item is strictly blocked by both UI and backend.
     Once all 10 slots are occupied for a term and category, the "+ Create" button is disabled and
     presents a clear error banner: *"Maximum limit reached: You have already assigned all 10 [WW / PT]
     columns for Term [X]. You cannot create additional items unless an existing item is archived or deleted."*
     Silent column reuse, column overwriting, or adding an 11th item is strictly prohibited.
9. **DepEd Order No. 015, s. 2026 Zero-Exam Rule:**
   - Subjects configured with `ex_weight == 0%` (e.g., *Research, Design and
     Innovation* under SSHS - Academic) do NOT have an examination component.
   - For these subjects, EX column reservation and EX assessment creation are
     completely disabled. Initial Grades are computed 100% from Written Works and
     Performance Tasks: `Initial Grade = round2(wwWs + ptWs)`.
10. **Term Scope Enforcement:**
    - A classwork item may only be assigned to a term that is actively taught by
      that subject offering (derived from `terms_taught` and `term_block`). A
      1-term subject taught in Term 2 cannot have classwork created in Term 1 or
      Term 3.
11. **Multi-Section Batch Creation:**
    - When a teacher instructs multiple sections of the same subject offering,
      the teacher can author the task once and publish as a batch. The system
      creates independent `classwork_items` rows per section linked by a shared
      `batch_group_id`, allowing distinct section deadlines while keeping
      authoring synchronized.
12. **File Upload Security, Allowed Formats & Rate Limiting:**
    - **Allowed File Formats:**
      - Documents: `.pdf` (`application/pdf`), `.docx` (`application/vnd.openxmlformats-officedocument.wordprocessingml.document`), `.doc` (`application/msword`), `.txt` (`text/plain`).
      - Student Media / Artifacts: `.png` (`image/png`), `.jpg` / `.jpeg` (`image/jpeg`).
      - All other extensions (e.g., `.exe`, `.bat`, `.zip`, `.rar`) are strictly blocked.
    - **Max File Size:** Maximum **5 MiB (5,242,880 bytes)** per file. Files exceeding this limit are rejected immediately before upload starts.
    - **Upload Rate Limiting:** Maximum **3 file upload operations per minute per teacher** to prevent storage exhaustion and spam. An inline cooldown indicator enforces this window.

## Phase 1 — Performance Tasks (PT)

### Teacher creates a PT

1. Open **Classwork → Performance Tasks → Create PT**.
2. Select one owned subject offering and term. Show the complete class context
   so duplicate section names are distinguishable.
3. Choose **Online in ClassRealm** or **In person / manual record**.
4. Enter a title, description, detailed instructions, maximum score (HPS), and
   optional deadline.
   - **Rubric / Criteria Matrix:** The teacher can configure criteria rows
     (e.g., *Content & Accuracy*, *Execution & Technique*, *Presentation*),
     each with individual maximum points. The sum of criteria points must
     strictly equal the task's HPS.
   - **Section-Specific Deadlines:** In multi-section batches, each section may
     have a distinct deadline or "No Due Date" based on class schedules.
5. For online mode, define allowed submission type (text, file, or both),
   attempts/resubmissions, accepted file types/size (PDF, DOC, DOCX up to 3 MiB),
   late policy, and whether a teacher attachment is provided. Do not show file
   upload controls for manual mode unless the teacher is attaching task
   instructions for students.
6. For manual mode, state that students will complete/hand in the work outside
   ClassRealm and that the teacher will record status, score, and feedback.
7. Select or confirm the next free PT Gradebook column for this offering and
   term (`PT 1` – `PT 10`). Show the column label and maximum points in the preview.
8. Save a draft or publish. Publishing must atomically create/confirm the PT,
   Gradebook reservation, and intended recipients. If any required step fails,
   report failure and do not show a success state.

### Student completes a PT

- **Online:** open the task, read instructions, prepare the response, submit
  before the effective deadline, and receive a durable confirmation and
  timestamp. If resubmission is allowed, show attempts remaining and preserve
  prior submission history.
- **In person/manual:** view the published task and its due date, then complete
  and hand in the output to the teacher outside the app. The student sees a
  status/score only after the teacher records it. There is no app submission
  receipt for physical work.
- In either mode, the student sees only their own current status and released
  score/feedback. They cannot see the teacher's answer key, private notes, or
  classmates' work.

### Teacher reviews and records a PT

- For online submissions, review the submitted response/file, grade against
  points/rubric, add feedback, and optionally return it for revision if the
  policy permits.
- For manual work, open the enrolled-student roster, select each learner, and
  record a status and score from the paper, demonstration, presentation, or
  other in-person evidence. Provide a bulk-entry option with per-student
  validation and a confirmation summary.
- **Offline-First Resilience:** Manual grading works seamlessly without internet.
  Scores and statuses are immediately saved to local Drift SQLite with
  `sync_status = 'pending_sync'`. A background sync service flushes the queue
  to Supabase upon reconnection without blocking the teacher.
- Distinguish **not yet graded** from **not submitted**, **absent**,
  **excused**, and **zero**. Support a manual note/evidence reference without
  requiring a digital copy of the physical output.
- Validate score against maximum points, record grader and timestamp, and
  retain correction history.
- Release the score/feedback to the student (and linked parent) only after the
  teacher's explicit release action or the configured release rule.

### PT to Gradebook

The graded PT writes to its reserved `PT n` column for the exact student,
offering, and term. The Gradebook shows the score, HPS, status, and source PT
title. Blank/not-yet-graded values remain distinct from zero. PT weighted scores
are calculated using that offering's configured PT weight. Archiving a PT hides
it from active assignment views but preserves the Gradebook column and history.

### Phase 1 acceptance criteria

- Two teachers with similarly named subjects/sections cannot read, update,
  publish, grade, or archive each other's PTs.
- A student outside the offering cannot see, submit, or be graded on the PT.
- Online mode supports the selected submission method and records a durable
  submission state.
- In-person/manual mode has no student upload/submit path, but the teacher can
  record each student's status, score, and feedback.
- The student (and authorized parent) sees the task and only released results.
- PT maps to the correct offering, term, PT category, HPS, and stable column.
- Failed saves/uploads do not report success or lose teacher-entered form data.
- Late work, resubmissions, withdrawn students, corrections, and archival keep
  coherent history.
- Gradebook and classwork show the same score and distinguish blank from zero.

## Phase 2 — Written Works (WW)

Phase 2 reuses the proven ownership, roster, mode, status, grade, and audit
rules from PT.

1. The teacher chooses the owned offering and term, then creates a WW item such
   as an activity, worksheet, or assignment.
2. The teacher chooses online-in-app submission or in-person/manual recording.
   In-person may mean a paper worksheet, oral recitation, board work, or other
   classroom activity; the teacher records the outcome in ClassRealm.
3. The teacher sets points, deadline, instructions, allowed response type,
   late/resubmission policy, and any relevant attachment.
4. The system reserves the next free WW column and publishes to the correct
   recipients.
5. Students complete in the selected mode; teachers grade online submissions
   or enter manual results from classroom work.
6. Released scores populate the matching `WW n` Gradebook column and contribute
   to the offering's configured WW computation.
7. WW items cannot consume PT/EX columns or affect another term/offering.

Phase 2 acceptance additionally verifies that several WW items map to distinct
columns and that full-column behavior is explicit and safe.

## Phase 3 — Quizzes (Short Quizzes)

Quizzes in ClassRealm are formative or short summative assessments (typically 10–30 items). Quizzes can be mapped to an available Written Works column (`WW n`) or an exam prep slot based on the offering's configuration.

### Essential Quiz Features (Mandatory):
1. **Creation Methods:**
   - **Manual Input:** The teacher manually enters question stems, answer choices, correct keys, and points.
   - **AI-Generated from Uploaded File:** (See comprehensive AI Generation Architecture below).
2. **Item Analysis (Mandatory for All Quizzes):** Every quiz automatically generates item difficulty, distractor breakdown, and error analysis upon completion.
3. **Anti-Cheating & Live Proctoring (Mandatory for All Quizzes):** Quizzes enforce fullscreen mode, unfocus/tab-switch tracking, anti-peeking within-section randomization, and live teacher monitor with Retake/Kick controls.

---

## Phase 4 — Major Examinations (EX: ST1, ST2, TE)

> **DepEd DO 15, s. 2026 Exemption:** If the selected subject offering has
> `ex_weight == 0%` (such as *Research, Design and Innovation* under SSHS -
> Academic), the Examination tab and EX creation flow are strictly disabled and
> marked with an informational banner: *"This subject has no Examination component
> under DepEd Order No. 015, s. 2026. Initial Grades are computed 100% from
> Written Works and Performance Tasks."* Teachers are not required or permitted
> to create EX items or reserve EX Gradebook slots for zero-exam subjects.

For subjects that include an examination component (`ex_weight > 0`, e.g., 20% or 30%),
major examinations correspond to the official DepEd slots:
- `ST 1`: Short Test 1 (Periodical check 1)
- `ST 2`: Short Test 2 (Periodical check 2)
- `TE`: Term Examination (Quarterly / Term Exam)

Like Quizzes, Examinations strictly incorporate:
- **Digital in ClassRealm** (timed in-app testing with live proctoring & anti-cheating).
- **In-Person / Manual Record** (paper-based exam administered in classroom; teacher logs scores).
- **Comprehensive Item Analysis** (difficulty index, discrimination index, distractor analysis, and misconception review).

---

## AI-Powered Quiz & Exam Generation Architecture

### 1. API Key Security & 3-Key Rotation Architecture (Public GitHub Safety)
- **Zero Exposed Keys:** Because the ClassRealm repository is public on GitHub, **no API keys are ever stored in Flutter client code or committed to git**.
- **Where to Store the API Keys:**
  Keys are securely stored as backend environment secrets in Supabase via the Supabase CLI:
  ```bash
  supabase secrets set GEMINI_API_KEY_1="AIzaSy..."
  supabase secrets set GEMINI_API_KEY_2="AIzaSy..."
  supabase secrets set GEMINI_API_KEY_3="AIzaSy..."
  ```
- **Supabase Edge Function (`generate-assessment`):**
  - The Flutter client sends an authenticated POST request with the file text / storage reference and generation parameters to the Supabase Edge Function.
  - **Automatic 3-Key Rotation:** The Edge Function maintains an array of the 3 keys. It initiates generation with Key 1. If Key 1 encounters a rate limit (HTTP 429), quota exhaustion, or server error, it instantly and transparently fails over to Key 2, and then Key 3. This guarantees unbroken generation without user-facing errors.

### 2. Document-Grounded Generation (Zero Hallucination)
- The teacher uploads a reference document (`.pdf`, `.docx`, `.doc`, `.txt`, max 5 MiB).
- Strict system prompt instructs the AI model:
  > *"You are an academic assessment generator. Generate questions STRICTLY and SOLELY from the provided source document text. Do not invent facts, outside knowledge, or information not present in the document."*
- If the document lacks sufficient content for the requested item count, the AI returns the maximum possible valid items with an explicit explanation.

### 3. Teacher Configuration Flow
Before generation starts, the teacher configures:
1. **Multi-Select / Hybrid Assessment Focus Selector (Select 1 or More, or All):**
   - Teachers can tailor the cognitive blend of questions by checking any combination (from 1 up to all 4 domains):
     - [ ] **Terms and Definitions:** Vocabulary, key terminology, foundational recall, and principles.
     - [ ] **Comprehensive / Conceptual Understanding:** Explanations, synthesis, summaries, and relationships between concepts.
     - [ ] **Application & Problem Solving:** Real-world scenarios, situational word problems, and practical application.
     - [ ] **Critical Thinking & Analysis:** Deep evaluation, logical reasoning, and distinguishing cause/effect or arguments.
   - **Hybrid Generation Engine:** When a teacher selects multiple styles (or all 4), the AI automatically blends and distributes questions across all checked cognitive domains, ensuring a balanced, high-rigor assessment.
2. **Question Types (Select 1 to 3 types):**
   - Allowed Types:
     - [ ] **Multiple Choice** (4 choices: A, B, C, D)
     - [ ] **True or False**
     - [ ] **Identification** (Direct recall / fill-in-the-blank answer)
     - *(Note: Matching Type is strictly excluded and prohibited).*
   - Teacher must select **at least 1 type** and may select up to all 3 types.
3. **Item Counts per Type & 100-Item Maximum:**
   - Teacher inputs the desired item count for each selected type (e.g., 20 Multiple Choice, 15 True or False, 15 Identification).
   - Validation rules:
     - For each selected question type, count must be $\ge 1$.
     - Unselected question types are automatically set to 0.
     - Total items across all types must be $\le 100$ items (strict maximum ceiling).
   - AI automatically generates the question stem, all answer choices, and the **correct answer key** for every item.

### 4. Mandatory Teacher Review & Edit Screen (Before Publishing)
- Generated items are NEVER published directly to students.
- An interactive Review & Edit screen displays all generated parts and questions:
  - Teacher can edit question stems, modify distractors, change the correct answer key, adjust points per item, delete unwanted questions, or add manual items.
  - Visual validation alerts if any question has an empty stem or missing answer key.
- Once the teacher is satisfied, they click **"Publish Quiz / Exam"**.
- Only currently enrolled students in that exact `subject_offering_id` receive access.

---

## Student Assessment Experience: Sectioned Layout & Anti-Peeking

This layout applies identically to **both Quizzes and Examinations (ST1, ST2, TE)**:

### 1. Strictly Sectioned Grouping (Never Mixed!)
- Questions are cleanly segregated into distinct numbered parts by question type:
  - **Part I: Multiple Choice** (Questions 1 to N)
  - **Part II: True or False** (Questions N+1 to M)
  - **Part III: Identification** (Questions M+1 to P)
- **STRICT PROHIBITION:** Questions of different types must NEVER be interspersed or mixed (e.g., Q1 Multiple Choice followed by Q2 True or False is strictly forbidden).

### 2. Within-Section Question Randomization (Anti-Peeking)
- When students take the assessment concurrently in a classroom:
  - The sequence of questions **within each section** is randomized per student attempt.
  - Student A's Question 1 in Part I will be different from Student B's Question 1 in Part I.
  - However, all students answer Part I (Multiple Choice) first, then Part II (True or False), then Part III (Identification), ensuring a consistent pedagogical flow while eliminating side-by-side screen peeking.

---

## Live Teacher Proctoring & Anti-Cheating Engine (Quizzes & Exams)

This anti-cheating system is active for **both Quizzes and Examinations (ST1, ST2, TE)**:

### 1. Client-Side Integrity & Event Monitoring
- **Fullscreen Enforcement:** Student enters full-screen mode upon starting. Exiting triggers an immediate warning dialog.
- **No Auto-Kick / No Auto-Submit:** Switching tabs, unfocusing the browser window, or minimizing the mobile app does **NOT** automatically submit or kick the student (preventing accidental lockouts from notifications or OS popups).
- **Silent Infraction Logging:** The client logs all focus disruptions via `AppLifecycleState` and `window.onblur`:
  - `violation_type`: `'tab_switch'`, `'window_blur'`, or `'app_backgrounded'`
  - `occurred_at`: Precise timestamp
  - `duration_seconds`: Exact elapsed time spent away from the assessment screen.
- **Clipboard & Context Menu Lock:** Text selection, copying questions, pasting external text, and right-click inspect are disabled during the test.

### 2. Live Proctoring Monitor Dashboard (Teacher Side)
- While the quiz or exam is underway, the teacher opens the **Live Assessment Monitor**:
  - Displays a live real-time roster of all enrolled students.
  - Status Indicators: `Not Started` (Grey), `In Progress` (Blue, with current question number e.g. `Q 14/30`), `Submitted` (Green).
  - **Real-Time Violation Counter Badge:** Shows infraction count and cumulative time away (e.g., `⚠️ 3 tab switches (42s away)`). The badge turns amber at 1–2 infractions and red at 3+ infractions.
  - Clicking any student card opens a detailed **Violation Timeline** showing exact timestamps and durations away from the screen.

### 3. Teacher Intervention Controls (Per Student)
Next to each student row, the teacher has two distinct authoritative action buttons:
1. **Retake Action:**
   - Prompts a confirmation dialog: *"Allow [Student Name] to retake this assessment?"*.
   - Resets the student's existing attempt safely.
   - Clears prior responses and unlocks the student's screen to restart from Question 1.
   - Designed for hardware crashes, accidental browser closures, or excused first warnings.
2. **Kick Action (Zero Score Lock):**
   - Prompts a prominent red confirmation dialog: *"Kick [Student Name] for academic dishonesty?"*.
   - Immediately terminates and locks the student's assessment session in real time via Supabase Realtime WebSocket broadcast.
   - Automatically records a final score of **zero (0)** with status `'kicked'` and audit reason `'kicked_for_academic_dishonesty'`.
   - The student's device immediately displays a locked overlay: *"Your assessment attempt has been terminated by your teacher for academic dishonesty."*

---

## Comprehensive Item Analysis Dashboard (Quizzes & Exams)

Immediately after a Quiz or Examination (ST1, ST2, TE) is closed or graded, teachers have access to the **Item Analysis Dashboard**:

### 1. Difficulty Index ($P$) per Question
The Difficulty Index measures how easy or difficult an item was for the class:
$$P = \frac{R}{T}$$
*(where $R$ = Number of students who answered correctly, and $T$ = Total students who attempted the item).*

- **Standard DepEd Classification Tiers:**
  - **Very Easy:** $P > 0.85$ (Consider revising or substituting for higher cognitive rigor).
  - **Easy:** $0.75 < P \le 0.85$
  - **Moderate / Ideal:** $0.25 \le P \le 0.75$ (Ideal balanced question difficulty).
  - **Difficult:** $0.15 \le P < 0.25$
  - **Very Difficult:** $P < 0.15$ (Flagged for potential wording ambiguity or key error).

### 2. Discrimination Index ($D$)
Evaluates how effectively the item distinguishes between high-performing and low-performing learners:
$$D = \frac{U - L}{N}$$
*(where $U$ = correct answers in top 27% of class, $L$ = correct answers in bottom 27%, and $N$ = size of upper/lower group).*

- **Quality Classification:**
  - $D \ge 0.30$: **Strong Item** (Retain as high-performing assessment item).
  - $0.20 \le D < 0.30$: **Marginal Item** (Minor revision recommended).
  - $D < 0.20$: **Poor Item / Questionable** (Needs overhaul or exclusion).

### 3. Distractor Efficiency Analysis (Multiple Choice)
- Displays a visual bar chart of student choice distribution across all options (A, B, C, D).
- Highlights **Non-functioning Distractors** (options chosen by 0% of students).
- Highlights **Ambiguous Distractors** (incorrect options chosen more frequently than the correct key, signaling potential instructional confusion).

### 4. Identification Misconceptions & Typo Review
- Aggregates top submitted incorrect text responses with frequency counts.
- **Manual Typo Forgiveness / Credit Granting:** Allows the teacher to award points with a single click if a student made an acceptable minor typo (e.g., *"mitokondria"* instead of *"mitochondria"*), automatically updating the student's score and recalculating class statistics.

### 5. Exportable Quality Assurance Report
- One-click **[Export Item Analysis (CSV / PDF)]** for departmental subject chair reviews, school accreditation, and DepEd quality audits.

---

## Code Architecture & Modular Directory Structure (Anti-2500-Line Rule)

To strictly prevent unmaintainable monolithic files (such as files exceeding 1,000–2,500 lines of code), all implementation code for Quizzes, Exams, Item Analysis, and Anti-Cheating MUST be split into clean, dedicated folders.

### 1. Golden Architecture Rules:
- **Max File Length:** No file shall exceed **350–400 lines of code**.
- **Separation of Concerns:** Business logic/math calculators, UI screens, dialog modals, and state services must reside in distinct files.
- **Reusability:** Shared assessment components must be reused between Quizzes and Exams rather than copy-pasted.

### 2. Dedicated Folder Blueprint:
```text
lib/features/teacher/sub_features/assessments/
├── item_analysis/                           # Dedicated Item Analysis Module
│   ├── models/
│   │   ├── item_difficulty_stat.dart       # P-Index, D-Index data model
│   │   ├── distractor_stat.dart            # Choice frequency breakdown
│   │   └── item_analysis_report.dart       # Aggregated assessment report
│   ├── controllers/
│   │   └── item_analysis_calculator.dart   # Pure math & statistic calculation engine
│   └── widgets/
│       ├── item_analysis_modal.dart        # Main dialog container (max 250 lines)
│       ├── difficulty_indicator_badge.dart # Color-coded status badge (Easy/Mod/Diff)
│       ├── distractor_breakdown_card.dart  # Multi-choice frequency distribution bar
│       ├── identification_misconceptions_list.dart # Typo & error review list
│       └── item_analysis_export_button.dart# CSV/PDF download trigger
│
├── anti_cheating/                           # Dedicated Anti-Cheating & Proctoring Module
│   ├── models/
│   │   ├── proctor_violation_log.dart      # Violation log model
│   │   └── student_live_proctor_state.dart # Realtime student session state
│   ├── services/
│   │   ├── student_lifecycle_watcher.dart  # Fullscreen & AppLifecycle listener
│   │   └── teacher_proctor_channel_service.dart # Supabase Realtime channel manager
│   └── widgets/
│       ├── live_proctor_monitor_modal.dart # Main proctoring dashboard dialog
│       ├── student_proctor_card.dart       # Individual student tile with live status
│       ├── violation_timeline_tile.dart    # Detailed timestamped infraction log
│       ├── retake_confirmation_dialog.dart # Reset attempt confirmation modal
│       └── kick_student_alert_dialog.dart  # Academic dishonesty kick modal
│
├── quiz_exam_authoring/                     # Creation & AI Generation
│   ├── widgets/
│   │   ├── assessment_type_tabs.dart       # Quiz vs Exam selector
│   │   ├── ai_generation_config_card.dart  # Style focus & item count selectors
│   │   ├── question_editor_tile.dart       # Individual question editing card
│   │   └── assessment_preview_modal.dart   # Pre-publishing review screen
│   └── services/
│       └── ai_assessment_generator_service.dart # Edge function caller & key rotation
│
└── student_taking/                          # Student Taking Experience
    ├── widgets/
    │   ├── sectioned_part_header.dart      # Part I, Part II, Part III dividers
    │   ├── exam_countdown_timer.dart       # Sticky countdown clock & auto-submit
    │   └── question_view_card.dart         # Question stem & option selection
    └── controllers/
        └── student_assessment_controller.dart # Response state & local caching
```

---

## Unbroken End-to-End User Experience Blueprint

The entire lifecycle from creation to Gradebook is continuous and resilient:

```text
[Teacher Authors / AI Generates Assessment]
                     │
                     ▼
[Review & Edit Screen (Validate Stems & Answer Keys)]
                     │
                     ▼
[Publish with Single-Day Schedule & Anti-Cheating Enabled]
                     │
                     ▼
[Students Enter Assessment in Fullscreen] ───(Tab Switch / Blur)──► [Logged to Proctor Log]
                     │                                                      │
                     ▼                                                      ▼
[Teacher Monitors via Live Proctoring Dashboard] ◄──────────────────────────┘
  ├─ Normal: Student Answers & Submits
  ├─ Glitch / Warning: Teacher clicks [Retake] (Reset Attempt)
  └─ Dishonesty: Teacher clicks [Kick] (Locks session, sets score to 0)
                     │
                     ▼
[Assessment Completed / Timer Expires]
                     │
                     ▼
[Auto-Scoring for Objective + Teacher Review for Identification]
                     │
                     ▼
[Instant Item Analysis Dashboard (P-Index, D-Index, Distractor Breakdown)]
                     │
                     ▼
[Teacher Approves & Releases Grades]
                     │
                     ▼
[Authoritative Sync to DepEd Gradebook (ww or ex Column)] ──► [Zero Broken States]
```

---

## End-to-End Database Schema & Gradebook Sync Spec

### 1. Database Tables & Relationships
- **`classwork_items`:**
  - `id` (UUID PK), `subject_offering_id` (UUID FK), `teacher_id` (UUID FK), `grading_category` (`'ww'`, `'pt'`, `'ex'`), `classwork_type` (`'performance_task'`, `'activity'`, `'assignment'`, `'quiz'`, `'exam'`), `term_number` (INT 1-3), `gradebook_column_index` (INT 1-10 for WW/PT, 1-3 for EX), `title` (TEXT), `description` (TEXT), `instructions` (TEXT), `highest_possible_score` (NUMERIC), `completion_mode` (`'online'`, `'manual'`), `batch_group_id` (UUID nullable), `deadline` (TIMESTAMPTZ nullable), `is_published` (BOOLEAN), `is_archived` (BOOLEAN), `created_at` (TIMESTAMPTZ).
- **`classwork_attachments`:**
  - `id` (UUID PK), `classwork_id` (UUID FK), `file_name` (TEXT), `file_path` (TEXT), `file_size_bytes` (INT $\le 5,242,880$), `mime_type` (TEXT), `created_at` (TIMESTAMPTZ).
- **`student_classwork_submissions`:**
  - `id` (UUID PK), `classwork_id` (UUID FK), `student_id` (UUID FK), `status` (`'assigned'`, `'submitted'`, `'late'`, `'graded'`, `'returned'`, `'absent'`, `'excused'`), `submission_text` (TEXT), `submission_file_path` (TEXT), `score` (NUMERIC), `teacher_feedback` (TEXT), `submitted_at` (TIMESTAMPTZ), `graded_at` (TIMESTAMPTZ).
- **`digital_assessments`:**
  - `id` (UUID PK), `classwork_id` (UUID FK UNIQUE), `assessment_type` (`'quiz'`, `'st1'`, `'st2'`, `'term_exam'`), `style_focus` (TEXT), `time_limit_minutes` (INT nullable), `max_attempts` (INT default 1), `source_document_path` (TEXT nullable), `created_at` (TIMESTAMPTZ).
- **`assessment_sections`:**
  - `id` (UUID PK), `assessment_id` (UUID FK), `section_part` (INT 1-3), `question_type` (`'multiple_choice'`, `'true_false'`, `'identification'`), `title` (TEXT), `instructions` (TEXT).
- **`assessment_questions`:**
  - `id` (UUID PK), `section_id` (UUID FK), `question_order` (INT), `question_text` (TEXT), `points` (NUMERIC default 1), `options` (JSONB nullable for Multiple Choice: `["Option A", "Option B", ...]`), `correct_answer` (TEXT).
- **`assessment_attempts`:**
  - `id` (UUID PK), `assessment_id` (UUID FK), `student_id` (UUID FK), `attempt_number` (INT), `started_at` (TIMESTAMPTZ), `submitted_at` (TIMESTAMPTZ), `total_score` (NUMERIC), `status` (`'in_progress'`, `'submitted'`, `'kicked'`, `'retake_requested'`), `kicked_reason` (TEXT).
- **`assessment_responses`:**
  - `id` (UUID PK), `attempt_id` (UUID FK), `question_id` (UUID FK), `student_answer` (TEXT), `is_correct` (BOOLEAN), `points_awarded` (NUMERIC).
- **`proctoring_violation_logs`:**
  - `id` (UUID PK), `attempt_id` (UUID FK), `student_id` (UUID FK), `violation_type` (`'tab_switch'`, `'window_blur'`, `'app_backgrounded'`), `duration_seconds` (INT), `created_at` (TIMESTAMPTZ).

### 2. Synchronization to Official Gradebook (`gradebook_records`):
- When a classwork score is released or an exam attempt is scored:
  1. The score is verified: $0 \le \text{score} \le \text{highest\_possible\_score}$.
  2. The target cell is identified by: `subject_offering_id` + `term_number` + `grading_category` (`ww`, `pt`, `ex`) + `gradebook_column_index` + `student_id`.
  3. The gradebook cell receives the authoritative raw score and updates the category total:
     $$\text{Total Score} = \sum \text{Item Scores}, \quad \text{Total HPS} = \sum \text{Item HPS}$$
     $$\text{Weighted Score (WS)} = \left(\frac{\text{Total Score}}{\text{Total HPS}}\right) \times \text{Category Weight}$$
  4. If `ex_weight == 0`, Initial Grade is computed directly from WW and PT weighted scores:
     $$\text{Initial Grade} = \text{round2}(\text{WW WS} + \text{PT WS})$$
  5. The transmuted Quarterly Grade is re-calculated and reflected on the Gradebook spreadsheet in real time.

---

## Prerequisites to finalize before implementation

Resolve these design/schema decisions before coding Phase 1. Do not assume that
a field in one migration or UI has already been deployed to the live Supabase
project.

### 1. Verify and reconcile the database schema

Compare migrations, deployed Supabase schema, Flutter models, repositories,
and any Edge Functions. In particular, confirm:

- `subject_offerings` ownership/uniqueness behavior when multiple teachers have
  similarly named or shared classes;
- the actual `classwork_items` fields for grading category, term, Gradebook
  column, publication, completion mode, target recipients, and batch IDs;
- submission/status constraints and whether a unique `(classwork_id,
  student_id)` row is sufficient for the chosen resubmission history;
- private attachment storage metadata, limits, and access method;
- digital assessment, attempt, response, and item-analysis tables; and
- Gradebook sheet and term-grade constraints.

Produce a forward-only migration plan after this comparison. Do not edit an
already-applied migration as a substitute for a forward migration.

### 2. Finalize Gradebook column policy

Confirm the term numbering, category column capacity, whether columns are
reserved per offering/term, how full categories behave, and how official term
grades are computed. Define whether scores are stored in per-item records,
Gradebook sheet JSON, or one authoritative store with a derived cache. The
recommended source of truth is per-item score/attempt records, with Gradebook
as a calculated view and any JSON sheet treated as a synchronized cache.

### 3. Finalize manual grading semantics

Set the exact allowed student states for online and in-person work, how absent
and excused entries affect Gradebook computation, whether manual scores can be
bulk-entered, how corrections are audited, when results become visible to
students/parents, and what happens to existing records after a student changes
section.

### 4. Finalize enrollment and recipient behavior

Choose snapshot, dynamic, or hybrid assignment recipients; define what happens
when a student joins, withdraws, is archived, or changes offering after
publication. Ensure all choices preserve historical assignments and scores.

### 5. Finalize teacher and student permissions

Define ownership checks, student self-access checks, parent-link checks, draft
visibility, result release, private notes, and attachment permissions. Enforce
them in database RLS and/or trusted backend functions, not just in Flutter.

### 6. Resolve current implementation gaps

Before feature expansion:

- remove mock-backed success fallbacks from production classwork reads/writes;
- ensure repository errors propagate so the UI cannot claim a failed write
  succeeded;
- scope every teacher query/mutation to the authenticated teacher's offering;
- resolve model/schema mismatch for `grading_category`, `term_number`,
  `gradebook_column_index`, recipient IDs, and completion mode;
- define secure private attachment upload/download and cleanup behavior;
- implement durable student submission and teacher grading flows for PT/WW;
- connect classwork scores to Gradebook and prove that both views agree; and
- ensure the digital exam flow uses persisted Supabase attempts/responses rather
  than mock-only results before calling it production-ready.

## Recommended implementation sequence

Development will proceed strictly in the following sequential order:

### Sprint 1 — Performance Tasks (PT)
- Teacher creation flow (Online in ClassRealm & In-Person / Manual record).
- Rubric / Criteria Matrix configuration (sum of criteria points equals HPS).
- Strict column capacity ceiling enforcement: Maximum 10 items (`PT 1` – `PT 10`).
- Student submission / In-person manual scoring roster.
- Offline-First local queue with Drift SQLite for manual grading.
- Gradebook column reservation and weighted score calculation ($0 \le \text{score} \le \text{HPS}$).

### Sprint 2 — Written Works: Activity / Assignment (WW)
- Teacher creation flow (Online in ClassRealm & In-Person / Manual record).
- Strict column capacity ceiling enforcement: Maximum 10 items (`WW 1` – `WW 10`).
- File attachment upload validation (PDF, DOC, DOCX, TXT max 5 MiB) and rate limiting (max 3 uploads/minute).
- Student submission interface, teacher grading, and Gradebook sync.

### Sprint 3 — Quizzes (Short Quizzes)
- Modular implementation adhering to the $\le 350-400$ lines rule in `assessments/item_analysis/` and `assessments/anti_cheating/`.
- Manual creation flow vs. AI-generated from uploaded reference document.
- Secure Supabase Edge Function (`generate-assessment`) with automatic 3-key rotation (`GEMINI_API_KEY_1`, `GEMINI_API_KEY_2`, `GEMINI_API_KEY_3`).
- Style focus selector (Terms & Definitions, Comprehensive, Application, Critical Thinking).
- Question type selector (Multiple Choice, True or False, Identification; Matching Type strictly excluded).
- Item distribution per type with a hard ceiling of 100 items max.
- Mandatory Teacher Review & Edit screen before publishing.
- Sectioned student interface (Part I, Part II, Part III) with within-section anti-peeking question randomization.
- Live teacher proctoring monitor (`anti_cheating/`) with real-time violation counter, **Retake**, and **Kick** (auto-zero) actions.
- Post-quiz Item Analysis dashboard (`item_analysis/`) with Difficulty ($P$) Index, Distractor breakdown, and error review.

### Sprint 4 — Major Examinations (EX: ST1, ST2, TE)
- DepEd Order No. 015, s. 2026 zero-exam detection and exemption banner for subjects with `ex_weight == 0%`.
- 3 official examination slots (`ST 1`, `ST 2`, `TE`).
- Comprehensive examination lifecycle with strict timer, auto-lock on expiry, and anti-cheating proctoring logs (`anti_cheating/`).
- Full Item Analysis suite (`item_analysis/`): Difficulty Index ($P$), Discrimination Index ($D$), Distractor Efficiency, and Identification Typo Forgiveness.
- Automatic objective scoring, manual review for subjective responses, and official Gradebook synchronization.
- Exportable Item Analysis report (CSV / PDF) for DepEd quality audits.

## DepEd Order No. 015, s. 2026 Curriculum Alignment

All classwork activities and Gradebook integrations must strictly adhere to the DepEd Order No. 015, s. 2026 (Strengthened Senior High School - SSHS) guidelines:

1. **Category Weightings:**
   - **SSHS - CORE:** WW 20%, PT 50%, EX 30% (3 terms, full school year).
   - **SSHS - ACADEMIC (Standard):** WW 20%, PT 50%, EX 30% or WW 20%, PT 60%, EX 20% (1 term).
   - **SSHS - ACADEMIC (Research & Innovation):** WW 40%, PT 60%, EX 0% (NO EXAM; Initial Grade = `round2(wwWs + ptWs)`).
   - **SSHS - TECH-PRO:** WW 15%, PT 65%, EX 20% (1 term).
2. **Dynamic Term Divisors:**
   - Term Grade is transmuted via the DepEd Transmutation Table (Initial Grade 60 → Transmuted 75).
   - Final Grade calculation across multiple taught terms uses the exact unit-weighted formula:
     `Final Grade = round((sum(TermGrade * UnitsPerTerm)) / TotalUnits)`.
3. **Official Descriptors:**
   - 90–100: *Outstanding*
   - 85–89: *Very Satisfactory*
   - 80–84: *Satisfactory*
   - 75–79: *Fairly Satisfactory*
   - Below 75: *Did Not Meet Expectations*

## Offline-First Architecture & Sync Queue

In environments with intermittent or zero school connectivity:
1. **Local Storage First:** All classwork metadata, enrolled student rosters, submissions, and manual grading records are cached in Drift SQLite via `LocalStorageService`.
2. **Optimistic UI Updates:** When a teacher scores physical outputs or oral presentations in class, the score and status are immediately updated in the local UI with a subtle `pending_sync` indicator badge.
3. **Silent Background Sync:** An asynchronous worker detects network restoration and flushes the queue of pending score records and status mutations to Supabase in batches without blocking teacher navigation or causing UI freezes.
4. **Conflict Resolution:** If a score was edited simultaneously, the most recent authenticated teacher mutation wins (`last_modified_at`), and an audit trail entry is preserved.

## Parent & Student Notification Lifecycle

To ensure strong home-school coordination, every classwork transition triggers automated alerts:
1. **Task Published:** Real-time push notification and in-app notification sent to all assigned students and their linked parents:
   - *"New [Performance Task / Written Work]: [Title] has been posted. Due: [Date and Time]."*
2. **Upcoming Due Date Reminder:** Automated notification dispatched 24 hours prior to deadline for any student who has not yet submitted:
   - *"Reminder: [Title] is due tomorrow at [Time]. Please submit your work on time."*
3. **Grades & Feedback Released:** Once the teacher executes the "Release Grades" action:
   - Student & Parent notification: *"Grades released for [Title]: You scored [Score]/[HPS] ([Percentage]%). Check your teacher's feedback."*
   - Directly links to the student report and feedback sheet.

## UI/UX & Inline Input Validation Standards

All Classwork authoring modals, score entry fields, and configuration forms must strictly comply with ClassRealm's design and input validation requirements:
1. **Strictly Inline Validation:** Bottom SnackBars, banners, or floating toasts are strictly prohibited for form input validation errors.
2. **Visual Error Cues:**
   - Input container or text box border highlights in distinct red (`Color(0xFFDC2626)` or `AppTheme.catRed`).
   - A clear, 12-13px red warning message with `Icons.error_outline` appears directly underneath the invalid input field.
   - The error message automatically and instantly clears as soon as the user starts editing or correcting the input.
3. **Category Color Coding:**
   - Performance Tasks (PT): Accent Emerald / `AppTheme.catGreen` (`#10B981`)
   - Written Works (WW): Accent Blue / `AppTheme.catBlue` (`#3B82F6`)
   - Examinations (EX): Accent Purple / `AppTheme.catPurple` (`#8B5CF6`)
4. **Clear Lifecycle Status Badges:**
   - `DRAFT` (Neutral Gray)
   - `PUBLISHED` (Active Blue)
   - `CLOSED` (Muted Amber)
   - `ARCHIVED` (Slate / Hidden)
