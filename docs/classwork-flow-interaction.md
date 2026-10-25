# Classwork Flow Interaction — Teacher to Student, End to End

## 1. Layunin at saklaw

Itinatakda ng dokumentong ito ang kumpletong interaction ng Teacher at Student sa
Classwork: mula sa pagbuo at pag-publish, pagtingin at paggawa ng estudyante,
pag-check/pag-grade, pag-release ng resulta, hanggang sa Gradebook at item
analysis. Saklaw nito ang:

1. **PT — Performance Task**
2. **WW — Written Work**, kasama ang activity at assignment
3. **Quiz — short digital assessment**
4. **EX — major assessment slots na ST1, ST2, at TE**

Pagkatapos maipatupad at mapatunayan ang teacher workflows ng bawat phase,
susunod na milestone ang end-to-end na pagsusuri at pagpapatapos ng Student
side. Hindi ituturing na tapos ang isang phase dahil lang gumagana ang teacher
screen: kailangan ding ma-load ng tunay na enrolled student ang item, matapos
ang pinapayagang action, at makita ang tama at awtorisadong status/score.

**Documentation/specification lamang ito.** Hindi nito ipinapalagay na mayroon
nang gumaganang implementation ang alinmang flow sa ibaba. Walang mock data ang
pinapahintulutan sa production acceptance path.

## 2. Kahulugan at pangunahing tuntunin

### 2.1 Completion mode

Sa paglikha ng PT at WW item, pipili ang teacher ng isa sa dalawang malinaw na
completion mode:

- **Online sa ClassRealm:** ang response/file ay ipinapasa sa app; may durable
  submission record at oras ng pagtanggap.
- **In-person / manual record:** ginagawa at ipinapasa ang output sa labas ng
  app (hal. papel, recitation, demo, performance); teacher ang nagtatala ng
  status, score, at feedback sa ClassRealm. Walang digital submission na
  ipinapanggap na nangyari.

Sa online quiz at EX, sinasagutan ng student ang assessment sa app. Kung may
paper-based quiz o exam, teacher ang pipili ng manual record flow; hindi ito
ituturing na digital attempt at hindi ito magkakaroon ng pekeng proctor logs o
item responses.

### 2.2 Source of truth at walang mock success

- Ang published task, recipient roster, submissions, attempts, answer
  responses, grade records, intervention events, at result-release status ay
  kailangang manggaling sa persistent, authenticated backend/database.
- Ang local database ay maaari lamang maging cache o offline queue na malinaw
  ang pending-sync state. Hindi ito maaaring magkunwaring na-save na sa
  server kung hindi pa kinukumpirma ng server.
- Huwag gumamit ng `MockDatabase`, hard-coded student roster, sample score, o
  success-shaped fallback sa alinmang production Classwork path.
- Kapag hindi available ang backend, ipakita ang error at panatilihin ang
  unsaved input kung ligtas. Huwag magpakita ng publish, submit, kick, retake,
  score-save, o release success hangga't walang authoritative confirmation.
- Ang retry ay dapat idempotent: hindi dapat lumikha ng dobleng task,
  submission, attempt, grade, o notification.
- Lahat ng time at deadline ay naka-store bilang timestamp na may timezone
  policy; pare-pareho ang ipinapakitang oras sa teacher at student.

### 2.3 Pagkakakilanlan at authorization

Ang bawat record ay nakatali sa stable IDs, hindi sa pangalan lang:

`teacher_id → subject_offering_id → classwork_id → student_id → submission/attempt → gradebook slot`

- Ang `subject_offering_id` ang nagtatakda ng teacher, subject, section, school
  year, at term.
- Dapat tiyakin ng trusted backend ang aktibong teacher identity at ownership
  ng offering sa bawat create, view, edit, publish, grade, release, archive,
  retake, o kick.
- Ang student ay makakakita at makakakilos lamang sa sariling assignment at
  attempt sa offering kung saan siya nakatala.
- Ang parent, kung may kaugnay na view, ay limitado sa naka-link na student at
  released information lamang.
- Ang pagtatago ng button o offering sa UI ay hindi kapalit ng backend
  authorization.

### 2.4 Assignment roster at enrollment changes

