import sys
import PIL
from PIL import Image, ImageDraw, ImageFont

print(f"Python: {sys.version}")
print(f"Pillow: {PIL.__version__}")

# Test font loading
font_paths = [
    "C:/Windows/Fonts/segoeui.ttf",
    "C:/Windows/Fonts/segoeuib.ttf",
    "C:/Windows/Fonts/calibri.ttf",
    "C:/Windows/Fonts/arial.ttf"
]
for p in font_paths:
    try:
        f = ImageFont.truetype(p, 20)
        print(f"Loaded: {p}")
    except Exception as e:
        print(f"Failed {p}: {e}")
