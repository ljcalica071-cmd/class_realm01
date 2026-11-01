from PIL import Image, ImageDraw, ImageFont
import os

def create_diagram():
    # Load user's reference photo
    photo_path = r'C:\Users\Admin\.gemini\antigravity\brain\612cfb69-8680-4c79-a00a-dd82e013b40f\.user_uploaded\media_1793508791634_73f764bd.jpg'
    img = Image.open(photo_path).convert('RGBA')
    w, h = img.size

    # Create overlay canvas
    overlay = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)

    try:
        font_lg = ImageFont.truetype("arialbd.ttf", 36)
        font_md = ImageFont.truetype("arialbd.ttf", 26)
        font_sm = ImageFont.truetype("arialbd.ttf", 20)
    except:
        font_lg = font_md = font_sm = ImageFont.load_default()

    # Highlight why Row J has no holes
    # Row J is at y ≈ h * 0.72
    # Draw a prominent banner on top of the black line the user drew
    draw.rectangle([(50, int(h * 0.68)), (w - 50, int(h * 0.74))], fill=(220, 38, 38, 180), outline=(255, 255, 255), width=3)
    draw.text((w // 2, int(h * 0.71)), "ROW J — NAKASAKSAK ANG ESP32 (WALANG LIBRENG BUTAS DITO)", fill=(255, 255, 255), font=font_md, anchor="mm")

    # Highlight Row A
    draw.rectangle([(50, int(h * 0.35)), (w - 50, int(h * 0.40))], fill=(34, 197, 94, 160), outline=(255, 255, 255), width=3)
    draw.text((w // 2, int(h * 0.375)), "ROW A (Cols 0 to 60) — MAY LIBRENG BUTAS DITO", fill=(255, 255, 255), font=font_md, anchor="mm")

    # Save explanation graphic
    out_img = Image.alpha_composite(img, overlay)
    out_path = r'c:\Users\Admin\AndroidStudioProjects\class_realm01\docs\hardware\breadboard_physical_reality.jpg'
    out_img.convert('RGB').save(out_path, quality=95)
    
    brain_path = r'C:\Users\Admin\.gemini\antigravity\brain\612cfb69-8680-4c79-a00a-dd82e013b40f\breadboard_physical_reality.jpg'
    out_img.convert('RGB').save(brain_path, quality=95)
    print("Created breadboard_physical_reality.jpg")

if __name__ == '__main__':
    create_diagram()