- Sa publish, gumawa ng recipient/roster snapshot para malinaw kung sinu-sino
  ang inatasan at ilan ang expected.
- Ang pag-enroll ng bagong student pagkatapos mag-publish ay hindi dapat
  magdagdag o mag-alis nang tahimik. Dapat sundin ang napiling policy at
  magkaroon ng audit record kung magdadagdag ang teacher.
- Kapag lumipat o nag-withdraw ang student, panatilihin ang historical
  assignment, attempt, at score sa orihinal na offering; huwag ilipat ang lumang
  grade sa bagong section.
- Ang bawat multi-section publish ay gumagawa ng hiwalay na classwork row at
  recipient roster bawat offering, kahit pareho ang title o shared batch ID.

## 3. Common end-to-end lifecycle

### A. Teacher authoring, review, at publish

1. **Buksan ang Classwork category.** Pumili ng PT, WW, Quiz, o EX slot.
2. **Piliin ang eksaktong offering.** Ipakita ang subject, grade/strand,
   section, school year, at term; huwag pag-isahin ang magkakaibang offering
   dahil magkapareho ang subject/section label.
3. **Kumpirmahin ang roster.** Ipakita ang recipient count at mga enrolled
   student na matatamaan. Default ang buong roster; ang individual targeting ay
   maaari lamang sa enrolled students.
4. **I-configure ang content.** Ilagay ang instructions, points/HPS, deadline
   o testing window, completion mode, attachment/submission settings, at
   assessment questions kung kailangan.
5. **I-configure ang Gradebook mapping.** Ipakita ang term, category, slot
   (WW 1–10, PT 1–10, EX ST1/ST2/TE), at HPS. Server ang naglalaan at
   nagla-lock ng slot; hindi maaaring i-overwrite ang slot ng ibang item.
6. **I-preview ang student view.** Kumpirmahin ang title, instructions, mode,
   deadline, recipients, allowed submissions, points, at slot bago magpatuloy.
7. **Save draft o publish.** Draft ay teacher-only. Sa publish, persistent
   backend ang magsasagawa ng kinakailangang task, roster, slot, at assessment
   records. Kung may hakbang na pumalya, huwag mag-publish ng bahagyang valid
   na task; ibalik ang malinaw na error at panatilihin ang form data.
8. **Kumpirmahin ang publish.** Ipakita lamang ang success pagkatapos
   ma-confirm ang transaction. Ang student visibility ay magsisimula sa
   configured availability time, hindi sa hindi pa nakumpirmang client state.

### B. Student discovery at pagpasok sa task

1. Student login/session ay beripikado sa server.
2. Student Classwork list ay nilo-load mula sa backend batay sa sariling
   active/preserved assignment roster, hindi sa buong subject list o mock data.
3. Ipakita ang category, subject/section, title, due date o testing window,
   mode, status, HPS kung angkop, at malinaw na next action.
4. Itago ang draft, ibang section, answer key, private teacher notes, at unreleased
   scores.
5. Kapag nag-open ang student, backend ulit ang magbe-verify ng enrollment,
   availability, status, at access. Ang lumang link o forged ID ay hindi dapat
   makapagbukas ng ibang student's item.
6. Kung offline o pumalya ang load, ipakita ang cached record bilang stale kung
   mayroon, at markahan itong hindi kumpirmadong kasalukuyan. Huwag magpakita
   ng submit/take control na hindi makakapag-save nang durable.

### C. Completion, review, grading, at result

1. Student completes the permitted action for the selected mode.
2. Backend records the submission/attempt once and returns a durable receipt or
   explicit failure.
3. Teacher workspace shows per-student status from persistent records.
4. Teacher reviews, scores, and adds feedback; all score changes are validated
   against HPS and written with actor, timestamp, and audit history.
5. Score remains unreleased until the teacher explicitly releases it or a
   separately approved release rule is configured.
6. On release, Gradebook reads the authoritative score for the exact student,
   item, offering, term, category, and reserved column. Student/authorized
   parent sees only the released result.
7. If a save/release/sync fails, show pending/error state and reconciliation
   action. Do not lose history or claim that Gradebook and Classwork agree
   until their authoritative records are reconciled.

## 4. PT — Performance Task flow

### 4.1 Teacher creates and publishes PT

