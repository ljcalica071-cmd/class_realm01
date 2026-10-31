import os
import sys
import zipfile
import hashlib
import xml.etree.ElementTree as ET
from PIL import Image

REPO_ROOT = r"c:\Users\Admin\AndroidStudioProjects\class_realm01"
CH1_CH3_DOCX = os.path.join(REPO_ROOT, "INTEGRATED_SENIOR_HIGH_SCHOOL_ATTENDANCE_CH1_CH2_CH3.docx")
ACTIVITIES_DOCX = os.path.join(REPO_ROOT, "CLASSREALM_Activities_2_and_4.docx")
DIAGRAMS_DIR = os.path.join(REPO_ROOT, "docs", "diagrams")

W_NS = "http://schemas.openxmlformats.org/wordprocessingml/2006/main"
A_NS = "http://schemas.openxmlformats.org/drawingml/2006/main"
R_NS = "http://schemas.openxmlformats.org/officeDocument/2006/relationships"

def get_xml_text(element):
    return "".join(element.itertext())

def check_docx_integrity(docx_path, name):
    print(f"\n==================================================")
    print(f"CHECKING INTEGRITY OF: {name}")
    print(f"Path: {docx_path}")
    print(f"==================================================")
    
    if not os.path.exists(docx_path):
        print(f"[FAIL] File does not exist!")
        return None
        
    size = os.path.getsize(docx_path)
    print(f"[PASS] File exists. Size: {size} bytes ({size / (1024*1024):.2f} MB)")
    
    try:
        zf = zipfile.ZipFile(docx_path, 'r')
    except Exception as e:
        print(f"[FAIL] Not a valid ZIP / DOCX archive: {e}")
        return None
        
    infolist = zf.infolist()
    filenames = [info.filename for info in infolist]
    
    required_files = ["word/document.xml", "[Content_Types].xml", "word/_rels/document.xml.rels"]
    for req in required_files:
        if req in filenames:
            print(f"[PASS] Contains required entry: {req}")
        else:
            print(f"[FAIL] Missing required entry: {req}")
            return None
            
    doc_xml_bytes = zf.read("word/document.xml")
    root = ET.fromstring(doc_xml_bytes)
    
    # Extract all text
    paragraphs = []
    for p in root.iter(f"{{{W_NS}}}p"):
        p_text = get_xml_text(p).strip()
        if p_text:
            paragraphs.append(p_text)
            
    table_texts = []
    for t in root.iter(f"{{{W_NS}}}tbl"):
        for r in t.iter(f"{{{W_NS}}}tr"):
            row_cells = [get_xml_text(c).strip() for c in r.iter(f"{{{W_NS}}}tc")]
            table_texts.append(" | ".join(row_cells))
            
    total_text = "\n".join(paragraphs) + "\n" + "\n".join(table_texts)
    total_words = len(total_text.split())
    
    print(f"Total non-empty paragraphs: {len(paragraphs)}")
    print(f"Total table rows: {len(table_texts)}")
    print(f"Total word count: {total_words}")
    
    # Placeholder detection
    prohibited_placeholders = [
        "lorem ipsum", "[todo]", "todo:", "tbd", "[tbd]", "placeholder", 
        "dummy text", "insert here", "fixme", "to be determined"
    ]
    found_placeholders = []
    for line in paragraphs + table_texts:
        line_lower = line.lower()
        for ph in prohibited_placeholders:
            if ph in line_lower:
                # check false positives like 'et al.' or valid words
                found_placeholders.append((ph, line[:100]))
                
    if found_placeholders:
        print(f"[FAIL] Found {len(found_placeholders)} prohibited placeholders:")
        for ph, snippet in found_placeholders[:10]:
            print(f"   - '{ph}': {snippet}")
    else:
        print(f"[PASS] Zero prohibited placeholders found in document text.")
        
    # Extract embedded media
    media_files = [f for f in filenames if f.startswith("word/media/")]
    print(f"Embedded media files count: {len(media_files)}")
    media_hashes = {}
    for m in media_files:
        m_bytes = zf.read(m)
        m_hash = hashlib.sha256(m_bytes).hexdigest()
        media_hashes[m] = (m_hash, len(m_bytes))
        
    zf.close()
    return {
        "size": size,
        "paragraphs": paragraphs,
        "total_words": total_words,
        "media_hashes": media_hashes,
        "total_text": total_text
    }

