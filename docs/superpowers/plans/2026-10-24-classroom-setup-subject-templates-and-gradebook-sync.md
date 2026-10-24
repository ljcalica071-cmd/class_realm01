# Classroom Setup Subject Templates & Dynamic Gradebook Engine Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans` along with `ui-ux-pro-max` and `task-skill-router` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement the complete Strengthened Senior High School (SSHS) DepEd Order No. 015, s. 2026 Subject Template Catalog with Search and Category Filtering in Classroom Setup, support Custom/Manual Entry with dynamic grading weights, and synchronize the Gradebook so that term tabs, auto-grading, and Final Grades view dynamically adapt to each subject's specific grading weights and number of terms taught.

**Architecture:**
1. **Master Subject Catalog (`teacher_classroom_setup_templates.dart`):** Populate all 61 official SSHS subjects across `SSHS - CORE`, `SSHS - ACADEMIC`, and `SSHS - TECH-PRO` with exact DO 15, s. 2026 component weights (`WW / PT / EX`), term counts (`1 Term` or `3 Terms`), and sub-test weights (`ST1 / ST2 / TE`).
2. **High-Polish Template Picker Modal (`teacher_classroom_setup_tab.dart`):** Redesign the template dialog using `ui-ux-pro-max` guidelines: real-time search bar, category filter tabs (`ALL CATEGORIES`, `SSHS - CORE`, `SSHS - ACADEMIC`, `SSHS - TECH-PRO`), cluster section grouping, prominent "Custom / Manual Entry" action card, and informative weight/term badges.
3. **Database & Manual Entry Weight Persistence (`SubjectRepository`):** Ensure both preset templates and manual entries reliably save `ww_weight`, `pt_weight`, `ex_weight`, `terms_taught`, `term_block`, `st1_weight`, `st2_weight`, and `te_weight` into Supabase `subject_offerings`.
4. **Dynamic Term-Isolated Gradebook (`teacher_gradebook_tab.dart`):** Dynamically hide inapplicable terms based on `_termsTaught` and `_termBlock` (e.g. 1-term subjects only show their single taught term tab + Final Grades; 2-term subjects show their two taught terms + Final Grades), dynamically compute Initial Grade with or without exams (`ex_weight == 0`), and dynamically render only the taught term columns in the Final Grades summary table.

**Tech Stack:** Flutter (Dart), Supabase PostgreSQL, Drift SQLite, `DepEdGradingEngine`.

---

## Global Constraints
- Strictly match the subjects and clusters specified by the user from `TEMPLATE - E-Class Record.xlsx`.
- Categories must be: `SSHS - CORE`, `SSHS - ACADEMIC`, `SSHS - TECH-PRO`.
- For Research and Design & Innovation: `WW 40%`, `PT 60%`, `EX 0%` (No Examination).
- For Field Experience / Apprenticeship: `WW 15%`, `PT 70%`, `EX 15%` (`TE 100%`).
- For Core: `WW 20%`, `PT 50%`, `EX 30%`, `3 Terms (Full Year)`.
- For Tech-Pro: `WW 15%`, `PT 65%`, `EX 20%`, `1 Term`.
- 1-Term subjects must hide non-applicable terms in Gradebook tabs and Final Grades table.
- Preserve backward-compatibility; no breaking changes to existing database records.

---

## Task Breakdown

### Task 1: Complete Master Subject Catalog (`lib/features/teacher/sub_features/setup/widgets/teacher_classroom_setup_templates.dart`)
- [ ] Define the complete list of 61 subjects:
  - **`SSHS - CORE`** (Cluster: `CORE`):
    - Effective Communication (WW 20, PT 50, EX 30, Terms: 3)
    - General Mathematics (WW 20, PT 50, EX 30, Terms: 3)
    - General Science (WW 20, PT 50, EX 30, Terms: 3)
    - Life and Career Skills (WW 20, PT 50, EX 30, Terms: 3)
    - Mabisang Komunikasyon (WW 20, PT 50, EX 30, Terms: 3)
    - Pag-aaral ng Kasaysayan at Lipunang Pilipino (WW 20, PT 50, EX 30, Terms: 3)
  - **`SSHS - ACADEMIC`**:
    - Cluster `BUSINESS AND ENTREPRENEURSHIP` (5 subjects: Business 1, Business 2, Contemporary Marketing, Entrepreneurship, Intro to Org & Mgmt - WW 20, PT 50, EX 30, Terms: 1)
    - Cluster `ARTS, SOCIAL SCIENCES, AND HUMANITIES` (24 subjects: Art Criticism, Contemporary Lit 1 & 2, Creative Comp 1 & 2, Creative Industries series, Filipino series, Philo, Leadership in Arts, Malikhaing Pagsulat, Philippine Governance, Social Sciences)
    - Cluster `FIELD EXPERIENCE` (3 subjects: Design and Innovation [WW 40, PT 60, EX 0], Research 1 [WW 40, PT 60, EX 0], Research 2 [WW 40, PT 60, EX 0])
  - **`SSHS - TECH-PRO`**:
    - Cluster `AESTHETIC, WELLNESS, AND HUMAN CARE` (4 subjects: Aesthetic Services, Caregiving Adult & Child, Hairdressing - WW 15, PT 65, EX 20)
    - Cluster `AGRI-FISHERY BUSINESS AND FOOD INNOVATION` (9 subjects: Agricultural Crops, Agro-entrepreneurship, Aquaculture, Fish Capture, Food Processing, Organic Agri, Poultry, Ruminants, Swine - WW 15, PT 65, EX 20)
    - Cluster `ICT SUPPORT AND COMPUTER PROGRAMMING TECHNOLOGIES` (6 subjects: Broadband Installation, Computer Programming .Net, Java, Oracle, CSS, Contact Center - WW 15, PT 65, EX 20)
    - Cluster `INDUSTRIAL TECHNOLOGIES` (4 subjects: Commercial Air-Con, Electrical Installation, Electronic Products Assembly, Photovoltaic Systems - WW 15, PT 65, EX 20)