Teacher configures:

- Owned offering, taught term, recipients, title, description/instructions,
  HPS, deadline (optional only if policy allows), and completion mode.
- Optional rubric/criteria. The sum of criterion maximum points must exactly
  equal the task HPS. Each criterion score must be within its maximum.
- For online mode: allowed response type (text, file, or both), file limits and
  accepted types, late policy, and whether resubmission is allowed.
- For manual mode: clear message that the output is completed/handed in
  outside ClassRealm and the teacher will record the result; no student upload
  control is shown.
- A stable free PT Gradebook slot within the selected offering and term.

Before publish, the preview confirms all configured details. Backend rechecks
teacher ownership, active offering, term eligibility, recipients, slot
availability, rubric totals, and HPS. Concurrent publishes for the same slot
must be serialized or rejected safely; last-write-wins must never overwrite
another PT.

### 4.2 Student completes PT online

1. Open the published task and review instructions, rubric, due date, allowed
   file/text types, late rule, and resubmission allowance.
2. Draft response can be edited locally, but it is not called submitted until
   server acknowledgement.
3. Validate all selected files and response constraints before upload. Upload
   only to private storage using a scoped authorization; do not expose public
   permanent URLs.
4. Show an upload progress state, prevent accidental duplicate taps, and allow
   safe retry. A retry with the same request key must not create a duplicate
   submission.
5. Submit confirmation summarizes the response/files. On success show receipt,
   submission timestamp, and status (`submitted` or `late`); on failure retain
   the draft and show a recoverable error.
6. If resubmission is permitted, create a new immutable submission version,
   identify which version is current, and retain prior versions for audit. If
   not permitted or the deadline has passed, block submission with the exact
   applicable policy, not a generic silent failure.
7. Student can see their own submission status and released feedback, never
   another student's output.

### 4.3 Student completes PT in person/manual

1. Student sees instructions, due date, rubric (if shared), and “Complete in
   person; teacher records the result.”
2. Student completes and hands in/presents the work outside the app.
3. No digital submit button, upload receipt, or fabricated submitted timestamp
   is shown.
4. Until teacher records a result, status remains `assigned` / `not yet
   recorded`; it is not assumed to be zero or missing.
5. After teacher records and releases status/score, student sees the recorded
   result and feedback.

### 4.4 Teacher reviews and grades PT

- Online: inspect the selected submission version and files; grade by rubric or
  total points; add feedback; optionally return for allowed revision.
- Manual: select an enrolled student and enter status, rubric points/score,
  feedback, and optional private evidence note. A bulk-entry grid is allowed,
  but each cell is independently validated and the final save summary names
  all saved/failed rows.
- Supported states must distinguish `assigned`, `not submitted`, `submitted`,
  `late`, `not yet graded`, `graded`, `returned`, `absent`, `excused`, and
  `released`, as applicable. Null score is not zero.
- Save feedback/score first; release is a deliberate, separately confirmed
  teacher action. Corrections preserve the prior value and audit details.

## 5. WW — Written Work flow

WW uses the same access, roster, mode, submission, feedback, status, and grade
rules as PT, but uses its own WW slot and category weight.

### 5.1 Teacher creates WW activity/assignment

1. Choose an active offering and term.
2. Choose activity or assignment type, then online or manual completion mode.
3. Add title, instructions, HPS, availability/deadline, late/resubmit rules,
   optional teacher attachment, recipients, and submission settings.
4. Reserve a free WW slot (`WW 1`–`WW 10`) for this exact offering and term.
5. Preview and publish through the same atomic, backend-confirmed lifecycle.

### 5.2 Student performs WW

- **Online:** open instructions/attachment, complete in app, submit text/file
  according to allowed type, receive timestamped receipt, and see status.
- **Manual:** perform worksheet, paper activity, recitation, board work, or
  other in-person task outside ClassRealm. There is no upload or submission
  receipt; teacher records completion and result.
- Late, absent, excused, returned, and not-yet-graded states remain distinct.
- No score becomes visible until released.

### 5.3 Teacher grades WW

Teacher reviews digital responses or records in-person result, validates score
against HPS, saves feedback/audit history, then explicitly releases. Only the
matching WW slot is updated; PT and EX slots are unaffected.

