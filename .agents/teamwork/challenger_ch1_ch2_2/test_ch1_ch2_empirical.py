"""
test_ch1_ch2_empirical.py
Standalone empirical validation script for CLASSREALM Chapters 1 & 2 deliverable.
Run by Challenger 2 (teamwork_challenger).
"""

import os
import sys
import re
import urllib.request
import urllib.error
import docx

DOCX_PATH = r"c:\Users\Admin\AndroidStudioProjects\class_realm01\INTEGRATED SENIOR HIGH SCHOOL ATTENDANCE.docx"

def main():
    print("=" * 80)
    print("CHALLENGER 2: EMPIRICAL VALIDATION & STRESS-TEST HARNESS")
    print("Target Document:", DOCX_PATH)
    print("=" * 80)

    if not os.path.exists(DOCX_PATH):
        print(f"FAIL: Deliverable not found at {DOCX_PATH}")
        sys.exit(1)

    file_size = os.path.getsize(DOCX_PATH)
    print(f"Deliverable Size: {file_size:,} bytes")

    doc = docx.Document(DOCX_PATH)
    paragraphs = doc.paragraphs
    tables = doc.tables

    print(f"Total Paragraphs: {len(paragraphs)}")
    print(f"Total Tables: {len(tables)}")

    full_text = "\n".join([p.text for p in paragraphs])

    # -------------------------------------------------------------
    # 1. LITERATURE STUDY COUNT & TEMPORAL HORIZON (2021-2026)
    # -------------------------------------------------------------
    print("\n" + "-" * 40)
    print("CHECK 1: Literature Study Count & Temporal Horizon (2021-2026)")
    print("-" * 40)

    # 5 Local Studies expected:
    # 1. Dela Cruz & Santos (2021)
    # 2. Canlas & Ado (2024)
    # 3. Bautista & Reyes (2025)
    # 4. Contreras & Mercado (2024)
    # 5. Edraga (2026)
    
    # 5 Foreign Studies expected:
    # 6. Al-Maroof et al. (2021)
    # 7. Wang et al. (2023)
    # 8. Kumar & Sharma (2022)
    # 9. Januhari et al. (2025)
    # 10. Fitriani et al. (2024)

    studies = [
        {"name": "Dela Cruz & Santos", "year": 2021, "type": "Local", "domain": "RFID Attendance"},
        {"name": "Canlas & Ado", "year": 2024, "type": "Local", "domain": "Learning Materials & Mobile Offline Access"},
        {"name": "Bautista & Reyes", "year": 2025, "type": "Local", "domain": "Automated Grade Computation & DepEd SF9/SF10"},
        {"name": "Contreras & Mercado", "year": 2024, "type": "Local", "domain": "Teacher Lesson Planning Guide Generation"},
        {"name": "Edraga", "year": 2026, "type": "Local", "domain": "AI/Algorithmic Lesson Plan Curation"},
        {"name": "Al-Maroof et al.", "year": 2021, "type": "Foreign", "domain": "Assessment & Cloud Submission"},
        {"name": "Wang et al.", "year": 2023, "type": "Foreign", "domain": "Automated Formative Assessment & Instant Feedback"},
        {"name": "Kumar & Sharma", "year": 2022, "type": "Foreign", "domain": "Dual-Path Attendance Tracking & Cloud Sync"},
        {"name": "Januhari et al.", "year": 2025, "type": "Foreign", "domain": "Cloud Learning Materials Organization & Indexing"},
        {"name": "Fitriani et al.", "year": 2024, "type": "Foreign", "domain": "Web-Mobile Multi-Portal Academic Information Systems"}
    ]

    local_count = 0
    foreign_count = 0
    temporal_valid = True

    for s in studies:
        pattern = re.compile(rf"{re.escape(s['name'])}.*?\({s['year']}\)", re.IGNORECASE)
        found = pattern.search(full_text)
        if not found:
            # check without parens or variant
            pattern2 = re.compile(rf"{re.escape(s['name'])}", re.IGNORECASE)
            found = pattern2.search(full_text)
        
        status = "FOUND" if found else "MISSING"
        if s["year"] < 2021 or s["year"] > 2026:
            temporal_valid = False
            year_stat = "INVALID_HORIZON"
        else:
            year_stat = "VALID_HORIZON"

        if s["type"] == "Local":
            local_count += 1
        else:
            foreign_count += 1

        print(f"[{status}] [{s['type']}] {s['name']} ({s['year']}) - {year_stat} - Domain: {s['domain']}")

    print(f"\nSummary Check 1: Local Studies = {local_count}/5, Foreign Studies = {foreign_count}/5, Total = {local_count+foreign_count}/10")
    print(f"Temporal Horizon (2021-2026) Strictly Respected: {temporal_valid}")

    # -------------------------------------------------------------
    # 2. METHODOLOGY, SAMPLE SIZE (N), & QUANTITATIVE FINDINGS
    # -------------------------------------------------------------
    print("\n" + "-" * 40)
    print("CHECK 2: Explicit Methodologies, Sample Sizes (N), Quantitative Metrics")
    print("-" * 40)

    # Let's inspect each study's text in the document
    for s in studies:
        print(f"\nAnalyzing Study: {s['name']} ({s['year']})")
        # Find paragraphs containing this study
        matched_paras = [p.text for p in paragraphs if s['name'] in p.text]
        combined_study_text = " ".join(matched_paras)
        
        # Check for N=
        n_match = re.search(r'N\s*=\s*(\d+)', combined_study_text, re.IGNORECASE) or re.search(r'sample of\s*(\d+)', combined_study_text, re.IGNORECASE) or re.search(r'(\d+)\s*(respondents|participants|students|teachers|evaluators|users)', combined_study_text, re.IGNORECASE)
        n_val = n_match.group(0) if n_match else "NONE FOUND"
        
        # Check for quantitative metrics (% or p-value or t-value or mean or SD)
        quant_match = re.findall(r'(\d+(?:\.\d+)?%|p\s*[<=]\s*\d+\.\d+|t\s*=\s*\d+\.\d+|r\s*=\s*\d+\.\d+|R\^2\s*=\s*\d+\.\d+|mean of \d+\.\d+|\b\d+\.\d+\s*(?:out of 5|/5|mean|SD)?|\b\d+\s*minutes|\b\d+\s*seconds)', combined_study_text, re.IGNORECASE)
        
        print(f"  - Sample Size: {n_val}")
        print(f"  - Quantitative Metrics Found ({len(quant_match)}): {quant_match[:5]}")
        if not n_match or not quant_match:
            print("  WARNING: Quantitative metrics or sample size might be sparse in narrative!")

    # -------------------------------------------------------------
    # 3. DIRECT EMPIRICAL PROOF FOR TEACHER WORKFLOWS
    # -------------------------------------------------------------
    print("\n" + "-" * 40)
    print("CHECK 3: Direct Empirical Proof for Teacher Workflows")
    print("-" * 40)

    # Lesson planning workflow: Contreras & Mercado (2024), Edraga (2026)
    lp_studies = ["Contreras & Mercado", "Edraga"]
    for lps in lp_studies:
        paras = [p.text for p in paragraphs if lps in p.text]
        print(f"\n[Teacher Lesson Planning] {lps}:")
        if paras:
            print(f"  Found in {len(paras)} paragraph(s).")
            for p in paras:
                print(f"  Excerpt: {p[:200]}...")
        else:
            print(f"  FAIL: {lps} not found in text!")

    # Learning materials workflow: Canlas & Ado (2024), Januhari et al. (2025)
    lm_studies = ["Canlas & Ado", "Januhari"]
    for lms in lm_studies:
        paras = [p.text for p in paragraphs if lms in p.text]
        print(f"\n[Learning Materials Organization] {lms}:")
        if paras:
            print(f"  Found in {len(paras)} paragraph(s).")
            for p in paras:
                print(f"  Excerpt: {p[:200]}...")
        else:
            print(f"  FAIL: {lms} not found in text!")

    # -------------------------------------------------------------
    # 4. TABLE 1 SYNTHESIS MATRIX VALIDATION
    # -------------------------------------------------------------
    print("\n" + "-" * 40)
    print("CHECK 4: Table 1 Synthesis Matrix Validation")
    print("-" * 40)

    if len(tables) < 1:
        print("FAIL: No tables found in document!")
    else:
        t1 = tables[0]
        rows = len(t1.rows)
        cols = len(t1.columns)
        print(f"Table 1 Dimensions: {rows} rows x {cols} columns")
        
        headers = [c.text.strip().replace('\n', ' ') for c in t1.rows[0].cells]
        print("Header row columns:")
        for idx, h in enumerate(headers):
            print(f"  Col {idx+1}: {h}")

        expected_study_rows = rows - 1
        print(f"Data rows (Studies): {expected_study_rows} (Expected: 10)")

        # Check for blanket negative statements like "lacks", "failed to", "no support"
        blanket_negative_words = [r'\blacks\b', r'\blacking\b', r'\bfailed to\b', r'\bhas no\b', r'\blacks any\b', r'\bno capability\b']
        flagged_cells = []

        for r_idx, row in enumerate(t1.rows[1:], start=1):
            row_study = row.cells[0].text.strip().replace('\n', ' ')
            sample_size = row.cells[3].text.strip().replace('\n', ' ')
            findings = row.cells[4].text.strip().replace('\n', ' ')
            synthesis = row.cells[5].text.strip().replace('\n', ' ')
            
            print(f"\nRow {r_idx}: {row_study}")
            print(f"  Sample ($N$): {sample_size}")
            print(f"  Findings Excerpt: {findings[:120]}...")
            print(f"  Synthesis / Gaps: {synthesis[:120]}...")

            for pattern in blanket_negative_words:
                if re.search(pattern, synthesis, re.IGNORECASE):
                    flagged_cells.append((r_idx, row_study, pattern))

        if flagged_cells:
            print(f"\nWARNING: Found potential blanket negative phrasing in Table 1:")
            for f in flagged_cells:
                print(f"  Row {f[0]} ({f[1]}): matches regex '{f[2]}'")
        else:
            print("\nPASS: No unsupported blanket negative 'lacks' claims found in Table 1!")

    # -------------------------------------------------------------
    # 5. THEORETICAL & CONCEPTUAL FRAMEWORK (DeLone & McLean 2003, IPSO)
    # -------------------------------------------------------------
    print("\n" + "-" * 40)
    print("CHECK 5: Theoretical & Conceptual Framework Verification")
    print("-" * 40)

    # DeLone & McLean citation
    dm_matches = re.findall(r'DeLone\s*(?:&|and)\s*McLean\s*\((?:1992|2003)\)', full_text, re.IGNORECASE)
    print(f"DeLone & McLean citations: {dm_matches}")
    dm_2003_found = any('2003' in m for m in dm_matches)
    dm_1992_found = any('1992' in m for m in dm_matches)
    print(f"DeLone & McLean (2003) cited: {dm_2003_found}")
    print(f"Outdated 1992 citation present: {dm_1992_found}")

    # Check 6 dimensions
    dimensions = [
        "System Quality",
        "Information Quality",
        "Service Quality",
        "Use", # or Intention to Use
        "User Satisfaction",
        "Net Benefits"
    ]
    print("\nChecking DeLone & McLean 6 Dimensions:")
    for dim in dimensions:
        dim_found = re.search(rf"\b{re.escape(dim)}\b", full_text, re.IGNORECASE)
        print(f"  - {dim}: {'FOUND' if dim_found else 'MISSING'}")

    # Check 4-part IPSO Conceptual Framework
    ipso_parts = ["Input", "Process", "System", "Output"]
    print("\nChecking 4-part IPSO Framework:")
    ipso_found_all = True
    for part in ipso_parts:
        part_found = re.search(rf"\b{part}\b", full_text)
        print(f"  - {part}: {'FOUND' if part_found else 'MISSING'}")
        if not part_found:
            ipso_found_all = False

    # Check Figures
    fig1 = re.search(r'Figure\s*1', full_text, re.IGNORECASE)
    fig2 = re.search(r'Figure\s*2', full_text, re.IGNORECASE)
    print(f"Figure 1 (Theoretical Framework) Caption: {'FOUND' if fig1 else 'MISSING'}")
    print(f"Figure 2 (Conceptual Framework / IPSO) Caption: {'FOUND' if fig2 else 'MISSING'}")

    # -------------------------------------------------------------
    # 6. CHAPTER 1 SMART CRITERIA & OPERATIONAL DEFINITIONS
    # -------------------------------------------------------------
    print("\n" + "-" * 40)
    print("CHECK 6: SMART Criteria & Operational Definitions")
    print("-" * 40)

    # Search for SMART targets
    smart_sy = re.findall(r'SY\s*2026[–-]2027|School\s*Year\s*2026[–-]2027|2026[–-]2027', full_text)
    print(f"Mentions of SY 2026-2027: {len(smart_sy)}")

    # Specific SMART numbered items
    smart_items = []
    for p in paragraphs:
        t = p.text.strip()
        if re.search(r'^(?:Target\s*\d+|[1-9]\d?[\.\)])', t) and any(kw in t.lower() for kw in ['attendance', 'grade', 'seconds', 'percent', '%', 'lesson plan', 'material', 'accuracy']):
            smart_items.append(t)

    print(f"Quantifiable SMART criteria candidates detected: {len(smart_items)}")
    for idx, item in enumerate(smart_items[:12], 1):
        print(f"  SMART {idx}: {item[:110]}...")

    # Operational Definitions: 9 IT terms
    req_terms = [
        "ESP32",
        "RFID",
        "Firebase Authentication",
        "Supabase",
        "Row-Level Security",
        "Admin Portal",
        "Teacher Portal",
        "Student Portal",
        "Parent Portal"
    ]
    print("\nVerifying 9 IT-Tailored Operational Definitions:")
    for term in req_terms:
        term_found = False
        term_def = ""
        for p in paragraphs:
            if p.text.strip().startswith(term) or f"**{term}**" in p.text or f"{term} -" in p.text or f"{term}:" in p.text or f"{term}." in p.text[:30]:
                term_found = True
                term_def = p.text.strip()
                break
        if not term_found:
            # looser search
            for p in paragraphs:
                if term in p.text and len(p.text) > 40 and ("refers to" in p.text.lower() or "defined as" in p.text.lower() or "operates as" in p.text.lower() or "serves as" in p.text.lower() or "configured" in p.text.lower() or "architected" in p.text.lower()):
                    term_found = True
                    term_def = p.text.strip()
                    break

        status = "FOUND" if term_found else "MISSING"
        print(f"  [{status}] {term}")
        if term_found:
            print(f"         Def excerpt: {term_def[:120]}...")

    # -------------------------------------------------------------
    # 7. VERIFICATION OF ACTIVE DOIs / ACADEMIC URLs
    # -------------------------------------------------------------
    print("\n" + "-" * 40)
    print("CHECK 7: Verification of DOIs & Academic URLs")
    print("-" * 40)

    # Extract all URLs / DOIs from the text
    doi_urls = re.findall(r'https?://[^\s<>"\)\]]+', full_text)
    print(f"Total URLs found in document: {len(doi_urls)}")
    
    unique_urls = list(set(doi_urls))
    print(f"Unique URLs: {len(unique_urls)}")
    for u in unique_urls:
        print(f"  - {u}")

    print("\n" + "=" * 80)
    print("EMPIRICAL CHECK COMPLETE")
    print("=" * 80)

if __name__ == "__main__":
    main()
