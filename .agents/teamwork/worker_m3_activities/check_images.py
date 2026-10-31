import os
from PIL import Image

diag_dir = r"c:\Users\Admin\AndroidStudioProjects\class_realm01\docs\diagrams"
for f in sorted(os.listdir(diag_dir)):
    if f.endswith('.png'):
        p = os.path.join(diag_dir, f)
        img = Image.open(p)
        w, h = img.size
        print(f"{f:35s} | {w:4d}x{h:4d} | ratio: {w/h:.2f} | {os.path.getsize(p)/1024:.1f} KB")