## 6. Quiz flow — digital attempt and manual alternative

### 6.1 Teacher authors, validates, and publishes

1. Choose an owned offering, term, recipients, and an available eligible
   Gradebook mapping according to finalized policy. A quiz must not consume an
   arbitrary or occupied slot.
2. Create questions manually or use a backend-secured generation service from
   an approved source. Generated questions are drafts only.
3. Review every question, answer key, points, and section before publish.
   Teacher must be able to edit/remove questions and fix invalid keys.
4. Configure quiz availability/testing window, duration, attempt policy,
   response behavior, randomization, and monitoring notice.
5. Confirm preview, HPS, slot, and roster. Backend validates all question
   counts/points and ownership before publishing.

### 6.2 Student starts and takes quiz

1. Student sees the quiz only during its availability window and only if on its
   recipient roster.
2. Before starting, show rules: duration, allowed attempts, submission
   behavior, monitoring signals collected, and what happens if connectivity is
   lost.
3. Backend creates one attempt with unique attempt ID and attempt number;
   server time is authoritative for start/end.
4. Deliver only the questions and options needed for the attempt. Never send
   answer keys or teacher-only fields to the student client.
5. Persist answers incrementally with idempotent requests and visible saved /
   saving / offline states. An unsaved answer must not appear confirmed.
6. If randomized, store the attempt's question order and option order on the
   server so refresh/reconnect does not reshuffle the same attempt.
7. Student submits explicitly or the server closes the attempt when the
   configured time ends. Confirmation lists unanswered items. A network retry
   cannot create an additional attempt or submit twice.
8. Show a receipt and submission status. Do not reveal correct answers or
   score until the assessment's configured release state.

### 6.3 Teacher monitors and grades quiz

- Monitor roster state: `not_started`, `in_progress`, `submitted`,
  `connection_lost`, `teacher_intervention_pending`, `kicked`, or `closed`,
  with last server-confirmed activity time.
- Objective question scoring is server-validated using protected keys.
- Identification/free-response items may require teacher review. Display
  provisional vs final score clearly.
- Teacher may inspect an attempt's answer timeline and supported monitoring
  events, but events are signals for review, not conclusive proof of cheating.
- Run item analysis only on valid submitted attempts and report the sample
  count/denominator for every statistic.
- Teacher releases a final score deliberately. The released score maps to the
  quiz's confirmed WW or EX Gradebook mapping; it cannot silently shift slots.

### 6.4 Quiz manual/in-person alternative

For a paper/in-person quiz, teacher records each student's status and score
through the manual roster flow. There is no digital attempt, response log,
randomization, item-level response analysis, or anti-cheating event claim.
Question-level analysis is available only if the teacher records/imports
validated per-question responses through a separately defined real workflow.
Do not fabricate responses to make item analysis appear complete.

## 7. EX flow — ST1, ST2, and TE

ST1, ST2, and TE are separate examination slots, not interchangeable labels or
reusable columns. The exact school-approved meanings and term association must
be configured and verified before implementation.

### 7.1 Teacher creates the exam

1. Choose the owned offering and valid term.
2. Confirm that the subject has an EX component. If `ex_weight == 0`, disable
   digital and manual EX creation and explain the policy; do not reserve an EX
   slot.
3. Select exactly one available slot: ST1, ST2, or TE. Reject duplicate
   occupancy for the same offering/term/slot.
4. Create and review questions/answer keys; configure exam date, same-day
   start/end window, duration, allowed attempt policy, randomization, and
   monitoring notice.
5. Preview recipient roster, HPS, policies, and the exact EX slot.
6. Publish only after backend confirms ownership, eligibility, slot capacity,
   valid schedule, and complete assessment data.

### 7.2 Student takes digital ST1/ST2/TE

1. Student sees only the exam assigned to them and sees the exam rules before
   entering.
2. At start, server confirms identity, recipient assignment, schedule window,
   attempt eligibility, and current exam status.
3. A durable attempt begins with server timestamp and immutable question
   ordering. Answers are saved as the student proceeds.
4. Student can reconnect to the same in-progress attempt under the configured
   recovery policy. Do not create an automatic retake because a page refreshed
   or app resumed.