- [ ] Add helper getters in `SubjectTemplate`:
  - `isNoExam`: returns `ex == 0`
  - `weightSummary`: e.g. `'WW 20% · PT 50% · EX 30%'` or `'WW 40% · PT 60% · NO EXAM'`

---

### Task 2: Redesign Template Picker Modal with Search & Category Filtering (`teacher_classroom_setup_tab.dart`)
- [ ] Implement `_showTemplateModal` with stateful search and filtering:
  - Add search input field with icon and clear action.
  - Add category filter tabs: `ALL CATEGORIES`, `SSHS - CORE`, `SSHS - ACADEMIC`, `SSHS - TECH-PRO`.
  - Filter list in real-time by search query (matching name or cluster) and selected category.
- [ ] Style "Custom / Manual Entry" as a prominent hero action card at the top.
- [ ] Group filtered subjects by Cluster with clean cluster section headers.
- [ ] Design subject list cards with:
  - Bold subject name
  - Cluster badge
  - Component weights pill (`WW / PT / EX` or `NO EXAM` badge)
  - Terms taught badge (`3 Terms (Full Year)` vs `1 Term`)
  - Smooth hover animations and rounded surface cards.
- [ ] Handle empty search state with clear feedback and button to use the search text as custom subject name.

---

### Task 3: Gradebook Multi-Term & Weight Engine Synchronization (`teacher_gradebook_tab.dart`)
- [ ] **Dynamic Term Tabs (`_buildTermTabs`):**
  - Read `_activeTerms` from `_termsTaught` and `_termBlock`.
  - If `_termsTaught == 1`: Only render the 1 active term tab (e.g. `Term 1` if `FIRST TERM`, `Term 2` if `SECOND TERM`, `Term 3` if `THIRD TERM`) + `FINAL GRADES`.
  - If `_termsTaught == 2`: Only render the 2 active term tabs + `FINAL GRADES`.
  - If `_termsTaught == 3`: Render all 3 term tabs + `FINAL GRADES`.
  - Ensure `_selectedTerm` automatically points to the first active term when switching subjects.
- [ ] **Dynamic Final Grades View (`_buildFinalGradesView`):**
  - Dynamically generate the Term Grade sub-columns to match ONLY the active terms (e.g. 1 term column for 1-term subjects; 2 term columns for 2-term subjects; 3 term columns for 3-term subjects).
  - Calculate column widths dynamically based on active terms count so table looks balanced and expansive.
  - Dynamically render row cells and empty placeholder rows for active terms only.
- [ ] **Zero-Exam & Custom Weight Auto-Grading:**
  - When `ex_weight == 0` (e.g. Research, Design & Innovation), display `EXAMINATIONS (EXs) (None / 0%)` and verify `DepEdGradingEngine.computeInitialGrade` calculates `round2(wwWs + ptWs)` without requiring exam scores.
  - Confirm custom manual entry weights (e.g., 30/40/30) dynamically dictate `_componentMetrics` and `_examMetrics` calculations instead of being locked to 20/50/30.

---

### Task 4: Verification & Manual Testing
- [ ] Test template picker dialog:
  - Search by subject name (e.g. "Computer Programming", "Research", "Accounting").
  - Filter by `SSHS - CORE`, `SSHS - ACADEMIC`, `SSHS - TECH-PRO`, and `ALL CATEGORIES`.
  - Select "Custom / Manual Entry".
  - Select a subject with no exam (e.g. "Research 1") and verify weights populate as WW 40, PT 60, EX 0.
- [ ] Test Gradebook:
  - Select a 1-Term subject: verify only 1 term tab is shown + Final Grades.
  - Open Final Grades view: verify only 1 term column is shown + Final Grade.
  - Select a 3-Term Core subject: verify all 3 term tabs and all 3 term columns are shown.
  - Verify auto-grading computes accurately.
