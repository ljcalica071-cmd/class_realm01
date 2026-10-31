import docx
import os
import sys
import zipfile
import re
import subprocess
import datetime
import json

DOCX_PATH = r"c:\Users\Admin\AndroidStudioProjects\class_realm01\INTEGRATED SENIOR HIGH SCHOOL ATTENDANCE.docx"
REPORT_OUTPUT = r"c:\Users\Admin\AndroidStudioProjects\class_realm01\.agents\teamwork\auditor_ch1_ch2_1\audit_results.json"
DUMP_OUTPUT = r"c:\Users\Admin\AndroidStudioProjects\class_realm01\.agents\teamwork\auditor_ch1_ch2_1\extracted_manuscript.txt"

def run_comprehensive_audit():
    results = {
        "timestamp": datetime.datetime.now(datetime.timezone.utc).isoformat(),
        "checks": {}
    }
    
    # ----------------------------------------------------
    # CHECK 1: Deliverable Authenticity & Substance
    # ----------------------------------------------------
    print("Executing Check 1: Deliverable Authenticity & Substance...")
    ch1_data = {}
    if not os.path.exists(DOCX_PATH):
        ch1_data["status"] = "FAIL"
        ch1_data["error"] = f"File not found: {DOCX_PATH}"
    else:
        file_size = os.path.getsize(DOCX_PATH)
        ch1_data["file_size_bytes"] = file_size
        doc = docx.Document(DOCX_PATH)
        paragraphs = doc.paragraphs
        ch1_data["paragraph_count"] = len(paragraphs)
        
        full_text = []
        words_count = 0
        char_count = 0
        for p in paragraphs:
            t = p.text.strip()
            full_text.append(t)
            words_count += len(t.split())
            char_count += len(t)
            
        ch1_data["words_in_paragraphs"] = words_count
        ch1_data["chars_in_paragraphs"] = char_count
        ch1_data["table_count"] = len(doc.tables)
        
        table_words = 0
        tables_meta = []
        for t_idx, tbl in enumerate(doc.tables):
            rows = len(tbl.rows)
            cols = len(tbl.columns) if rows > 0 else 0
            for r in tbl.rows:
                for c in r.cells:
                    table_words += len(c.text.strip().split())
            tables_meta.append({"table_index": t_idx + 1, "rows": rows, "cols": cols})
            
        ch1_data["tables_metadata"] = tables_meta
        ch1_data["words_in_tables"] = table_words
        ch1_data["total_words"] = words_count + table_words
        
        # Check media assets
        with zipfile.ZipFile(DOCX_PATH, 'r') as z:
            media_files = [f for f in z.namelist() if f.startswith('word/media/')]
            ch1_data["media_files"] = media_files
            
        # Check headings
        headings = []
        for i, p in enumerate(paragraphs):
            if p.style and 'Heading' in p.style.name:
                headings.append({"index": i, "style": p.style.name, "text": p.text})
            elif p.text.isupper() and 3 < len(p.text) < 100:
                headings.append({"index": i, "style": "CAPS", "text": p.text})
        ch1_data["headings"] = headings
        
        # Check if placeholders exist
        placeholders = [p.text for p in paragraphs if "[TBD]" in p.text or "[TODO]" in p.text or "Lorem ipsum" in p.text]
        ch1_data["placeholder_count"] = len(placeholders)
        ch1_data["placeholders"] = placeholders
        
        ch1_data["status"] = "PASS" if ch1_data["total_words"] > 5000 and len(placeholders) == 0 else "FAIL"
        
        # Dump full text
        with open(DUMP_OUTPUT, "w", encoding="utf-8") as dump_file:
            dump_file.write(f"=== MANUSCRIPT DUMP (Total Words: {ch1_data['total_words']:,}) ===\n\n")
            dump_file.write("--- PARAGRAPHS ---\n")
            for i, p in enumerate(paragraphs):
                dump_file.write(f"[{i:03d} | {p.style.name if p.style else 'NoStyle'}]: {p.text}\n")
            dump_file.write("\n--- TABLES ---\n")
            for t_idx, tbl in enumerate(doc.tables):
                dump_file.write(f"\nTable {t_idx+1}:\n")
                for r_idx, r in enumerate(tbl.rows):
                    cells_text = [c.text.replace('\n', ' ') for c in r.cells]
                    dump_file.write(f"Row {r_idx:02d}: " + " | ".join(cells_text) + "\n")

    results["checks"]["1_authenticity_and_substance"] = ch1_data
    
    # ----------------------------------------------------
    # CHECK 2: File Isolation Audit
    # ----------------------------------------------------
    print("Executing Check 2: File Isolation Audit...")
    ch2_data = {}
    # Run git status on lib and test
    try:
        git_stat = subprocess.run(["git", "status", "--porcelain", "lib", "test"], capture_output=True, text=True)
        ch2_data["git_status_raw"] = git_stat.stdout
        modified_files = []
        for line in git_stat.stdout.strip().splitlines():
            parts = line.strip().split()
            if len(parts) >= 2:
                modified_files.append(parts[-1])
        ch2_data["reported_files"] = modified_files
        
        # Check timestamps
        # Note: Task prompt 2 (Chapters 1 & 2) was approved at 2026-10-29T22:58:33Z.
        # Let's inspect each modified file in lib and test for modification time.
        file_timestamps = {}
        files_modified_after_ch1_ch2_start = []
        # Target cutoff: 2026-10-29T22:58:33Z in epoch or ISO
        task2_start_dt = datetime.datetime.fromisoformat("2026-10-29T22:58:33+00:00")
        
        for f in modified_files:
            if os.path.exists(f):
                mtime = os.path.getmtime(f)
                dt = datetime.datetime.fromtimestamp(mtime, tz=datetime.timezone.utc)
                file_timestamps[f] = dt.isoformat()
                if dt >= task2_start_dt:
                    files_modified_after_ch1_ch2_start.append({"file": f, "mtime": dt.isoformat()})
                    
        ch2_data["file_timestamps"] = file_timestamps
        ch2_data["files_modified_during_ch1_ch2_task"] = files_modified_after_ch1_ch2_start
        ch2_data["status"] = "PASS" if len(files_modified_after_ch1_ch2_start) == 0 else "FAIL"
    except Exception as e:
        ch2_data["status"] = "ERROR"
        ch2_data["error"] = str(e)
        
    results["checks"]["2_file_isolation"] = ch2_data

    # Read the full text for content checks
    doc = docx.Document(DOCX_PATH)
    all_para_text = "\n".join([p.text for p in doc.paragraphs])
    all_table_text = "\n".join(["\n".join([c.text for c in r.cells]) for tbl in doc.tables for r in tbl.rows])
    combined_text = all_para_text + "\n" + all_table_text
    
    # ----------------------------------------------------
    # CHECK 4: Definition Integrity (9 IT Definitions)
    # ----------------------------------------------------
    print("Executing Check 4: Definition Integrity...")
    ch4_data = {}
    terms = [
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
    term_findings = {}
    for term in terms:
        # Search for term in paragraphs under Definition of Terms
        pattern = re.compile(rf"(?:^|\n)[ \t]*(?:[0-9]+\.|\b)?[ \t]*{re.escape(term)}[ \t]*[-:–—](.*?)(?=\n[ \t]*(?:[0-9]+\.|\b)?[ \t]*[A-Z][a-zA-Z0-9 -]+[-:–—]|\n\n|\Z)", re.DOTALL | re.IGNORECASE)
        match = pattern.search(all_para_text)
        if match:
            def_text = match.group(1).strip()
            # Check length and architecture specificity
            is_tailored = any(kw in def_text.lower() for kw in ["classrealm", "hardware", "postgres", "rls", "token", "lrn", "uid", "role", "portal", "attendance", "microcontroller", "offline", "flash", "jwt"])
            term_findings[term] = {
                "found": True,
                "text_snippet": def_text[:150] + ("..." if len(def_text) > 150 else ""),
                "word_count": len(def_text.split()),
                "tailored_to_architecture": is_tailored
            }
        else:
            # Fallback direct search
            term_matches = [p.text for p in doc.paragraphs if term.lower() in p.text.lower() and ("refer" in p.text.lower() or "defined" in p.text.lower() or "operat" in p.text.lower() or ":" in p.text)]
            term_findings[term] = {
                "found": len(term_matches) > 0,
                "snippet": term_matches[0][:150] if term_matches else "NOT FOUND",
                "tailored_to_architecture": any(kw in term_matches[0].lower() for kw in ["classrealm", "postgres", "rls", "token", "lrn", "uid"]) if term_matches else False
            }
    ch4_data["terms"] = term_findings
    all_terms_found = all(tf["found"] and tf["tailored_to_architecture"] for tf in term_findings.values())
    ch4_data["status"] = "PASS" if all_terms_found else "FAIL"
    results["checks"]["4_definition_integrity"] = ch4_data

    # ----------------------------------------------------
    # CHECK 5: Scope & Boundary Hardening Integrity
    # ----------------------------------------------------
    print("Executing Check 5: Scope & Boundary Hardening Integrity...")
    ch5_data = {}
    # 1. Admin negative boundaries
    admin_no_grades = ("grade" in combined_text.lower() and "admin" in combined_text.lower())
    admin_prohibitions = [
        "admin has no access" in combined_text.lower() or "admin is prohibited" in combined_text.lower() or "restricted exclusively" in combined_text.lower(),
        "academic year" in combined_text.lower(),
        "teacher provisioning" in combined_text.lower()
    ]
    # 2. Role exclusions: Registrar and Principal
    role_exclusions = ("registrar" in combined_text.lower() and "principal" in combined_text.lower() and "exclude" in combined_text.lower())
    # 3. Excluded workflows: transfer student, transfer section, dropping
    workflow_exclusions = ("transfer" in combined_text.lower() and "drop" in combined_text.lower())
    # 4. Permanent manual fallback
    manual_fallback = ("manual" in combined_text.lower() and "fallback" in combined_text.lower())
    # 5. Preserving/exporting student grade records
    grade_preservation = ("export" in combined_text.lower() or "download" in combined_text.lower()) and "grade" in combined_text.lower()

    ch5_data["admin_prohibitions_present"] = all(admin_prohibitions)
    ch5_data["registrar_principal_exclusions_present"] = role_exclusions
    ch5_data["transfer_drop_exclusions_present"] = workflow_exclusions
    ch5_data["manual_attendance_fallback_present"] = manual_fallback
    ch5_data["grade_preservation_export_present"] = grade_preservation
    
    ch5_status = all([
        all(admin_prohibitions),
        role_exclusions,
        workflow_exclusions,
        manual_fallback,
        grade_preservation
    ])
    ch5_data["status"] = "PASS" if ch5_status else "FAIL"
    results["checks"]["5_scope_and_boundary_hardening"] = ch5_data

    # ----------------------------------------------------
    # CHECK 6: Adviser Critique (Mpbomilc review) Resolution
    # ----------------------------------------------------
    print("Executing Check 6: Adviser Critique Resolution...")
    ch6_data = {}
    # 1. Institution: Eduardo Barreto Sr. High School (single 't')
    inst_correct = "Eduardo Barreto Sr. High School" in combined_text
    inst_misspelled = "Eduardo Barretto" in combined_text
    ch6_data["institution_correct"] = inst_correct
    ch6_data["institution_misspelling_found"] = inst_misspelled
    
    # 2. Client: Ma'am Karen P. Gonzaga
    client_correct = "Karen P. Gonzaga" in combined_text
    ch6_data["client_correct"] = client_correct
    
    # 3. SMART targets: measurable & dated
    smart_targets = ("smart" in combined_text.lower() or ("percent" in combined_text.lower() and "minute" in combined_text.lower()))
    ch6_data["smart_targets_present"] = smart_targets
    
    # 4. Permanent manual fallback
    ch6_data["manual_fallback_present"] = manual_fallback
    
    # 5. Synthesis matrix without blanket 'lacks'
    table_text_lower = all_table_text.lower()
    blanket_lacks = [p for p in table_text_lower.split('\n') if "lacks " in p or "simply lacks" in p or "does not have" in p]
    ch6_data["blanket_lacks_in_table"] = blanket_lacks
    ch6_data["synthesis_matrix_has_no_blanket_lacks"] = len(blanket_lacks) == 0
    
    # 6. DeLone & McLean (2003) model
    dm_2003 = "delone" in combined_text.lower() and "mclean" in combined_text.lower() and "2003" in combined_text
    ch6_data["delone_mclean_2003_present"] = dm_2003
    
    # 7. 4-part IPSO framework (Input, Process, System, Output)
    ipso_present = ("ipso" in combined_text.lower() or ("input" in combined_text.lower() and "process" in combined_text.lower() and "system" in combined_text.lower() and "output" in combined_text.lower()))
    ch6_data["ipso_framework_present"] = ipso_present
    
    ch6_status = (inst_correct and not inst_misspelled and client_correct and smart_targets and manual_fallback and (len(blanket_lacks) == 0) and dm_2003 and ipso_present)
    ch6_data["status"] = "PASS" if ch6_status else "FAIL"
    results["checks"]["6_adviser_critique_resolution"] = ch6_data

    # ----------------------------------------------------
    # CHECK 3: Scholarship Authenticity & Hallucination Forensics
    # ----------------------------------------------------
    print("Executing Check 3: Scholarship Authenticity & Hallucination Forensics...")
    ch3_data = {}
    
    # Expected 10 empirical studies from worker report:
    # Local: Holgado et al. (2026), Navarra & Antonio (2025), Mahinay & Encarnacion (2024), Contreras & Mercado (2024), Canlas & Ado (2024)
    # Foreign: Irhamna et al. (2026), Jantan et al. (2023), Jones (2022), Edraga (2026), Januhari et al. (2025)
    studies = [
        {"key": "Holgado et al. (2026)", "lead_author": "Holgado", "year": "2026", "type": "Philippine Local"},
        {"key": "Navarra & Antonio (2025)", "lead_author": "Navarra", "year": "2025", "type": "Philippine Local"},
        {"key": "Mahinay & Encarnacion (2024)", "lead_author": "Mahinay", "year": "2024", "type": "Philippine Local"},
        {"key": "Contreras & Mercado (2024)", "lead_author": "Contreras", "year": "2024", "type": "Philippine Local"},
        {"key": "Canlas & Ado (2024)", "lead_author": "Canlas", "year": "2024", "type": "Philippine Local"},
        {"key": "Irhamna, Kasmini, & Khairuman (2026)", "lead_author": "Irhamna", "year": "2026", "type": "International"},
        {"key": "Jantan, Mohd Zainudin, & Mustafa@Dain (2023)", "lead_author": "Jantan", "year": "2023", "type": "International"},
        {"key": "Jones (2022)", "lead_author": "Jones", "year": "2022", "type": "International"},
        {"key": "Edraga (2026)", "lead_author": "Edraga", "year": "2026", "type": "International"},
        {"key": "Januhari, Setyanto, & Kusrini (2025)", "lead_author": "Januhari", "year": "2025", "type": "International"}
    ]
    
    study_evaluations = []
    # Search reference list in docx
    ref_paras = [p.text for p in doc.paragraphs if "references" in p.text.lower() or "https://" in p.text or "doi.org" in p.text]
    
    for s in studies:
        author = s["lead_author"]
        year = s["year"]
        in_narrative = (author in all_para_text and year in all_para_text)
        in_table = (author in all_table_text and year in all_table_text)
        
        # Find exact reference entry
        ref_entry = None
        for p in doc.paragraphs:
            if author in p.text and year in p.text:
                if "http" in p.text or "doi" in p.text or "journal" in p.text.lower() or "conference" in p.text.lower() or "vol" in p.text.lower():
                    ref_entry = p.text.strip()
                    break
        
        doi_match = None
        if ref_entry:
            doi_search = re.search(r"https?://(?:dx\.)?doi\.org/[^\s]+|https?://[^\s]+", ref_entry)
            if doi_search:
                doi_match = doi_search.group(0).rstrip('.')
                
        study_evaluations.append({
            "key": s["key"],
            "type": s["type"],
            "lead_author": author,
            "year": int(year),
            "in_narrative": in_narrative,
            "in_table": in_table,
            "reference_entry": ref_entry,
            "doi_or_url": doi_match,
            "published_2021_2026": 2021 <= int(year) <= 2026
        })
        
    ch3_data["studies"] = study_evaluations
    all_studies_present = all(s["in_narrative"] and s["in_table"] and s["reference_entry"] is not None and s["published_2021_2026"] for s in study_evaluations)
    ch3_data["all_10_present_and_valid_dates"] = all_studies_present
    ch3_data["status"] = "PASS" if all_studies_present else "FAIL"
    results["checks"]["3_scholarship_authenticity"] = ch3_data

    # ----------------------------------------------------
    # FINAL VERDICT
    # ----------------------------------------------------
    all_passed = all(check["status"] == "PASS" for check in results["checks"].values())
    results["verdict"] = "CLEAN" if all_passed else "INTEGRITY VIOLATION"
    
    print("\n================ FINAL RESULTS ================")
    print(f"Check 1: {results['checks']['1_authenticity_and_substance']['status']}")
    print(f"Check 2: {results['checks']['2_file_isolation']['status']}")
    print(f"Check 3: {results['checks']['3_scholarship_authenticity']['status']}")
    print(f"Check 4: {results['checks']['4_definition_integrity']['status']}")
    print(f"Check 5: {results['checks']['5_scope_and_boundary_hardening']['status']}")
    print(f"Check 6: {results['checks']['6_adviser_critique_resolution']['status']}")
    print(f"VERDICT: {results['verdict']}")
    print("================================================")
    
    with open(REPORT_OUTPUT, "w", encoding="utf-8") as rf:
        json.dump(results, rf, indent=2)
    print(f"Detailed JSON results written to: {REPORT_OUTPUT}")

if __name__ == '__main__':
    run_comprehensive_audit()