5. Student submits or the server closes the attempt at the configured end.
   The exact finalization state is persisted before confirmation is shown.
6. Teacher grades any manual-response items. The score remains hidden until
   release.

### 7.3 Teacher records paper exam

For a paper exam, teacher chooses manual mode, records each student's
attendance/participation state and score, optionally enters item-level
responses if item analysis is required, and releases after checking the entry
summary. The system must label the record as manual; it must not show a digital
attempt or monitoring evidence.

### 7.4 EX result to Gradebook

On release, update only the selected ST1/ST2/TE cell for the exact student,
offering, and term. Preserve null, zero, absent, and excused semantics. Recheck
the official grading/weighting configuration and ensure score/HPS and aggregate
results reconcile with the authoritative grade record.

## 8. Anti-cheating and teacher-controlled interventions

### 8.1 Realistic monitoring contract

Monitoring supports assessment integrity, but it cannot guarantee that all
external assistance is detected or prevent every form of cheating.

- Web can record supported visibility/focus changes, fullscreen exit where
  supported, page lifecycle events, network interruptions, and timestamps.
- Native apps can record supported app lifecycle/background events and
  fullscreen changes where the platform permits.
- These events can count focus-loss episodes and elapsed time away from the
  assessment, with debounce/threshold rules to avoid duplicate noise.
- The system must not claim that it identified the destination app/site.
- Circle to Search, operating-system overlays, another device, camera/phone
  use, accessibility tools, or platform-specific gestures cannot reliably be
  detected by a normal Flutter web page. Circle to Search in particular must
  not be described as detected unless a separately validated, platform-approved
  signal actually exists. Never claim “100% anti-cheat.”
- Browser refresh, app interruption, permission dialogs, incoming calls, and
  network loss can create events without dishonest intent. Store context and
  let the teacher review; do not label an event itself as proof of misconduct.
- Monitoring notice must explain the signals collected and be shown before
  attempt start. Collect only the minimum event data needed, protect it by
  role, and apply an approved retention policy.

### 8.2 Event recording

For each supported event, store attempt ID, student ID, event type, server
receipt time, client occurrence time if provided, duration when measurable,
source platform, and whether the event was accepted/de-duplicated. Events must
be append-only or auditable; clients cannot delete or rewrite prior events.

Examples of supported event names include `tab_hidden`, `window_blur`,
`fullscreen_exit`, `app_backgrounded`, `connection_lost`, and
`connection_restored`. Use a short debounce so simultaneous blur/visibility
notifications do not count as multiple switches for one transition. Display
raw counts and timing to teacher; avoid an unexplained “cheating score.”

### 8.3 No automatic kick, retake, or score penalty

- **No auto-kick.** A tab switch, blur, fullscreen exit, refresh, or signal
  threshold never automatically kicks a student.
- **No auto-retake.** Connectivity loss or a client event never silently resets
  an attempt. The attempt follows its configured recovery policy until a
  teacher acts or a documented server-side timer closes it.
- **No automatic zero solely from monitoring.** A focus event is not proof.
  A zero, invalidation, or misconduct outcome requires an explicit,
  authorized, audited teacher decision under school policy.
- Student's in-progress work remains preserved when possible while the teacher
  reviews the event.

### 8.4 Teacher retake action

1. Teacher opens the specific student's attempt and reviews the event timeline
   and current saved answers.
2. Teacher chooses **Allow retake**. Before mutation, show a confirmation modal
   stating student, assessment, reason, current attempt state, and exact effect.
3. Modal offers **Cancel** and a clearly labeled final action. No action occurs
   if closed/cancelled.
4. On confirmation, backend checks teacher ownership and current attempt
   version. Preserve the original attempt as `superseded`/`retake_granted`;
   do not erase answers, logs, score, or audit history.
5. Create an authorized new attempt (or unlock according to the finalized
   attempt model), link it to the prior attempt, record actor/time/reason, and
   notify the student. Only one retake grant can be consumed; duplicate
   confirmations are idempotent.
6. If the backend fails, keep the old attempt unchanged and show an error.

### 8.5 Teacher kick/terminate action

1. Teacher reviews the exact attempt and selects **End attempt / Kick**.
2. A prominent confirmation modal names the student and assessment, summarizes
   the evidence, asks for a required reason, and states the configured
   consequence (e.g., lock current attempt; any score consequence must follow
   school-approved policy and be explicit). **Cancel** is the safe default.
