"""
audit_ch2.py - Independent, deep forensic audit of Chapter 2 in INTEGRATED SENIOR HIGH SCHOOL ATTENDANCE.docx
Author: Reviewer 2 (teamwork_reviewer)
"""

import os
import sys
import zipfile
import re
import urllib.request
import docx
from docx import Document
from docx.shared import Inches, Pt

DOC_PATH = r"c:\Users\Admin\AndroidStudioProjects\class_realm01\INTEGRATED SENIOR HIGH SCHOOL ATTENDANCE.docx"

def run_audit():
    print("=" * 80)
    print("REVIEWER 2: CHAPTER 2 INDEPENDENT FORENSIC AUDIT")
    print("=" * 80)
    
    if not os.path.exists(DOC_PATH):
        print(f"CRITICAL ERROR: File not found at {DOC_PATH}")
        sys.exit(1)
        
    file_size = os.path.getsize(DOC_PATH)
    print(f"File: {DOC_PATH}")
    print(f"File Size: {file_size:,} bytes")
    
    doc = Document(DOC_PATH)
    
    # 1. Section Margins
    print("\n--- 1. SECTION & MARGIN INSPECTION ---")
    sections = doc.sections
    print(f"Number of sections: {len(sections)}")
    for s_idx, section in enumerate(sections):
        top_in = round(section.top_margin.inches, 2)
        bottom_in = round(section.bottom_margin.inches, 2)
        left_in = round(section.left_margin.inches, 2)
        right_in = round(section.right_margin.inches, 2)
        print(f"Section {s_idx+1} Margins: Top={top_in}\", Bottom={bottom_in}\", Left={left_in}\", Right={right_in}\"")
        # Target: Top=1.6, Bottom=1.2, Left=1.6, Right=1.4
        if abs(top_in - 1.6) <= 0.05 and abs(left_in - 1.6) <= 0.05 and abs(bottom_in - 1.2) <= 0.05 and abs(right_in - 1.4) <= 0.05:
            print("  [PASS] Margins conform to Laguna University mandate (1.6, 1.6, 1.2, 1.4 inches).")
        else:
            print(f"  [WARN] Margins do not exactly match expected 1.6, 1.6, 1.2, 1.4: {top_in}, {left_in}, {bottom_in}, {right_in}")

    # 2. Extract Chapter 2 Paragraphs
    print("\n--- 2. CHAPTER 2 PARAGRAPHS EXTRACTION ---")
    ch2_paragraphs = []
    in_ch2 = False
    ref_paragraphs = []
    in_ref = False
    
    for idx, p in enumerate(doc.paragraphs):
        text = p.text.strip()
        if "CHAPTER II" in text:
            in_ch2 = True
        elif "CHAPTER III" in text:
            in_ch2 = False
            break
            
        if in_ch2:
            if "2.5 References" in text or "REFERENCES" in text.upper():
                in_ref = True
            if in_ref and not ("2.5 References" in text or "REFERENCES" in text.upper()):
                if text:
                    ref_paragraphs.append((idx, text, p))
            ch2_paragraphs.append((idx, text, p))
            
    print(f"Total Paragraphs in Document: {len(doc.paragraphs)}")
    print(f"Total Paragraphs in Chapter 2: {len(ch2_paragraphs)}")
    print(f"Total Reference Entries: {len(ref_paragraphs)}")

    # 3. Check Chapter 2 Sections and Core Module Coverage
    print("\n--- 3. CORE MODULE COVERAGE CHECK ---")
    ch2_full_text = "\n".join([t for idx, t, p in ch2_paragraphs])
    
    modules = {
        "Attendance Tracking (RFID / Manual Fallback)": [
            "attendance tracking", "rfid", "manual", "fallback", "esp32", "roster"
        ],
        "Assessment & Grade Computation": [
            "grading", "assessment", "deped order no. 015", "written work", "performance tasks", "transmutation"
        ],
        "Teacher Lesson Planning Guide Generation": [
            "lesson plan", "guide generation", "instructional planning", "competencies", "edraga", "contreras"
        ],
        "Learning Materials Organization": [
            "learning materials", "repository", "instructional material", "canlas", "januhari"
        ]
    }
    
    for mod_name, keywords in modules.items():
        found = [kw for kw in keywords if kw.lower() in ch2_full_text.lower()]
        print(f"Module: {mod_name}")
        print(f"  Keywords matched ({len(found)}/{len(keywords)}): {found}")
        if len(found) >= 3:
            print("  [PASS] Sufficiently covered in literature review narrative.")
        else:
            print("  [FAIL] Inadequate coverage in literature review narrative.")

    # 4. Check Empirical Studies (10 studies: 5 local, 5 foreign)
    print("\n--- 4. SOURCED EMPIRICAL LITERATURE VERIFICATION (10 Studies, 2021-2026) ---")
    local_studies = [
        "Holgado", "Navarra", "Mahinay", "Contreras", "Canlas"
    ]
    foreign_studies = [
        "Irhamna", "Jantan", "Jones", "Edraga", "Januhari"
    ]
    
    print("Checking Philippine Local Studies (5 expected):")
    for s in local_studies:
        present_in_text = s.lower() in ch2_full_text.lower()
        print(f"  Local study '{s}': {'FOUND' if present_in_text else 'MISSING'}")
        
    print("Checking Foreign/International Studies (5 expected):")
    for s in foreign_studies:
        present_in_text = s.lower() in ch2_full_text.lower()
        print(f"  Foreign study '{s}': {'FOUND' if present_in_text else 'MISSING'}")

    # 5. Check Table 1 Synthesis Matrix
    print("\n--- 5. TABLE 1 SYNTHESIS MATRIX VERIFICATION ---")
    print(f"Total Tables in Document: {len(doc.tables)}")
    if len(doc.tables) > 0:
        tbl = doc.tables[0]
        rows = len(tbl.rows)
        cols = len(tbl.columns) if rows > 0 else 0
        print(f"Table 1 dimensions: {rows} rows x {cols} cols (Expected: 11 rows x 6 cols)")
        
        # Check Headers
        header_row = [c.text.strip().replace("\n", " ") for c in tbl.rows[0].cells]
        print(f"Header columns: {header_row}")
        
        expected_cols = [
            "AUTHOR", "TITLE", "METHODOLOGY", "SAMPLE", "FINDINGS", "CONTRIBUTION"
        ]
        col_matches = sum(1 for exp in expected_cols if any(exp in h.upper() for h in header_row))
        print(f"Header match score: {col_matches}/{len(expected_cols)}")
        
        # Check rows content
        blanket_lacks = 0
        studies_in_table = []
        for r_idx in range(1, rows):
            row_text = " | ".join([c.text.strip() for c in tbl.rows[r_idx].cells])
            # Check for negative "lack" / "lacks" statements
            if re.search(r'\blacks?\b|\bfailed to\b|\bdeficient\b', row_text, re.IGNORECASE):
                blanket_lacks += 1
                print(f"  [WARN] Potential negative/blanket statement in row {r_idx}: {row_text[:100]}...")
            for s in local_studies + foreign_studies:
                if s.lower() in row_text.lower() and s not in studies_in_table:
                    studies_in_table.append(s)
                    
        print(f"Studies represented in Table 1 ({len(studies_in_table)}/10): {studies_in_table}")
        print(f"Unsupported blanket 'lack' statements detected: {blanket_lacks}")
        if len(studies_in_table) == 10 and blanket_lacks == 0:
            print("  [PASS] Table 1 encompasses all 10 domain sources with constructive contributions and zero blanket 'lacks' claims.")
        else:
            print("  [FAIL/WARN] Table 1 check issues.")
    else:
        print("  [FAIL] No tables found in document!")

    # 6. Check Theoretical Framework (DeLone & McLean 2003)
    print("\n--- 6. THEORETICAL FRAMEWORK VERIFICATION ---")
    dm_2003 = "DeLone" in ch2_full_text and "McLean" in ch2_full_text and "2003" in ch2_full_text
    print(f"DeLone & McLean (2003) cited: {dm_2003}")
    
    dm_dims = [
        "System Quality", "Information Quality", "Service Quality", 
        "Use", "User Satisfaction", "Net Benefits"
    ]
    dm_found = [d for d in dm_dims if d.lower() in ch2_full_text.lower()]
    print(f"D&M Dimensions mapped ({len(dm_found)}/6): {dm_found}")
    
    fig1_present = "Figure 1" in ch2_full_text
    print(f"Figure 1 captioned: {fig1_present}")

    # 7. Check Conceptual Framework (4-part IPSO)
    print("\n--- 7. CONCEPTUAL FRAMEWORK (IPSO) VERIFICATION ---")
    ipso_text = "IPSO" in ch2_full_text or ("Input" in ch2_full_text and "Process" in ch2_full_text and "System" in ch2_full_text and "Output" in ch2_full_text)
    print(f"IPSO 4-part model present: {ipso_text}")
    
    ipso_parts = ["Input", "Process", "System", "Output"]
    ipso_narrative = all(p in ch2_full_text for p in ipso_parts)
    print(f"All 4 IPSO narrative stages present: {ipso_narrative}")
    
    fig2_present = "Figure 2" in ch2_full_text
    print(f"Figure 2 captioned: {fig2_present}")

    # 8. Check Embedded Media and Image Assets
    print("\n--- 8. EMBEDDED MEDIA ASSETS VERIFICATION ---")
    with zipfile.ZipFile(DOC_PATH, 'r') as z:
        media_files = [f for f in z.namelist() if f.startswith('word/media/')]
        print(f"Media files in docx archive ({len(media_files)}): {media_files}")
        for m in media_files:
            info = z.getinfo(m)
            print(f"  {m}: {info.file_size:,} bytes")
            
    # Check drawings/pictures in document.xml
    with zipfile.ZipFile(DOC_PATH, 'r') as z:
        doc_xml = z.read('word/document.xml').decode('utf-8')
        drawings = doc_xml.count('<w:drawing>')
        blips = re.findall(r'r:embed="(rId\d+)"', doc_xml)
        print(f"Total <w:drawing> tags: {drawings}")
        print(f"Image blip references ({len(blips)}): {blips}")
        if drawings >= 2 and len(media_files) >= 2:
            print("  [PASS] Figures 1 and 2 are genuinely embedded in the OpenXML package.")
        else:
            print("  [FAIL] Missing embedded image drawings.")

    # 9. References Audit & URL Verification
    print("\n--- 9. REFERENCES AUDIT (APA 7th Edition) ---")
    print(f"Total References Extracted: {len(ref_paragraphs)}")
    urls_found = []
    for idx, text, p in ref_paragraphs:
        # Check indent
        left = p.paragraph_format.left_indent
        first_line = p.paragraph_format.first_line_indent
        left_in = round(left.inches, 2) if left else None
        first_line_in = round(first_line.inches, 2) if first_line else None
        
        # Check URLs/DOIs
        urls = re.findall(r'https?://[^\s<>"]+|www\.[^\s<>"]+', text)
        urls_found.extend(urls)
        print(f"Ref {idx}: {text[:70]}...")
        print(f"  Indent: left={left_in}\", first_line={first_line_in}\" (Expected: left=0.5\", first_line=-0.5\")")
        print(f"  URLs found: {urls}")

    print(f"\nTotal URLs/DOIs found: {len(urls_found)}")
    
    # 10. URL Connectivity Check
    print("\n--- 10. URL / DOI LIVE REACHABILITY CHECK ---")
    headers = {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'}
    for u in set(urls_found):
        try:
            req = urllib.request.Request(u, headers=headers, method='HEAD')
            with urllib.request.urlopen(req, timeout=5) as resp:
                print(f"  [HTTP {resp.status}] {u}")
        except Exception as e:
            # Try GET if HEAD is not supported by some servers
            try:
                req = urllib.request.Request(u, headers=headers, method='GET')
                with urllib.request.urlopen(req, timeout=5) as resp:
                    print(f"  [HTTP {resp.status} (via GET)] {u}")
            except Exception as e2:
                print(f"  [UNREACHABLE / TIMEOUT / 403 / ERROR] {u} -> {e2}")

    print("\n" + "=" * 80)
    print("AUDIT EXECUTION COMPLETE")
    print("=" * 80)

if __name__ == '__main__':
    run_audit()
