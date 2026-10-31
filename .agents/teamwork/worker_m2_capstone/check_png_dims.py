import os
import struct

diagram_dir = r"c:\Users\Admin\AndroidStudioProjects\class_realm01\docs\diagrams"
files = [
    "figure1_ipso_diagram.png",
    "figure2_ipo_diagram.png",
    "figure3_agile_scrum_framework.png",
    "figure5_context_diagram.png"
]

for f in files:
    path = os.path.join(diagram_dir, f)
    if os.path.exists(path):
        size = os.path.getsize(path)
        with open(path, 'rb') as fp:
            data = fp.read(32)
            # PNG signature is 8 bytes, IHDR chunk starts at byte 12, width at 16, height at 20
            w, h = struct.unpack(">II", data[16:24])
            print(f"{f}: {w}x{h} px, {size} bytes, aspect_ratio={w/h:.3f}")
    else:
        print(f"{f}: NOT FOUND")
