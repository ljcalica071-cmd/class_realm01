import docx
from docx.oxml.ns import qn

DOCX_PATH = r"c:\Users\Admin\AndroidStudioProjects\class_realm01\INTEGRATED_SENIOR_HIGH_SCHOOL_ATTENDANCE_CH1_CH2_CH3.docx"
doc = docx.Document(DOCX_PATH)

print("=== EXACT FORMATTING & PAGINATION SIMULATION ===")

sec = doc.sections[0]
top_margin_pt = sec.top_margin.pt
bottom_margin_pt = sec.bottom_margin.pt
left_margin_pt = sec.left_margin.pt
right_margin_pt = sec.right_margin.pt
page_height_pt = sec.page_height.pt
page_width_pt = sec.page_width.pt

printable_h = page_height_pt - top_margin_pt - bottom_margin_pt
printable_w = page_width_pt - left_margin_pt - right_margin_pt

print(f"Page size: {page_width_pt} x {page_height_pt} pt ({page_width_pt/72:.2f} x {page_height_pt/72:.2f} in)")
print(f"Margins (pt): Top={top_margin_pt:.1f}, Bottom={bottom_margin_pt:.1f}, Left={left_margin_pt:.1f}, Right={right_margin_pt:.1f}")
print(f"Printable area: {printable_w:.1f} pt wide x {printable_h:.1f} pt high")

# Check font, line spacing, space before/after for every paragraph from 0 to 100
page = 1
current_y = 0.0

print(f"\n--- Page {page} (Title Page) ---")

for idx in range(0, 101):
    p = doc.paragraphs[idx]
    txt = p.text.strip()
    
    # Check if explicit page break before this or inside this
    has_page_br = any(br.get(qn('w:type')) == 'page' for br in p._p.findall('.//' + qn('w:br')))
    
    # Line spacing
    ls = p.paragraph_format.line_spacing
    sb = p.paragraph_format.space_before.pt if p.paragraph_format.space_before else 0.0
    sa = p.paragraph_format.space_after.pt if p.paragraph_format.space_after else 0.0
    
    # Determine font size
    font_size = 12.0
    for r in p.runs:
        if r.font.size:
            font_size = r.font.size.pt
            break
            
    # In Word, 1.5 line spacing for 12pt font has line pitch of 18pt
    line_pitch = font_size * 1.5 if ls is None or ls == 1.5 else (font_size * ls if isinstance(ls, float) else 18.0)
    
    # Estimate number of lines in this paragraph
    # Average char width for Arial 12pt is ~5.5 pt. With printable_w = 396 pt, ~65 chars/line.
    if len(txt) == 0:
        lines = 1
    else:
        # Wrap calculation
        words = txt.split()
        cur_line_len = 0
        lines = 1
        for w in words:
            w_len = len(w) + 1
            if (cur_line_len + w_len) * (font_size * 0.48) > printable_w:
                lines += 1
                cur_line_len = w_len
            else:
                cur_line_len += w_len
                
    p_height = sb + (lines * line_pitch) + sa
    
    if current_y + p_height > printable_h and idx > 0 and not (page == 1 and idx < 27):
        page += 1
        current_y = 0.0
        print(f"--- Page {page} --- (Triggered by P{idx}: '{txt[:35]}...')")
        
    current_y += p_height
    
    if has_page_br:
        print(f"  [Explicit Page Break at P{idx}]")
        page += 1
        current_y = 0.0
        print(f"--- Page {page} ---")

print(f"\nTotal estimated pages for Title Page + Chapter 1: {page} pages!")
