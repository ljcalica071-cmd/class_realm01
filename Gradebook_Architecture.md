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
| **1. INSTRUCTIONS** | **Onboarding / Help Tooltips** | Hindi na kailangan ng hiwalay na tab. Maglalagay tayo ng "i" (info) icons at coach marks kapag first time binuksan ni teacher ang Gradebook. |
| **2. INPUT DATA** | **Academic Setup & Student Roster** | Ang *School Info*, *Teacher Info*, at *Learners' Names (Male/Female)* ay **automatic nang mapupunan**. Manggagaling ito sa Step 2 & 3 ng Teacher Setup at sa mga enrolled students. Wala nang manual typing ng pangalan! Ang tanging ise-setup ni teacher dito ay ang **Subject Category & Cluster** para sa computation. |
| **3. Term 1** | **Gradebook Tab (Filtered to Term 1)** | Isang matrix view kung saan nag-i-input ng raw scores (WW, PT, EX). |
| **4. Term 2** | **Gradebook Tab (Filtered to Term 2)** | Same view, papalitan lang ang filter dropdown sa taas to "Term 2". |
| **5. Term 3** | **Gradebook Tab (Filtered to Term 3)** | Same view, papalitan lang ang filter dropdown sa taas to "Term 3". |
| **6. FINAL GRADES** | **Final Grades / Report Card View** | Isang read-only summary table na nagko-compute ng average ng Term 1, 2, at 3 para makuha ang Final Grade per subject. |

---

## 2. Dynamic Grading Logic (The SSHS Core Subject Standard)

Ang system natin ay magiging flexible para makapag-set ang teacher ng sarili nilang percentages, ngunit ang **Default Preset para sa SSHS Core Subjects** ay susunod sa eksaktong hatian ng template:

*   **Written / Oral Works (WWs):** 20%
*   **Product / Performance Tasks (PTs):** 50%
*   **Examinations (EXs):** 30% (Na may sub-categories pa: ST1=30%, ST2=30%, TE=40%)

### Core Formulas (Automated by Backend):
1.  **Percentage Score (PS) per Component:**
    `PS = (Total Learner's Raw Score / Total Highest Possible Score) * 100`
2.  **Weighted Score (WS) per Component:**
    `WS = PS * (Component Weight Percentage / 100)` *(e.g., PS * 0.20 para sa WW)*
3.  **Initial Grade:**
    `Initial Grade = WS_WW + WS_PT + WS_EX`
4.  **Term Grade (Transmuted):**
    Base sa official DepEd Transmutation Table (halimbawa, 60 Initial Grade = 75 Transmuted Grade). Ang transmutation table ay nasa database para standard at laging updated.

---

## 3. UI/UX Flow for Teachers (Flexible Setup)

### Scenario 1: First-Time Gradebook Setup (Replacing "Input Data" Sheet)
Kapag unang beses binuksan ni teacher ang Gradebook para sa isang klase (e.g., Gen Math):
1.  **Prompt:** *"Configure Grading Weights for [Subject Name]"*
2.  **Select Preset:**
    *   **SSHS Core Subject (Default):** WW=20%, PT=50%, EX=30%.
    *   **Custom Setup:** Pwedeng ibahin ni teacher kung sakaling Work Immersion o ibang track ito na may ibang grading format.
3.  **Component Builder:**
    *   Kung pinili niya ang default, makikita niya agad ang 20-50-30 breakdown.
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
