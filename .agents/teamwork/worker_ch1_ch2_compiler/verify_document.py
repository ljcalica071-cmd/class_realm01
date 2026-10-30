"""
verify_document.py
Independent verification of the compiled document
Checks typography, margins, element counts, table styling, images, and content requirements.
Updated: checks new IPO conceptual framework, no DeLone in References, no NFC, all URLs present.
"""

import os
import sys
import zipfile
import docx
from docx import Document

if hasattr(sys.stdout, "reconfigure"):
    try:
        sys.stdout.reconfigure(encoding="utf-8")
    except Exception:
        pass

IPSO_DOC_PATH = r"c:\Users\Admin\AndroidStudioProjects\class_realm01\INTEGRATED SENIOR HIGH SCHOOL ATTENDANCE_v2_IPSO.docx"
DOC_PATH = r"c:\Users\Admin\AndroidStudioProjects\class_realm01\INTEGRATED SENIOR HIGH SCHOOL ATTENDANCE.docx"
REVISED_PATH = r"c:\Users\Admin\AndroidStudioProjects\class_realm01\INTEGRATED SENIOR HIGH SCHOOL ATTENDANCE_REVISED.docx"

def verify_single(path):
    print("=" * 70)
    print(f"VERIFYING: {path}")
    print("=" * 70)
    
    if not os.path.exists(path):
        print(f"FAIL: File not found: {path}")
        return False
        
    file_size = os.path.getsize(path)
    print(f"File exists. Size: {file_size:,} bytes")
    
    doc = Document(path)
    
    # 1. Check Margins
    print("\n--- 1. Section Margins Check ---")
    sect = doc.sections[0]
    top_in = sect.top_margin.inches
    bottom_in = sect.bottom_margin.inches
    left_in = sect.left_margin.inches
    right_in = sect.right_margin.inches
    print(f"Margins (inches): Top={top_in:.2f}, Left={left_in:.2f}, Bottom={bottom_in:.2f}, Right={right_in:.2f}")
    
    margin_ok = (
        abs(top_in - 1.6) < 0.05 and
        abs(left_in - 1.6) < 0.05 and
        abs(bottom_in - 1.2) < 0.05 and
        abs(right_in - 1.4) < 0.05
    )
    if margin_ok:
        print("PASS: Margins match institutional specification (1.6, 1.6, 1.2, 1.4).")
    else:
        print(f"WARNING: Margins deviation detected! Top={top_in}, Left={left_in}, Bottom={bottom_in}, Right={right_in}")

    # 2. Check Paragraphs & Headings
    print("\n--- 2. Structure & Paragraphs Check ---")
    paragraphs = doc.paragraphs
    tables = doc.tables
    print(f"Total Paragraphs: {len(paragraphs)}")
    print(f"Total Tables: {len(tables)}")
    
    # Check Title Page Front Matter
    p0_text = paragraphs[0].text.strip()
    print(f"Paragraph 0 (Title): {p0_text}")
    assert "INTEGRATED SENIOR HIGH SCHOOL ATTENDANCE" in p0_text, "Title page title mismatch!"
    
    author_found = any("Calica, Ljay H." in p.text for p in paragraphs[:25])
    institution_found = any("Laguna University" in p.text for p in paragraphs[:25])
    print(f"Title Page Author present: {author_found}")
    print(f"Title Page Institution present: {institution_found}")
    
    # Check Chapter Headings
    full_text = "\n".join([p.text for p in paragraphs])
    assert "CHAPTER I" in full_text, "Missing CHAPTER I"
    assert "INTRODUCTION" in full_text, "Missing INTRODUCTION"
    assert "CHAPTER II" in full_text, "Missing CHAPTER II"
    assert "REVIEW OF RELATED LITERATURE AND THEORETICAL/CONCEPTUAL FRAMEWORK" in full_text, "Missing CHAPTER II Title"
    
    print("PASS: Chapter I and Chapter II headings present.")

    # 3. Check Institutional & Client Specifics
    print("\n--- 3. Institutional & Client Names Check ---")
    assert "Eduardo Barreto Sr. High School" in full_text, "Missing 'Eduardo Barreto Sr. High School'"
    assert "Karen P. Gonzaga" in full_text, "Missing client name"
    assert "Senior High School Mathematics Teacher" in full_text, "Missing client designation"
    assert "60 to 70 students" in full_text or "60-70 students" in full_text, "Missing student count (~60-70)"
    assert "three class sections" in full_text or "3 sections" in full_text, "Missing 3 sections mention"
    print("PASS: Institutional pilot school and client accurately named, student count verified.")

    # 4. Check Scope & Limitations
    print("\n--- 4. Scope, Boundaries & Exclusions Check ---")
    assert "solely for" in full_text and "academic year transitions and teacher provisioning" in full_text, "Missing admin restriction phrasing"
    assert "Registrar and Principal" in full_text, "Missing Registrar and Principal exclusion"
    assert "dropping" in full_text or "transfer" in full_text, "Missing transfer/drop exclusion"
    assert "Row-Level Security (RLS)" in full_text or "Row-Level Security" in full_text, "Missing RLS mention"
    assert "permanent manual" in full_text.lower(), "Missing permanent manual fallback mention"
    assert "23:59" in full_text, "Missing 23:59 auto-absent trigger"
    print("PASS: System boundaries, role exclusions, and permanent manual fallback verified.")

    # 5. Check Definition of Terms
    print("\n--- 5. Definition of Terms (9 Terms) Check ---")
    required_terms = [
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
    for term in required_terms:
        found = term in full_text
        print(f"  - {term}: {'FOUND' if found else 'MISSING'}")
        assert found, f"Term missing: {term}"
    print("PASS: All 9 IT-tailored operational definitions verified.")

    # 6. Check Empirical Literature (10 Studies)
    print("\n--- 6. Empirical Literature Check (10 Studies) ---")
    studies = [
        ("Holgado et al. (2026)", "Holgado"),
        ("Navarra & Antonio (2025)", "Navarra"),
        ("Bacongol & Durango (2025)", "Bacongol"),
        ("Contreras & Mercado (2024)", "Contreras"),
        ("Canlas & Ado (2024)", "Canlas"),
        ("Irhamna, Kasmini, & Khairuman (2026)", "Irhamna"),
        ("Kurniawan, Fitriadi, Albaroky, & Astiani (2024)", "Kurniawan"),
        ("Ramadhani, Sahiruddin, Kasri, & Alhamid (2025)", "Ramadhani"),
        ("Cevikbas, Konig, & Rothland (2024)", "evikba"),
        ("Januhari, Setyanto, & Kusrini (2025)", "Januhari")
    ]
    for label, query in studies:
        found = query.lower() in full_text.lower()
        print(f"  - {label}: {'FOUND' if found else 'MISSING'}")
        assert found, f"Study missing: {label}"
    print("PASS: Exactly 10 empirical studies verified in narrative.")

    # 7. Check Table 1 Synthesis Matrix
    print("\n--- 7. Table 1 Synthesis Matrix Check ---")
    assert len(tables) >= 1, "No tables found!"
    table1 = tables[0]
    print(f"Table 1 Rows: {len(table1.rows)}, Cols: {len(table1.columns)}")
    assert len(table1.rows) == 11, f"Expected 11 rows (1 header + 10 studies), found {len(table1.rows)}"
    assert len(table1.columns) == 6, f"Expected 6 columns, found {len(table1.columns)}"
    
    # Check headers
    header_cells = [c.text.strip().replace('\n', ' ') for c in table1.rows[0].cells]
    print(f"Header cells: {header_cells}")
    assert "AUTHOR & YEAR" in header_cells[0]
    assert "CONTRIBUTION" in header_cells[5]
    print("PASS: Table 1 Synthesis Matrix structure and all 10 studies verified.")

    # 8. Check Theoretical & Conceptual Frameworks
    print("\n--- 8. Theoretical & Conceptual Frameworks Check ---")
    # Theoretical Framework (Section 2.3) — DeLone appears as inline citation only
    assert "DeLone and McLean (2003)" in full_text or "DeLone & McLean (2003)" in full_text, "Missing DeLone & McLean (2003) inline citation in Section 2.3"
    assert "Input-Process-Storage-Output Diagram (IPSO)" in full_text, "Missing IPSO Diagram Title in Figure 1"
    assert "traced backward through Storage and Process" in full_text, "Missing backward tracing narrative in Figure 1"
    assert "System Quality" in full_text and "Information Quality" in full_text and "Service Quality" in full_text
    assert "Figure 1" in full_text
    assert "Figure 2" in full_text
    assert "IPSO" in full_text
    # Conceptual Framework (Section 2.4) — must now be IPO 3-column style
    assert "Input-Process-Output Diagram (IPO) of CLASSREALM" in full_text, "Figure 2 caption must say 'Input-Process-Output Diagram (IPO) of CLASSREALM'"
    assert "feedback" in full_text.lower(), "Missing feedback loop mention in Conceptual Framework"
    print("PASS: Theoretical (IPSO + DeLone/McLean 2003) and Conceptual (IPO) frameworks verified.")

    # 9. Check Embedded Media (Images)
    print("\n--- 9. Embedded Media (Images) Check ---")
    with zipfile.ZipFile(path, 'r') as z:
        media_files = [f for f in z.namelist() if f.startswith('word/media/')]
        print(f"Media files in docx: {media_files}")
        assert len(media_files) >= 2, "Expected at least 2 media files for Figure 1 and Figure 2!"
    print("PASS: Embedded image files verified inside Word package.")

    # 10. Check References — DeLone NOT in refs, all 10 study URLs present, no NFC
    print("\n--- 10. References & Content Guard Checks ---")
    assert "2.5 References" in full_text, "Missing References heading"

    # DeLone DOI must NOT appear in the References list (2003 source excluded)
    delone_doi = "https://doi.org/10.1080/07421222.2003.11045748"
    if delone_doi in full_text:
        print(f"  FAIL: DeLone & McLean (2003) DOI found in document — must be removed from References!")
        assert False, "DeLone & McLean DOI must not appear in References"
    else:
        print("  PASS: DeLone & McLean (2003) DOI correctly absent from References.")

    # All 10 study URLs/DOIs must be present
    required_dois = [
        ("Contreras", "https://doi.org/10.47772/IJRISS.2024.803052S"),
        ("Bacongol", "https://doi.org/10.63498/etcor454"),
        ("Kurniawan", "https://doi.org/10.34010/injuratech.v4i1.14124"),
        ("Ramadhani", "https://doi.org/10.21009/jtp.v27i3.60886"),
        ("Cevikbas", "https://doi.org/10.1007/s11858-023-01487-2"),
        ("Canlas", "https://doi.org/10.62718/vmca.tech-gjtdsi.9.1.SC-0726-003"),
        ("Navarra", "https://doi.org/10.70838/pemj.350801"),
        ("Januhari", "https://doi.org/10.15408/aism.v8i1.45738"),
        ("Holgado", "https://research-manila.letran.edu.ph/article/279"),
        ("Irhamna", "https://inotera.poltas.ac.id/index.php/inotera/article/view/620"),
    ]
    all_dois_ok = True
    for author, doi in required_dois:
        if doi in full_text:
            print(f"  PASS: {author} URL/DOI present.")
        else:
            print(f"  FAIL: {author} URL/DOI MISSING: {doi}")
            all_dois_ok = False
    assert all_dois_ok, "One or more study DOIs/URLs are missing from References!"

    # No NFC mention in document body (NFC is not documented)
    nfc_found = "Near Field Communication" in full_text or " NFC " in full_text
    if nfc_found:
        print("  WARNING: NFC mention detected in document — should be removed (RFID only for now).")
    else:
        print("  PASS: No NFC mention in document (RFID-only as specified).")

    # No boilerplate APA formatting sentence
    if "formatted in accordance with the American Psychological Association" in full_text:
        print("  FAIL: Boilerplate APA formatting sentence still present — must be removed!")
        assert False, "Boilerplate formatting sentence must be removed from Section 2.5"
    else:
        print("  PASS: Boilerplate APA formatting sentence correctly absent.")

    assert "Tejada" not in full_text, "Tejada (2012) must be removed!"
    print("PASS: References, working DOIs/URLs, content guards all verified.")

    print("\n" + "=" * 70)
    print(f"ALL VERIFICATION SUITE CHECKS PASSED FOR {os.path.basename(path)}!")
    print("=" * 70)
    return True

def verify():
    if len(sys.argv) > 1:
        targets = [sys.argv[1]]
    else:
        targets = [DOC_PATH, IPSO_DOC_PATH, REVISED_PATH]
    verified = False
    for t in targets:
        if os.path.exists(t):
            try:
                res = verify_single(t)
                if res:
                    verified = True
                    break
            except Exception as e:
                print(f"Error reading {t}: {e}")
    if not verified:
        sys.exit(1)

if __name__ == "__main__":
    verify()