3. Only after explicit confirmation does the backend atomically close/lock the
   attempt, record the teacher actor, reason, timestamp, evidence references,
   and outcome, and broadcast the result to the student's active session.
4. The student sees a neutral explanation that the attempt was ended by the
   teacher and how to contact the teacher; do not expose private teacher notes.
5. Preserve all answers and events. Never delete evidence or auto-create a
   retake. A retake afterward is a separate teacher action with its own
   confirmation.
6. If realtime broadcast is unavailable, persist the termination first and
   force the client to re-check authoritative attempt status; do not depend on
   a websocket message as the only lock.
7. Teacher action can be reviewed/audited. A client cannot kick a student by
   sending a forged realtime event.

## 9. Item analysis

Item analysis is generated only from actual, persisted item-level responses
with a known answer key and a clearly defined scoring rule.

- Show the number of submitted/graded attempts and item-level denominator.
- Difficulty index: correct responses divided by eligible responses. Exclude
  unanswered/excused responses only according to the approved scoring policy
  and disclose the denominator.
- Discrimination index and upper/lower group definition must use a documented
  cohort and tie-handling policy. Suppress or label results for a cohort too
  small to interpret reliably.
- Distractor distribution uses the actual saved option selected per student.
  Flag unselected distractors; do not infer a misconception as fact.
- Identification typo/alternate-answer review is a teacher suggestion, not
  automatic credit. Teacher approves any accepted answer/score adjustment.
- If answer key changes after attempts, require a controlled regrade preview,
  display affected students and score deltas, and persist the old/new key and
  score audit.
- Recalculate and reconcile item statistics after approved regrade.
- Manual/paper assessments need actual item response data before item-level
  statistics can be shown. If unavailable, clearly state “No item-level
  responses recorded” rather than showing invented charts.
- Exported reports contain only authorized class data and identify assessment,
  offering, term, cohort size, generation time, and analysis version.

## 10. Gradebook and result rules

- Store each classwork item's category, term, HPS, and reserved slot before
  publish; mapping is stable for the item's lifetime.
- A score record is unique to the exact student and classwork item. Gradebook
  is a derived view or reconciled cache, never a separate conflicting score
  authority.
- Validate `0 <= score <= HPS`; preserve decimals only if the configured
  grading policy permits them.
- `null` means not yet scored, not zero. Keep explicit states for absent,
  excused, not submitted, not graded, graded, returned, and released.
- Changes after release require a teacher confirmation/reason as configured,
  preserve old and new values, and notify/release the corrected result
  deliberately.
- A transient Gradebook sync failure leaves a retryable reconciliation state.
  Never double-count an item or silently select a different slot.
- Archiving hides an item from active work but preserves assignments,
  submissions, attempts, scores, logs, and released historical results.
- Do not hard-delete records with attempts, submissions, grades, or released
  results through normal UI.

## 11. Error and unexpected scenario matrix

