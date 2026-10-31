import os
import struct
import sys

sys.stdout.reconfigure(encoding='utf-8', errors='replace')

DIAGRAM_DIR = r"c:\Users\Admin\AndroidStudioProjects\class_realm01\docs\diagrams"

def get_png_dimensions(file_path):
    with open(file_path, 'rb') as f:
        data = f.read(24)
        if data[:8] == b'\x89PNG\r\n\x1a\n':
            w, h = struct.unpack('>LL', data[16:24])
            return w, h
    return None, None

files = os.listdir(DIAGRAM_DIR)
png_files = [f for f in files if f.endswith('.png')]

print(f"=== AUDITING DIAGRAMS IN {DIAGRAM_DIR} ===")
print(f"Total PNG files: {len(png_files)}")

for f_name in sorted(png_files):
    f_path = os.path.join(DIAGRAM_DIR, f_name)
    size = os.path.getsize(f_path)
    w, h = get_png_dimensions(f_path)
    print(f"{f_name:35s} | {size:8,d} bytes | {w:4d} x {h:4d} px")

# Check if required 14 diagrams are present
required = [
    'activity2_dfd_level0.png',
    'activity2_dfd_level1_overview.png',
    'activity2_dfd_level1_proc1.png',
    'activity2_dfd_level1_proc2.png',
    'activity2_dfd_level1_proc3.png',
    'activity2_dfd_level1_proc4.png',
    'activity4_class_diagram.png',
    'activity4_erd.png',
    'activity4_object_diagram.png',
    'activity4_use_case.png',
    'figure1_ipso_diagram.png',
    'figure2_ipo_diagram.png',
    'figure3_agile_scrum_framework.png',
    'figure5_context_diagram.png'
]

missing = [r for r in required if r not in png_files]
print("\nMissing required diagrams:", missing if missing else "None! All 14 present!")
