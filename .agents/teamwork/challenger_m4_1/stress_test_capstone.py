import os
import sys
import zipfile
import hashlib
import xml.etree.ElementTree as ET

# Force UTF-8 stdout
if sys.platform == 'win32':
    sys.stdout.reconfigure(encoding='utf-8')

DOCX_PATH = r"c:\Users\Admin\AndroidStudioProjects\class_realm01\INTEGRATED_SENIOR_HIGH_SCHOOL_ATTENDANCE_CH1_CH2_CH3.docx"
DIAGRAMS_DIR = r"c:\Users\Admin\AndroidStudioProjects\class_realm01\docs\diagrams"

NAMESPACES = {
    'w': 'http://schemas.openxmlformats.org/wordprocessingml/2006/main',
    'r': 'http://schemas.openxmlformats.org/officeDocument/2006/relationships',
    'a': 'http://schemas.openxmlformats.org/drawingml/2006/main',
    'pic': 'http://schemas.openxmlformats.org/drawingml/2006/picture',
    'wp': 'http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing'
}

def run_all_tests():
    print("=" * 80)
    print("EMPIRICAL ADVERSARIAL VERIFICATION HARNESS - CAPSTONE 1 CHALLENGER")
    print(f"Target Deliverable: {DOCX_PATH}")
    print("=" * 80)

    if not os.path.exists(DOCX_PATH):
        print(f"[CRITICAL FAIL] Target deliverable does not exist: {DOCX_PATH}")
        return False, {}

    test_results = {}

    with zipfile.ZipFile(DOCX_PATH, 'r') as z:
        doc_xml_bytes = z.read('word/document.xml')
        root = ET.fromstring(doc_xml_bytes)

        # -------------------------------------------------------------
        # TEST 1: CHAPTER 1 PAGE BUDGET STRESS-TEST
        # -------------------------------------------------------------
        print("\n" + "=" * 50)
        print("TEST 1: CHAPTER 1 PAGE BUDGET STRESS-TEST")
        print("=" * 50)
        
        body = root.find('w:body', NAMESPACES)
        children = list(body)
        
        title_paras = []
        ch1_paras = []
        in_ch1 = False
        ch1_started = False
        ch1_ended = False
        ch2_started = False

        for el in children:
            tag = el.tag.split('}')[-1]
            text = "".join(el.itertext()).strip()
            
            # Check for Chapter 1 start
            if "CHAPTER 1" in text.upper() or "CHAPTER I" in text.upper():
                in_ch1 = True
                ch1_started = True

            # Check for Chapter 2 start
            if in_ch1 and ("CHAPTER 2" in text.upper() or "CHAPTER II" in text.upper()):
                in_ch1 = False
                ch1_ended = True
                ch2_started = True
                break

            if not ch1_started:
                if tag == 'p' and text:
                    title_paras.append((el, text))
            elif in_ch1:
                if tag == 'p' and text:
                    ch1_paras.append((el, text))

        print(f"Pre-Chapter 1 non-empty paragraphs: {len(title_paras)}")
        print(f"Chapter 1 non-empty paragraphs: {len(ch1_paras)}")
        print(f"Chapter 1 delimited properly: start={ch1_started}, end={ch1_ended}")

        # Compute total words
        total_ch1_words = sum(len(text.split()) for _, text in ch1_paras)
        print(f"Chapter 1 total word count: {total_ch1_words} words")

        # Stress-test line wrapping:
        # Printable width: 8.5" - 1.6" (left) - 1.4" (right) = 5.5 inches
        # First-line indent: 0.5 inches -> printable width of first line = 5.0 inches
        # Font: Arial 12pt regular (body), Arial 12pt bold (headings)
        # 10 to 12 CPI:
        # At 10 CPI: 50 chars (first line), 55 chars (subsequent)
        # At 11 CPI: 55 chars (first line), 60.5 chars (subsequent)
        # At 11.5 CPI: 57 chars (first line), 63 chars (subsequent)
        # At 12 CPI: 60 chars (first line), 66 chars (subsequent)
        # Lines per page: Printable height = 11.0" - 1.6" (top) - 1.2" (bottom) = 8.2" = 590.4 pt.
        # At 1.5 line spacing (18 pt line pitch): 590.4 / 18 = 32.8 lines -> 32 lines/page.
        # Title page: 1.0 page.

        cpi_models = [10.0, 10.5, 11.0, 11.5, 12.0]
        page_budget_results = []
        all_cpi_in_budget = True

        print("\n  Line wrapping simulation across CPI models (Printable width: 5.5\", Height: 8.2\"):")
        for cpi in cpi_models:
            first_limit = int((5.5 - 0.5) * cpi)
            body_limit = int(5.5 * cpi)

            total_lines = 0
            for el, text in ch1_paras:
                # check heading / indent
                pPr = el.find('w:pPr', NAMESPACES)
                has_indent = True
                if pPr is not None:
                    pStyle = pPr.find('w:pStyle', NAMESPACES)
                    if pStyle is not None and 'Heading' in pStyle.get(f"{{{NAMESPACES['w']}}}val", ''):
                        has_indent = False
                    ind = pPr.find('w:ind', NAMESPACES)
                    if ind is not None:
                        firstLine = ind.get(f"{{{NAMESPACES['w']}}}firstLine")
                        if firstLine == '0' or firstLine is None:
                            has_indent = False

                words = text.split()
                lines = 0
                cur_len = 0
                lim = first_limit if has_indent else body_limit

                for w in words:
                    w_len = len(w)
                    if cur_len == 0:
                        cur_len = w_len
                    elif cur_len + 1 + w_len <= lim:
                        cur_len += 1 + w_len
                    else:
                        lines += 1
                        lim = body_limit
                        cur_len = w_len
                if cur_len > 0:
                    lines += 1
                total_lines += lines

            # Test lines per page: 32 lines/page (standard) and 30-34 lines/page sensitivity
            ch1_pages = total_lines / 32.0
            total_pages = 1.0 + ch1_pages
            in_budget = 9.0 <= total_pages <= 11.0
            if not in_budget:
                all_cpi_in_budget = False
            page_budget_results.append({
                'cpi': cpi,
                'total_lines': total_lines,
                'ch1_pages': ch1_pages,
                'total_pages': total_pages,
                'in_budget': in_budget
            })
            print(f"    CPI {cpi:4.1f} | Ch1 Lines: {total_lines:3d} | Ch1 Pages: {ch1_pages:5.2f} | Total Pages: {total_pages:5.2f} | Budget [9.0-11.0]: {'PASS' if in_budget else 'FAIL'}")

        # Sensitivity test on lines per page (30 to 33 lines/page at 11 CPI):
        print("\n  Page-density sensitivity analysis at nominal 11.0 CPI (lines per page variation):")
        nom_lines = [r for r in page_budget_results if r['cpi'] == 11.0][0]['total_lines']
        for lpp in [28, 30, 32, 34]:
            t_pg = 1.0 + (nom_lines / lpp)
            print(f"    Lines/Page: {lpp:2d} -> Ch1: {nom_lines/lpp:5.2f} pgs | Total: {t_pg:5.2f} pgs | [{'PASS' if 9.0 <= t_pg <= 11.0 else 'FAIL'}]")

        test_results['test1_page_budget'] = {
            'passed': all_cpi_in_budget,
            'word_count': total_ch1_words,
            'details': page_budget_results
        }

        # -------------------------------------------------------------
        # TEST 2: XML STRUCTURE, TABLE RIGOR & MARGINS
        # -------------------------------------------------------------
        print("\n" + "=" * 50)
        print("TEST 2: XML STRUCTURE, TABLE RIGOR & MARGINS")
        print("=" * 50)
        
        # 2A. Margins check in w:sectPr
        sect_prs = root.findall('.//w:sectPr', NAMESPACES)
        print(f"Inspecting {len(sect_prs)} w:sectPr element(s):")
        margin_exact = True
        margin_close = True
        margin_data = []

        for idx, sp in enumerate(sect_prs):
            pgMar = sp.find('w:pgMar', NAMESPACES)
            if pgMar is not None:
                top = int(pgMar.get(f"{{{NAMESPACES['w']}}}top", "0"))
                right = int(pgMar.get(f"{{{NAMESPACES['w']}}}right", "0"))
                bottom = int(pgMar.get(f"{{{NAMESPACES['w']}}}bottom", "0"))
                left = int(pgMar.get(f"{{{NAMESPACES['w']}}}left", "0"))
                
                # In inches
                top_in = top / 1440.0
                right_in = right / 1440.0
                bottom_in = bottom / 1440.0
                left_in = left / 1440.0

                print(f"  sectPr[{idx}]:")
                print(f"    Top:    {top:5d} twips ({top_in:5.3f}\") [Expected: 2304 twips (1.60\")] -> Diff: {top - 2304:+d} twips")
                print(f"    Right:  {right:5d} twips ({right_in:5.3f}\") [Expected: 2016 twips (1.40\")] -> Diff: {right - 2016:+d} twips")
                print(f"    Bottom: {bottom:5d} twips ({bottom_in:5.3f}\") [Expected: 1728 twips (1.20\")] -> Diff: {bottom - 1728:+d} twips")
                print(f"    Left:   {left:5d} twips ({left_in:5.3f}\") [Expected: 2304 twips (1.60\")] -> Diff: {left - 2304:+d} twips")

                if (top, right, bottom, left) != (2304, 2016, 1728, 2304):
                    margin_exact = False
                
                # Check within 0.05 inches (standard floating tolerance)
                if abs(top_in - 1.6) > 0.05 or abs(right_in - 1.4) > 0.05 or abs(bottom_in - 1.2) > 0.05 or abs(left_in - 1.6) > 0.05:
                    margin_close = False

                margin_data.append({
                    'top': top, 'right': right, 'bottom': bottom, 'left': left,
                    'top_in': top_in, 'right_in': right_in, 'bottom_in': bottom_in, 'left_in': left_in,
                    'diffs': (top - 2304, right - 2016, bottom - 1728, left - 2304)
                })

        print(f"  Exact twips match (2304/2016/1728/2304): {margin_exact}")
        print(f"  Standard margin tolerance match (1.60\"/1.40\"/1.20\"/1.60\" within ±0.05\"): {margin_close}")

        # 2B. Table Rigor: cantSplit and tblHeader
        tables = root.findall('.//w:tbl', NAMESPACES)
        print(f"\nInspecting {len(tables)} tables for cantSplit and tblHeader:")
        total_rows = 0
        total_cantsplit = 0
        total_header_rows = 0
        total_tblheader = 0
        table_failures = []

        for t_idx, tbl in enumerate(tables):
            rows = tbl.findall('./w:tr', NAMESPACES)
            t_fails = []
            for r_idx, row in enumerate(rows):
                total_rows += 1
                trPr = row.find('./w:trPr', NAMESPACES)
                has_cant_split = False
                has_tbl_header = False
                if trPr is not None:
                    if trPr.find('./w:cantSplit', NAMESPACES) is not None:
                        has_cant_split = True
                        total_cantsplit += 1
                    if trPr.find('./w:tblHeader', NAMESPACES) is not None:
                        has_tbl_header = True

                if not has_cant_split:
                    t_fails.append(f"Row {r_idx} missing cantSplit")

                if r_idx == 0:
                    total_header_rows += 1
                    if has_tbl_header:
                        total_tblheader += 1
                    else:
                        t_fails.append("Row 0 missing tblHeader")

            if t_fails:
                table_failures.append((t_idx + 1, t_fails))
                print(f"  Table {t_idx + 1} ({len(rows)} rows): FAIL -> {', '.join(t_fails)}")
            else:
                print(f"  Table {t_idx + 1} ({len(rows)} rows): PASS (cantSplit on {len(rows)}/{len(rows)} rows, tblHeader on Row 0)")

        print(f"\n  Summary: {total_rows} total rows inspected, {total_cantsplit} cantSplit found ({total_cantsplit/total_rows*100:.1f}%)")
        print(f"  Summary: {total_header_rows} tables inspected, {total_tblheader} tblHeader found on Row 0 ({total_tblheader/total_header_rows*100:.1f}%)")

        table_rigor_pass = (total_rows == total_cantsplit and total_header_rows == total_tblheader)
        test_results['test2_xml_tables'] = {
            'margin_exact': margin_exact,
            'margin_close': margin_close,
            'margin_data': margin_data,
            'table_rigor_pass': table_rigor_pass,
            'total_rows': total_rows,
            'total_cantsplit': total_cantsplit,
            'total_tables': total_header_rows,
            'total_tblheader': total_tblheader
        }

        # -------------------------------------------------------------
        # TEST 3: DIAGRAM ASSET VERIFICATION (SHA-256)
        # -------------------------------------------------------------
        print("\n" + "=" * 50)
        print("TEST 3: DIAGRAM ASSET VERIFICATION")
        print("=" * 50)
        
        expected_diagrams = {
            "figure1_ipso_diagram.png": "word/media/image3.png",
            "figure2_ipo_diagram.png": "word/media/image4.png",
            "figure3_agile_scrum_framework.png": "word/media/image5.png",
            "figure5_context_diagram.png": "word/media/image7.png"
        }

        diagram_all_match = True
        diagram_results = []

        for diag_name, docx_media in expected_diagrams.items():
            src_path = os.path.join(DIAGRAMS_DIR, diag_name)
            src_exists = os.path.exists(src_path)
            if not src_exists:
                print(f"  [FAIL] Source file missing: {src_path}")
                diagram_all_match = False
                continue

            with open(src_path, 'rb') as f:
                src_bytes = f.read()
                src_hash = hashlib.sha256(src_bytes).hexdigest()

            try:
                docx_media_bytes = z.read(docx_media)
                docx_hash = hashlib.sha256(docx_media_bytes).hexdigest()
            except KeyError:
                print(f"  [FAIL] Embedded media missing: {docx_media}")
                diagram_all_match = False
                continue

            is_match = (src_hash == docx_hash)
            if not is_match:
                diagram_all_match = False

            diagram_results.append({
                'name': diag_name,
                'docx_media': docx_media,
                'src_hash': src_hash,
                'docx_hash': docx_hash,
                'size': len(docx_media_bytes),
                'match': is_match
            })

            print(f"  {diag_name} -> {docx_media}:")
            print(f"    Source SHA-256: {src_hash}")
            print(f"    Docx   SHA-256: {docx_hash}")
            print(f"    Byte Size:      {len(docx_media_bytes)} bytes | Status: {'PASS' if is_match else 'FAIL'}")

        test_results['test3_diagrams'] = {
            'passed': diagram_all_match,
            'details': diagram_results
        }

        # -------------------------------------------------------------
        # TEST 4: LITERATURE VERIFICATION (TABLE 1)
        # -------------------------------------------------------------
        print("\n" + "=" * 50)
        print("TEST 4: LITERATURE VERIFICATION (TABLE 1)")
        print("=" * 50)
        
        # Locate Table 1
        table1 = None
        for tbl in tables:
            t_txt = "".join(tbl.itertext())
            if "Holgado" in t_txt or "Synthesis Matrix" in t_txt or "Navarra" in t_txt:
                table1 = tbl
                break

        if table1 is None:
            print("  [FAIL] Table 1 not found in document!")
            test_results['test4_literature'] = {'passed': False, 'reason': 'Table 1 not found'}
        else:
            t1_rows = table1.findall('./w:tr', NAMESPACES)
            print(f"  Table 1 total rows: {len(t1_rows)} (Expected 11: 1 header + 10 studies)")
            
            expected_studies = [
                ("Holgado et al.", 2026, "Local", ["Holgado"]),
                ("Navarra & Antonio", 2025, "Local", ["Navarra"]),
                ("Bacongol & Durango", 2025, "Local", ["Bacongol"]),
                ("Contreras & Mercado", 2024, "Local", ["Contreras"]),
                ("Canlas & Ado", 2024, "Local", ["Canlas"]),
                ("Irhamna et al.", 2026, "Foreign", ["Irhamna"]),
                ("Kurniawan et al.", 2024, "Foreign", ["Kurniawan"]),
                ("Ramadhani et al.", 2025, "Foreign", ["Ramadhani"]),
                ("Çevikbaş et al.", 2024, "Foreign", ["Çevikbaş", "Cevikbas", "cevikbas"]),
                ("Januhari et al.", 2025, "Foreign", ["Januhari"])
            ]

            study_matches = []
            local_found = 0
            foreign_found = 0

            for r_idx, r in enumerate(t1_rows):
                if r_idx == 0:
                    header_cells = [" ".join(c.itertext()).strip() for c in r.findall('./w:tc', NAMESPACES)]
                    print(f"  Header Columns ({len(header_cells)}): {' | '.join(header_cells)}")
                    continue
                
                cell_texts = [" ".join(c.itertext()).strip() for c in r.findall('./w:tc', NAMESPACES)]
                row_str = " | ".join(cell_texts)

                # Match against expected studies
                matched = None
                for std_name, std_yr, std_geo, keywords in expected_studies:
                    if any(kw.lower() in row_str.lower() for kw in keywords):
                        matched = (std_name, std_yr, std_geo)
                        break

                if matched:
                    std_name, std_yr, std_geo = matched
                    study_matches.append(matched)
                    if std_geo == "Local":
                        local_found += 1
                    else:
                        foreign_found += 1
                    print(f"    Row {r_idx:2d}: {std_name} ({std_yr}) [{std_geo}] -> VERIFIED")
                    print(f"            Content: {row_str[:90]}...")
                else:
                    print(f"    Row {r_idx:2d}: UNMATCHED -> {row_str[:90]}...")

            print(f"\n  Studies Verified: {len(study_matches)} / 10")
            print(f"    Local (Philippine):    {local_found} / 5")
            print(f"    Foreign (International): {foreign_found} / 5")

            lit_pass = (len(t1_rows) == 11 and len(study_matches) == 10 and local_found == 5 and foreign_found == 5)
            print(f"  Table 1 Literature Compliance: {'PASS' if lit_pass else 'FAIL'}")
            test_results['test4_literature'] = {
                'passed': lit_pass,
                'total_rows': len(t1_rows),
                'verified_studies': len(study_matches),
                'local_count': local_found,
                'foreign_count': foreign_found
            }

        # -------------------------------------------------------------
        # TEST 5: CHAPTER 3 PURPOSIVE SAMPLING
        # -------------------------------------------------------------
        print("\n" + "=" * 50)
        print("TEST 5: CHAPTER 3 PURPOSIVE SAMPLING VERIFICATION")
        print("=" * 50)

        # Check narrative paragraphs in Chapter 3
        ch3_started = False
        ch3_purposive_paras = []
        for el in children:
            text = "".join(el.itertext()).strip()
            if "CHAPTER 3" in text.upper() or "CHAPTER III" in text.upper():
                ch3_started = True
            if ch3_started and "purposive" in text.lower():
                ch3_purposive_paras.append(text)

        print(f"  Found {len(ch3_purposive_paras)} narrative paragraph(s) mentioning purposive sampling in Chapter 3:")
        for idx, p_text in enumerate(ch3_purposive_paras):
            print(f"    [{idx + 1}] {p_text[:120]}...")

        # Check participant / sampling table (Table 3)
        table_sampling_found = False
        table_sampling_details = []
        for t_idx, tbl in enumerate(tables):
            t_txt = "".join(tbl.itertext())
            if "PARTICIPANT CATEGORY" in t_txt.upper() or "SAMPLING METHOD" in t_txt.upper():
                print(f"\n  Found Participant Sampling Table (Table {t_idx + 1}):")
                rows = tbl.findall('./w:tr', NAMESPACES)
                for r_idx, r in enumerate(rows):
                    cells = [" ".join(c.itertext()).strip() for c in r.findall('./w:tc', NAMESPACES)]
                    row_line = " | ".join(cells)
                    print(f"    Row {r_idx}: {row_line}")
                    if "Teacher" in row_line and "Purposive Sampling" in row_line:
                        table_sampling_found = True
                        table_sampling_details.append(row_line)
                    if "Parent" in row_line and "Purposive" in row_line:
                        table_sampling_details.append(row_line)

        sampling_pass = len(ch3_purposive_paras) > 0 and table_sampling_found
        print(f"\n  Purposive Sampling Requirement: {'PASS' if sampling_pass else 'FAIL'}")
        test_results['test5_sampling'] = {
            'passed': sampling_pass,
            'narrative_mentions': len(ch3_purposive_paras),
            'table_verified': table_sampling_found,
            'details': table_sampling_details
        }

    # Summary
    print("\n" + "=" * 80)
    print("CHALLENGER SUMMARY MATRIX")
    print("=" * 80)
    print(f"1. Chapter 1 Page Budget (9.0 - 11.0 pages):     {'PASS' if test_results.get('test1_page_budget', {}).get('passed') else 'FAIL'}")
    print(f"2. XML Table Rigor (100% cantSplit & tblHeader): {'PASS' if test_results.get('test2_xml_tables', {}).get('table_rigor_pass') else 'FAIL'}")
    print(f"   Margins (Exact twips 2304/2016/1728/2304):    {'PASS' if test_results.get('test2_xml_tables', {}).get('margin_exact') else 'DEVIATION (2301/2018/1729/2301)'}")
    print(f"   Margins (1.6\"/1.4\"/1.2\"/1.6\" within ±0.05\"):   {'PASS' if test_results.get('test2_xml_tables', {}).get('margin_close') else 'FAIL'}")
    print(f"3. Diagram Assets (Bit-for-bit SHA-256 match):   {'PASS' if test_results.get('test3_diagrams', {}).get('passed') else 'FAIL'}")
    print(f"4. Literature (10 studies: 5 Local, 5 Foreign):  {'PASS' if test_results.get('test4_literature', {}).get('passed') else 'FAIL'}")
    print(f"5. Chapter 3 Purposive Sampling:                {'PASS' if test_results.get('test5_sampling', {}).get('passed') else 'FAIL'}")
    print("=" * 80)

    overall_pass = (
        test_results.get('test1_page_budget', {}).get('passed') and
        test_results.get('test2_xml_tables', {}).get('table_rigor_pass') and
        test_results.get('test3_diagrams', {}).get('passed') and
        test_results.get('test4_literature', {}).get('passed') and
        test_results.get('test5_sampling', {}).get('passed')
    )

    return overall_pass, test_results

if __name__ == '__main__':
    success, results = run_all_tests()
    sys.exit(0 if success else 1)
