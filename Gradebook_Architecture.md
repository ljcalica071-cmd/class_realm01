# ClassRealm — Dynamic Gradebook & Assessment Engine Architecture

> **Document Type:** Feature Architecture & Logic Strategy
> **Reference File:** `TEMPLATE-SSHS-E-Class-Record-SY-2026-2027.xlsx`
> **Target Users:** Teachers
> **Date Created:** 2026-09-27

---

## 1. Feature Placement & Translation from Excel to ClassRealm
Ang Excel template na ginagamit ng mga teacher ay may anim (6) na pangunahing sheets. Sa ClassRealm system, hindi na kailangan ng literal na "sheets" dahil idedesign natin ito para maging integrated at automated. Eto ang mapping mula sa Excel papunta sa ClassRealm UI:

| Excel Template Sheet | ClassRealm System Feature | Paano ito gagana sa System? |
| :--- | :--- | :--- |
| **1. INSTRUCTIONS** | **Dedicated Instructions View** | Ang system ay magkakaroon ng dedicated "Instructions" tab/modal na kaparehas ng sa Excel para mabasa ng teacher kung paano eksaktong gumagana ang gradebook, lalo na kung paano i-configure ang Old Curriculum. |
| **2. INPUT DATA** | **Academic Setup & Student Roster** | Ang *School Info*, *Teacher Info*, at *Learners' Names (Male/Female)* ay **automatic nang mapupunan** papunta sa Term 1, 2, 3 at Final Grades! Wala nang manual typing ng pangalan. Ang tanging ise-setup ni teacher dito ay ang **Grade Level at Subject Area Info (Category -> Cluster -> Subject)** gamit ang dropdowns. |
| **3. Term 1** | **Gradebook Tab (Filtered to Term 1)** | Isang matrix view kung saan nag-i-input ng raw scores (WW, PT, EX). |
| **4. Term 2** | **Gradebook Tab (Filtered to Term 2)** | Same view, papalitan lang ang filter dropdown sa taas to "Term 2". |
| **5. Term 3** | **Gradebook Tab (Filtered to Term 3)** | Same view, papalitan lang ang filter dropdown sa taas to "Term 3". |
| **6. FINAL GRADES** | **Final Grades / Report Card View** | Isang read-only summary table na nagko-compute ng average ng Term 1, 2, at 3 para makuha ang Final Grade per subject. |

---

## 2. Dynamic Grading Logic (DepEd Order 15, s. 2026 Standard)

Ang system ay sumusunod sa pinakabagong **DepEd Order No. 015, s. 2026** para sa **Strengthened Senior High School (SSHS)**. Hindi naka-hardcode ang mga percentage sa iisang formula lamang dahil bawat Subject Category at Cluster ay may nakatalagang opisyal na weight preset mula sa `HELPER` sheet ng DepEd ECR:

### A. Opisyal na Component Weights Presets (WW / PT / EX)

| Subject Category / Cluster | Written / Oral Works (WWs) | Product / Performance Tasks (PTs) | Examinations (EXs) | Halimbawa ng mga Asignatura |
| :--- | :---: | :---: | :---: | :--- |
| **SSHS - CORE** | **20%** | **50%** | **30%** | Effective Communication, General Mathematics, General Science, etc. |
| **Academic Electives (ABM / HUMSS / STEM)** | **20%** | **50%** | **30%** | Business 2: Finance and Income Tax, Accountancy, Economics |
| **TechPro Electives (TVL / ICT)** | **15%** | **65%** | **20%** | Computer Programming (Java), Web Development, Animation, Robotics |
| **Arts, Sports, Health & Wellness Electives** | **20%** | **60%** | **20%** | Art Criticism and Creative Markets, Music, Visual Arts, Sports Science |
| **Research, Design, and Innovation** | **15%** | **70%** | **15%** | Capstone Projects, Research in Daily Life, Innovation Projects |
| **Work Immersion / Apprenticeship** | **40%** | **60%** | **0%** *(o 15% TE)* | Work Immersion, Field Exposure (*15% Term Exam lang*) |
| **Old Curriculum / Custom (Custom Mode)** | *Teacher sets* | *Teacher sets* | *Teacher sets* | Manu-manong i-e-encode ng teacher basta mag-total sa **100%** |

---

### B. Internal Sub-weights ng Examinations (EX) Component
Hindi simpleng pag-total ng scores ang EX component. Hinahati ito sa tatlong (3) sub-assessments na may kanya-kanyang internal weights:
* **Summative Test 1 (ST 1):** **30%** ng EX
* **Summative Test 2 (ST 2):** **30%** ng EX
* **Term Examination (TE):** **40%** ng EX

