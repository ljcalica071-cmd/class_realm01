import os
from PIL import Image

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
        with Image.open(path) as img:
            print(f"{f}: size={img.size}, dpi={img.info.get('dpi', 'No DPI')}")
    else:
        print(f"{f}: NOT FOUND")