| Scenario | Required system behavior | Teacher/student-visible result |
|---|---|---|
| Teacher loses network while authoring | Do not claim server save/publish. Preserve local form draft if possible; retry with idempotency key. | “Not published — connection failed.” Draft clearly marked local/pending if applicable. |
| Publish succeeds on server but response is lost | Re-query by request/idempotency ID; do not insert a second item or reserve another slot. | Resolve to published only after server confirms existing record. |
| Two teachers or two tabs select the same final slot | Backend transaction/unique constraint arbitrates; one succeeds, other receives conflict. | Losing teacher keeps form values and selects a new free slot. |
| Student refreshes during an online attempt | Restore same server attempt, saved answers, remaining server-calculated time, and question order. | No automatic retake; clearly show reconnecting/restored status. |
| Student double-taps submit or retries a timed-out request | Idempotent submission response returns the same receipt. | One submission/attempt only. |
| Student loses connection while answering | Keep last server-acknowledged answers, mark unsaved work clearly, reconnect to same attempt under policy. | Never claim unsaved answers were received. |
| Student reconnects after exam window | Apply published recovery/close policy; do not silently start another attempt. | Explain whether saved work was finalized or teacher review is required. |
| Student opens someone else's task/attempt ID | Backend denies access and logs authorization failure without exposing existence/details. | Generic unavailable/not authorized state. |
| Student changes offering after task publish | Keep historical recipient and grades in original offering; apply approved roster policy to future work. | No silent migration or duplicate grade. |
| New enrollment after publication | Apply explicit snapshot/dynamic policy; add recipient only via auditable path if allowed. | Teacher sees roster change/count. |
| File upload succeeds but submission save fails | Keep object private and clean up/reconcile orphan safely; do not create a broken submission. | Submission remains unconfirmed; retry available. |
| Teacher grades some bulk rows then network fails | Persist confirmed rows only; report each row's authoritative status and safely retry remaining rows. | No blanket “all saved” message. |
| Invalid score exceeds HPS or rubric points mismatch | Reject row/transaction before score commit; preserve prior valid score. | Inline field-specific error and affected student/criterion. |
| Teacher's browser refreshes during monitoring | Reload persisted roster/events/attempt status; no state is reset. | Teacher can continue monitoring from current server state. |
| Blur event caused by OS notification or accessibility overlay | Record supported signal only; no automatic punishment. | Teacher reviews context; student is not auto-kicked or reset. |
| Circle to Search or another external aid is used | Do not claim detection absent a verified platform signal; normal web event monitoring may only record focus/visibility changes. | Report only observable events; teacher decides under policy. |
| Realtime connection drops during teacher kick | Persist authorized server action first; client polls/rechecks authoritative status. | No duplicate action; student is locked after next status check. |
| Teacher cancels kick/retake confirmation | No data change, no event-outcome mutation, no notification. | Return to monitor unchanged. |
| Teacher confirms kick, then response times out | Query authoritative attempt status; idempotent action prevents repeat side effects. | Show final state only after server confirmation. |
| Item key is corrected after grading | Preview affected responses/score changes, require approval, audit and regrade consistently. | Student sees corrected score only after deliberate re-release. |
| No item responses exist for a paper test | Do not calculate distractor/difficulty charts from aggregate score alone. | State that item analysis requires item-level responses. |
| Student is absent/excused | Store explicit state, do not convert to zero unless approved grading policy explicitly requires a separate action. | Student/teacher sees accurate status. |
| Gradebook update fails after score release | Keep authoritative grade and reconciliation status; retry without duplicate/slot drift. | Teacher sees sync warning; student result visibility follows approved release policy. |
| Backend unavailable at login/list load | Show retry/error and only clearly labeled stale cached records if available. | No mock roster, fake task, or fabricated empty-success state. |

## 12. Teacher and student screens/statuses

### Teacher Classwork list

Each item should show category, title, offering/section, term, mode, deadline
or exam window, slot, draft/published/closed/archived state, recipient count,
submission/attempt count, ungraded count, and sync/error indicator where
applicable.

### Teacher item workspace

Tabs/filters should separate:

- Overview and configuration
- Assigned roster
- Submitted / in progress
- Not submitted / absent / excused
- Needs grading / returned
- Released results
- Proctor events for digital assessments
- Item analysis for assessments with enough real responses

Do not combine students from separate offerings in one roster action.

### Student Classwork list/detail

Show only assigned, available content and the student's own progress. Provide a
clear mode-specific action:

- Online PT/WW: `Open` / `Continue` / `Submit` / `View receipt`
- Manual PT/WW: `View instructions` and status recorded by teacher
- Digital Quiz/EX: `Start` / `Continue attempt` / `View submission status`
- Manual Quiz/EX: `View instructions` / released score when available

Show score/feedback only after release and never show teacher-only notes or
answer keys before the configured reveal.

## 13. Implementation order and Student-side verification milestone

Implementation is sequential; do not build every category against mocks and
declare integration complete.

### Phase 1 — PT

1. Finalize schema/authorization/roster/slot requirements.
2. Implement backend-backed teacher create/publish and online/manual student
   completion.
3. Implement teacher review/manual grading/release and authoritative Gradebook
   mapping.
4. Verify complete PT flow with real test accounts and persistent test
   records.

### Phase 2 — WW