$$\text{WS ST1} = \left(\frac{\text{ST1 Raw Score}}{\text{ST1 HPS}}\right) \times 30$$
$$\text{WS ST2} = \left(\frac{\text{ST2 Raw Score}}{\text{ST2 HPS}}\right) \times 30$$
$$\text{WS TE} = \left(\frac{\text{TE Raw Score}}{\text{TE HPS}}\right) \times 40$$
$$\text{Total EX PS} = \text{WS ST1} + \text{WS ST2} + \text{WS TE}$$
$$\text{EX Weighted Score (WS)} = \text{Total EX PS} \times \text{Weight}_{\text{EX}}$$

*(Tala: Sa mga specialized immersion o field exposure, ang buong 15% EX ay nagmumula sa Term Exam TE lamang).*

---

### C. Standard Computation Pipeline (Step-by-Step)
1. **Compute Percentage Score (PS):**
   $$\text{WW PS} = \left(\frac{\sum \text{WW Raw Scores}}{\sum \text{WW HPS}}\right) \times 100$$
   $$\text{PT PS} = \left(\frac{\sum \text{PT Raw Scores}}{\sum \text{PT HPS}}\right) \times 100$$
2. **Compute Component Weighted Scores (WS):**
   $$\text{WW WS} = \text{WW PS} \times \text{Weight}_{\text{WW}}$$
   $$\text{PT WS} = \text{PT PS} \times \text{Weight}_{\text{PT}}$$
   $$\text{EX WS} = \text{EX PS} \times \text{Weight}_{\text{EX}}$$
3. **Compute Initial Grade (IG):**
   $$\text{Initial Grade} = \text{WW WS} + \text{PT WS} + \text{EX WS}$$
4. **Transmutation to Term Grade (TG):**
   I-lookup ang Initial Grade sa **Adjusted Transmutation Table** (DO 15, s. 2026).
5. **Compute Final Grade (3-Term Subjects):**
   $$\text{Final Grade} = \text{ROUND}\left(\frac{\text{TG}_1 + \text{TG}_2 + \text{TG}_3}{3}, 0\right)$$

---

### D. Ang Opisyal na Adjusted Transmutation Table (DO 15, s. 2026)

| Initial Grade Range (Min – Max) | Transmuted Term Grade | Level / Descriptor |
| :---: | :---: | :--- |
| **99.50 – 100.00** | **100** | Advancing (90 – 100) |
| **98.32 – 99.49** | **99** | Advancing |
| **97.14 – 98.31** | **98** | Advancing |
| **95.96 – 97.13** | **97** | Advancing |
| **94.78 – 95.95** | **96** | Advancing |
| **93.60 – 94.77** | **95** | Advancing |
| **92.42 – 93.59** | **94** | Advancing |
| **91.24 – 92.41** | **93** | Advancing |
| **90.06 – 91.23** | **92** | Advancing |
| **88.88 – 90.05** | **91** | Advancing |
| **87.70 – 88.87** | **90** | Advancing |
| **86.52 – 87.69** | **89** | Benchmarking (80 – 89) |
| **85.34 – 86.51** | **88** | Benchmarking |
| **84.16 – 85.33** | **87** | Benchmarking |
| **82.98 – 84.15** | **86** | Benchmarking |
| **81.80 – 82.97** | **85** | Benchmarking |
| **80.62 – 81.79** | **84** | Benchmarking |
| **79.44 – 80.61** | **83** | Benchmarking |
| **78.26 – 79.43** | **82** | Benchmarking |
| **77.08 – 78.25** | **81** | Benchmarking |
| **75.90 – 77.07** | **80** | Benchmarking |
| **74.72 – 75.89** | **79** | Connecting (75 – 79) |
| **73.54 – 74.71** | **78** | Connecting |
| **72.36 – 73.53** | **77** | Connecting |
| **71.18 – 72.35** | **76** | Connecting |
| **70.00 – 71.17** | **75** | Connecting *(Passing Line)* |
| **65.34 – 69.99** | **74** | Developing (65 – 74) |
| **60.67 – 65.33** | **73** | Developing |
| **56.01 – 60.66** | **72** | Developing |
| **51.34 – 56.00** | **71** | Developing |
| **46.67 – 51.33** | **70** | Developing |
| **42.01 – 46.66** | **69** | Developing |
| **37.34 – 42.00** | **68** | Developing |
| **32.68 – 37.33** | **67** | Developing |
| **28.01 – 32.67** | **66** | Developing |
| **23.35 – 28.00** | **65** | Developing |
| **18.68 – 23.34** | **64** | Emerging (60 – 64) |
| **14.01 – 18.67** | **63** | Emerging |
| **9.35 – 14.00** | **62** | Emerging |
| **4.68 – 9.34** | **61** | Emerging |
| **0.00 – 4.67** | **60** | Emerging |

---

