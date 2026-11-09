# AI-Powered Quiz & Exam Question Generator — Detailed Implementation Plan & Master Prompt

This implementation plan is saved directly in the project repository at `docs/ai_assessment_generator_plan.md` so that any conversation or agent session in `class_realm01` can immediately read and reference it.

---

## 1. Master Agent Prompt (For Gradebook and Classwork Chat)

Copy and paste this prompt when you want the agent in your other chat to execute the implementation:

```markdown
Basahin mo ang implementation plan sa `docs/ai_assessment_generator_plan.md`. 
I-implement natin ang Document-Grounded AI Quiz & Exam Question Generator sa Assessment Creation Wizard (`lib/features/teacher/sub_features/assessments/screens/create_assessment_flow.dart`) para sa Quizzes (WW 1–10) at Exams (ST1, ST2, TE) sa Online Assessment mode.

Pangunahing requirements:
1. File upload: PDF (.pdf) at PowerPoint (.ppt, .pptx) lamang, max 15 MB na may upfront display at inline validation (Golden Rule).
2. Difficulty selector (Easy, Medium, Hard) at Target Focus selector (Memorization / Comprehensive / Critical Thinking).
3. Flexible question counts (MCQ, TF, Identification) kung saan pwede ang 0 sa alinmang type (hal. Identification lang kapag MCQ=0, TF=0).
4. Strict Grounding: Huwag gagamit ng outside knowledge na wala sa dokumento.
5. Auto-fill papunta sa Step 2 Question Builder (_plannedQuestions) para pwedeng i-review at i-edit ni teacher ang bawat tanong at answer key bago i-publish.
6. Validation adjustments: Short term/phrase lang sa identification (1-60 chars), bawal ang duplicate choices sa MCQ, at inline red error messages lamang.
```

---

## 2. Strict AI Grounding & Prompt Template

When [`GeminiService`](file:///c:/Users/rexsa/AndroidStudioProjects/class_realm01/lib/core/services/gemini_service.dart) calls the AI model:

```text
You are an expert Senior High School (SHS) Assessment Author for ClassRealm.
Your task is to generate a [ASSESSMENT_TYPE] ([ASSESSMENT_SLOT]) strictly based on the provided lecture document.

CRITICAL RULE: Do not use any outside knowledge. If the answer cannot be found in the document, do not create a question about it. Every question, option, and answer key must be 100% verifiable from the provided document text.

Quiz/Exam Requirements:
- Subject: [SUBJECT_NAME]
- Assessment Title: [ASSESSMENT_TITLE]
- Target Audience: Students taking a [DIFFICULTY] level assessment.
- Focus: [FOCUS_LABEL] — [FOCUS_DESCRIPTION]
- Multiple Choice Questions (MCQ): Generate exactly [MCQ_COUNT] questions. Each must have 4 plausible options (A, B, C, D) and 1 definitive correct answer ("A", "B", "C", or "D"). All 4 options must be distinct and between 1 and 150 characters.
- True/False Questions: Generate exactly [TF_COUNT] questions. Each must be a clear factual statement from the document whose answer is definitively "True" or "False".
- Identification Questions: Generate exactly [IDENT_COUNT] questions. Each question MUST be written in a "Terms and Definitions" style (describing a specific concept, term, person, law, or process from the document), and the answer MUST be a specific, short term or phrase found in the text (1 to 5 words, strictly 2 to 60 characters, never a full sentence or paragraph).

If any question count ([MCQ_COUNT], [TF_COUNT], or [IDENT_COUNT]) is 0, return an empty array [] for that category.

Character & Formatting Constraints:
1. Question statement: 15 to 400 characters. Clear, unambiguous, and grammatically complete.
2. MCQ choices: Exactly 4 strings per MCQ item (without leading "A. ", "B. " prefixes). Each choice must be 1 to 150 characters, and all 4 choices must be unique.
3. Identification answer ("correctAnswer"): 2 to 60 characters max, no trailing period, representing a concise term or short phrase directly from the document.
4. If the document does not contain enough distinct facts to fulfill the requested [TOTAL_COUNT] questions without inventing outside information, set "insufficientContent": true and generate as many strictly grounded questions as the document supports, explaining why in "warningMessage".

Return ONLY valid JSON matching this exact schema:
{
  "insufficientContent": false,
  "warningMessage": null,
  "multipleChoice": [
    {
      "statement": "Question text here?",
      "choices": ["Option A text", "Option B text", "Option C text", "Option D text"],
      "correctAnswer": "A",
      "sourceExcerpt": "Brief quote/page/slide reference from the document"
    }
  ],
  "trueFalse": [
    {
      "statement": "Declarative statement from the document.",
      "correctAnswer": "True",
      "sourceExcerpt": "Brief quote/page/slide reference from the document"
    }
  ],
  "identification": [
    {
      "statement": "Definition or description of the term based strictly on the document.",
      "correctAnswer": "Short Term",
      "sourceExcerpt": "Brief quote/page/slide reference from the document"
    }
  ]
}
```

---

## 3. Recommended Validation Adjustments

| Rule | Current State | Recommended Adjustment |
| :--- | :--- | :--- |
| **Question Distribution** | `int.tryParse` | Empty text box is treated as `0`. Total items must be `1..100`. |
| **Question Statement** | `min: 2`, `max: 500` | Set `min: 10`, `max: 500`. |
| **MCQ Choices** | `min: 2`, no max, no duplicate check | Allow `min: 1` char (para sa numbers `0`, `5`), add `max: 180` chars, at **case-insensitive uniqueness validation** (bawal magkaparehong choices). |
| **Identification Answer Key** | `min: 2`, no max | Set **`1..60` chars**, strip trailing periods, at bawal ang mahabang paragraph. |
| **File Upload (Golden Rule)** | Not yet implemented in Step 1 | Formats: `.pdf`, `.ppt`, `.pptx` only. Max size: `15 MB`. Lahat ng constraints ipinapakita upfront sa UI; lahat ng errors ay inline red text sa ilalim ng container. |

---

## 4. Workflow & Integration Architecture

1. **Step 1:** Teacher inputs counts (e.g. `MCQ = 0`, `TF = 0`, `IDENT = 10`), uploads `.pdf`/`.pptx` (max 15MB), selects Difficulty & Focus.
2. **Text Extraction:** In-memory extraction via `archive` package (for `.pptx`) at `DataPart` / text extractor (for `.pdf`).
3. **AI Generation:** `GeminiService.generateAssessmentQuestions(...)` with multi-key failover in `EnvConfig`.
4. **Auto-Fill:** Direct mapping to `List<QuestionDraft> _plannedQuestions` and navigation to **Step 2 (Question Builder)**.
5. **Review & Edit:** Teacher can click each question in the navigator matrix, edit statements/choices/answers, and publish when all are complete.