def main():
    print("STARTING FORENSIC INTEGRITY AUDIT...")
    ch_info = check_docx_integrity(CH1_CH3_DOCX, "Capstone 1 (Chapters 1-3)")
    act_info = check_docx_integrity(ACTIVITIES_DOCX, "Consolidated Activities (2 & 4)")
    
    # Check diagrams in docs/diagrams
    print(f"\n==================================================")
    print("CHECKING DIAGRAM INTEGRITY IN docs/diagrams/")
    print(f"==================================================")
    
    diagram_files = [f for f in os.listdir(DIAGRAMS_DIR) if f.endswith(".png")]
    print(f"Found {len(diagram_files)} diagram PNG files in {DIAGRAMS_DIR}:")
    diagram_hashes = {}
    for df in sorted(diagram_files):
        df_path = os.path.join(DIAGRAMS_DIR, df)
        df_bytes = open(df_path, "rb").read()
        df_hash = hashlib.sha256(df_bytes).hexdigest()
        img = Image.open(df_path)
        dpi = img.info.get('dpi', (72, 72))
        print(f"  - {df}: {img.width}x{img.height} px, {len(df_bytes)/1024:.1f} KB, DPI={dpi}, SHA256={df_hash[:16]}...")
        diagram_hashes[df] = (df_hash, len(df_bytes), img.width, img.height, dpi)
        
    # Verify embedded diagram matching
    print(f"\n--- Checking Embedded Diagrams in Capstone 1 ---")
    matched_ch = 0
    for m, (m_hash, m_size) in ch_info["media_hashes"].items():
        matched_df = [df for df, (dh, ds, w, h, dpi) in diagram_hashes.items() if dh == m_hash]
        if matched_df:
            print(f"  [MATCH] {m} ({m_size} bytes) matches {matched_df[0]}")
            matched_ch += 1
        else:
            print(f"  [INFO] {m} ({m_size} bytes) is non-diagram media (e.g. logos: LU/CCS)")
    print(f"Total matched diagrams in Capstone 1: {matched_ch} (Expected: 4 - Figures 1, 2, 3, 5)")
    
    print(f"\n--- Checking Embedded Diagrams in Activities 2 & 4 ---")
    matched_act = 0
    for m, (m_hash, m_size) in act_info["media_hashes"].items():
        matched_df = [df for df, (dh, ds, w, h, dpi) in diagram_hashes.items() if dh == m_hash]
        if matched_df:
            print(f"  [MATCH] {m} ({m_size} bytes) matches {matched_df[0]}")
            matched_act += 1
        else:
            print(f"  [UNKNOWN] {m} does not match any diagram in docs/diagrams/")
    print(f"Total matched diagrams in Activities: {matched_act} (Expected: 10)")
    
    # Check Architecture & Tech Stack Authenticity
    print(f"\n==================================================")
    print("CHECKING ARCHITECTURE & TECH STACK AUTHENTICITY")
    print(f"==================================================")
    required_keywords = [
        ("Drift", "Drift ORM"),
        ("SQLite", "SQLite local DB"),
        ("OfflineSyncQueue", "OfflineSyncQueue buffer"),
        ("SyncCoordinator", "SyncCoordinator (45s sync)"),
        ("ESP32", "ESP32 DevKit V1"),
        ("RC522", "RC522 13.56 MHz RFID module"),
        ("LittleFS", "LittleFS flash buffer"),
        ("attendance_queue.jsonl", "Spool queue file"),
        ("FreeRTOS", "FreeRTOS task segregation"),
        ("Supabase", "Supabase PostgreSQL backend"),
        ("Row-Level Security", "Row-Level Security (RLS)"),
        ("Firebase Authentication", "Firebase Authentication identity platform"),
        ("Admin", "Admin role"),
        ("Teacher", "Teacher role"),
        ("Student", "Student role"),
        ("Parent", "Parent role"),
        ("Ma'am Karen P. Gonzaga", "Client Teacher"),
        ("Eduardo Barretto", "Pilot School")
    ]
    
    print(f"\n--- Checking Keywords in Capstone 1 ---")
    ch_text = ch_info["total_text"]
    for kw, label in required_keywords:
        cnt = ch_text.count(kw)
        if cnt > 0:
            print(f"  [PASS] {label} ('{kw}'): {cnt} occurrences")
        else:
            print(f"  [FAIL] {label} ('{kw}'): MISSING!")
            
    print(f"\n--- Checking Keywords in Activities 2 & 4 ---")
    act_text = act_info["total_text"]
    for kw, label in required_keywords:
        cnt = act_text.count(kw)
        if cnt > 0:
            print(f"  [PASS] {label} ('{kw}'): {cnt} occurrences")
        else:
            print(f"  [FAIL] {label} ('{kw}'): MISSING!")
            
    # Check Classmate Leakage in Activities 2 & 4
    print(f"\n==================================================")
    print("CHECKING CLASSMATE LEAKAGE IN ACTIVITIES")
    print(f"==================================================")
    leakage_terms = ["cashier", "gcash", "tuition fee", "omr paper", "moj integrated", "moj catholic"]
    leak_found = False
    for lt in leakage_terms:
        cnt = act_text.lower().count(lt)
        if cnt > 0:
            print(f"  [FAIL] Leakage term '{lt}' FOUND ({cnt} occurrences)!")
            leak_found = True
        else:
            print(f"  [PASS] Leakage term '{lt}': 0 occurrences")
            
    if not leak_found:
        print("[PASS] Zero classmate artifact leakage detected.")
        
if __name__ == "__main__":
    main()