### E. Descriptors & Qualitative Assessment
| Numerical Grade Range | Descriptors | General Description | Remarks |
| :---: | :---: | :--- | :---: |
| **90 – 100** | **Advancing** | Consistently demonstrates skills and understanding that meet or exceed standards with independence, flexibility, and depth. | **PASSED** |
| **80 – 89** | **Benchmarking** | Demonstrates expected grade-level skills and understanding competently and independently. | **PASSED** |
| **75 – 79** | **Connecting** | Demonstrates sufficient understanding and application of grade-level standards with occasional guidance and support. | **PASSED** |
| **65 – 74** | **Developing** | Demonstrates partial understanding and inconsistent application of skills, requires targeted support and scaffolding. | **FAILED** |
| **60 – 64** | **Emerging** | Does not yet demonstrate foundational skills and understanding; requires intensive support. | **FAILED** |

---

## 3. UI/UX Flow for Teachers (Flexible Setup)

### Scenario 1: First-Time Gradebook Setup (Replacing "Input Data" Sheet)
Kapag unang beses binuksan ni teacher ang Gradebook para sa isang klase (e.g., Gen Math):
1.  **Prompt:** *"Configure Grading Weights for [Subject Name]"*
2.  **Select Curriculum System & Setup Mode:**
    *   **Grade 11 (Strengthened SHS — New Curriculum):** May automatic dropdown templates para sa Core Subjects at Elective Clusters (*Business & Entrepreneurship*, *Social Sciences & Humanities*). Automatic ang default DO 15 presets (WW=20%, PT=50%, EX=30%). May **Custom Fallback** din kung gustong mag-type ng ibang Subject Name si Grade 11 teacher.
    *   **Grade 12 (Old Curriculum — 3 Terms):** Sumusunod din sa **3 Terms (Trimester)** schedule at may **100% kaparehong grading computation engine** (WW PS/WS + PT PS/WS + EX PS/WS, 41-tier transmutation, 3-term average). Dahil Old Curriculum pa ang Grade 12, gagamit ang teacher ng Custom Setup Mode para i-type nang mano-mano ang Subject Name at ang sarili nilang WW, PT, at EX percentages (na kailangang mag-total sa 100%).


3.  **Component Builder:**
    *   Kung Strengthened SHS, lalabas agad ang breakdown. Kung custom, ita-type pa lang.
    *   Sa ilalim ng **EX (30%)**, pwedeng mag-add ng "Child Components" (ST1, ST2, TE) gaya ng nasa excel template para mas detailed ang pagkuha ng EX score.
4.  **Validation:** Ang "Save" button ay naka-disable hanggang hindi nagto-total sa **100%** ang mga weights.

### Scenario 2: Adding a Grade Item (Encoding Scores in Term 1/2/3)
1.  Sa Gradebook view, pipili si teacher ng Term (Term 1).
2.  Click `+ Add Column / Grade Item`.
3.  Fill out form: Name (e.g., Quiz 1), Component Category (Dropdown: WW, PT, ST1, ST2, TE), at **Highest Possible Score (HPS)**.
4.  Lalabas ang bagong column. Mag-i-input ng raw scores si teacher per student.
5.  **Real-time Computation:** Automatic na mag-u-update ang "Total", "PS", at "WS" columns bawat input ni teacher, gaya ng bilis ng Excel. Hahatiin din nang maayos ang Male at Female rows.

---

## 4. Edge Cases & System Responses (Critical Scenarios)

| Scenario / Edge Case | System Response / Backend Logic | User Experience (UI) |
| :--- | :--- | :--- |
| **Weights do not equal 100%** | System blocks saving of Gradebook Setup. | Red warning text: *"Total weight must be exactly 100%. Current total: [X]%."* Save button is disabled. |
| **Teacher adds a column but sets HPS to 0** | Prevents Division by Zero error in backend (`Score / 0 = Error`). | Error modal: *"Highest Possible Score must be greater than 0."* |
| **Student's raw score is higher than HPS** | Validation block to prevent inflated grades. | Cell turns red. Warning: *"Score cannot exceed the Highest Possible Score ([HPS])."* |
| **Blank Score (Student was absent/excused)** | Blank cell is ignored in computation. It does NOT count as zero automatically unless typed. | Cell stays empty. HPS for that specific student can be optionally exempted in future updates. |
| **Zero Score Input (0)** | Computed mathematically. PS and Average drop accordingly. | Display `0` in red text to alert the teacher. |
| **Changing weights Mid-Term** (May encoded grades na) | System allows it but requires confirmation, as it will recalculate all existing grades. | Modal Alert: *"Changing component weights will recalculate the grades of all students. Proceed?"* |
| **Viewing "Final Grades" tab but Term 3 is missing** | System computes running average based only on completed terms. | Shows "N/A" for Term 3, but Final Grade shows tentative running average. |

---

## 5. Connection to Master Plan
*   Ang buong flow na ito ay ang katuparan ng **Section 1.19 (Flexible Gradebook Assessment Engine)** sa ating `Master_Plan.md`.
*   Dahil naka-link ang "INPUT DATA" sa central database, hindi na mag-ta-type ng LRN at pangalan ang mga teacher nang paulit-ulit. One-time enrollment lang, automatic na itong lalabas sa Gradebook ng bawat subject.