1. Reuse proven PT ownership, mode, roster, grading, and release rules.
2. Implement WW-specific activity/assignment settings and WW column mapping.
3. Verify online/manual WW flows, including late/resubmit behavior if enabled.

### Phase 3 — Quiz

1. Implement persistent authoring, secure answer-key handling, attempts,
   responses, time window, recovery, teacher review, and controlled monitoring.
2. Implement retake/kick only with explicit confirmation, trusted authorization,
   audit trail, and preserved prior attempt history.
3. Implement item analysis only from actual item-level responses.
4. Verify digital and manual quiz paths independently.

### Phase 4 — ST1, ST2, TE

1. Implement each reserved EX slot with offering/term/weight validation.
2. Reuse the verified assessment attempt and monitoring primitives.
3. Verify digital and paper/manual workflows and EX Gradebook reconciliation.

### Student-side end-to-end acceptance gate

After each phase's teacher workflow is complete, test its student flow before
starting the next phase. Final Student-side review covers all categories:

- Use separate real test identities/roles for admin/teacher/student/parent where
  applicable; ensure accounts and records belong to the intended test Supabase
  and Firebase projects.
- Seed only explicit test fixtures in an isolated test environment. The running
  app path itself must load from configured backend records; no production
  `MockDatabase` fallback is permitted.
- Publish each item as teacher and verify the server roster, offering, term,
  slot, and visibility.
- Sign in as an enrolled student and verify only their assigned item appears.
- Sign in as a student from another offering and verify no item, attachment,
  answer key, roster, or attempt is accessible.
- Complete online submission/attempt, refresh/reopen, and confirm durable
  receipt, saved state, and no duplicate records.
- Complete manual items and verify student cannot upload/submit in that mode;
  teacher can record status/score and student sees it only after release.
- Verify teacher grading, correction audit, explicit result release,
  notification state, and Gradebook cell all refer to the same item/student/
  offering/term/category/slot.
- Verify quiz/exam events using only supported browser/device signals. Include
  ordinary refresh, tab/window backgrounding, app backgrounding where
  available, connection loss, and teacher monitor reconnect.
- Verify no event threshold auto-kicks, auto-resets, or assigns zero.
- Verify teacher cancel leaves the attempt unchanged; confirmed retake/kick
  persists exactly once and preserves the original evidence/history.
- Verify item analysis against a known response fixture and show “insufficient
  data” or “no item responses” rather than misleading statistics when
  appropriate.
- Verify no mock roster, mock task, sample score, or success-shaped fallback
  appears after a backend error.
- Exercise permissions and behavior on Chrome and supported mobile platforms;
  document platform-specific monitoring limitations instead of implying
  identical detection.

**Completion definition:** A phase is complete only when its teacher-to-student
journey, failure cases, authorization, persisted records, grade release, and
Gradebook mapping pass the phase's acceptance tests. The Student-side milestone
is complete only when every applicable acceptance gate above passes using the
real configured backend in an isolated test environment and no mock data is
used by the tested feature path.

## 14. Decisions required before implementation

Resolve and document these decisions before the affected code/schema is built:

1. Exact recipient policy for new enrollment, withdrawal, archive, and section
   transfer after publication.
2. Approved grading treatment for absent, excused, late, not submitted, kicked,
   and teacher-invalidated attempts.
3. Resubmission/attempt count, timer recovery, and make-up/retake policies per
   category.
4. Whether quiz scores map to WW or EX, and how quiz items consume/reserve a
   Gradebook slot without conflicting with ST1/ST2/TE.
5. Exact ST1/ST2/TE meanings, term association, and school-approved slot
   policy.
6. Assessment monitoring notice, data retention, audit access, and who may
   decide/appeal a kick or score consequence.
7. Supported platform signals and browser/mobile limitations. Circle to Search
   must remain “not reliably detectable” unless verified platform capability
   and applicable policy are established.
8. Whether manual paper assessments will capture per-item student responses
   for item analysis or only total scores.
9. Final database source of truth for grade records, submission versions,
   attempt history, and Gradebook-derived cache; confirm schema against actual
   migrations/deployed project before any migration is applied.

No implementation should infer these unresolved policies from a mock screen or
sample data. Any future fixture must be test-only, visibly scoped to an
isolated test environment, and never act as a fallback for real users.
