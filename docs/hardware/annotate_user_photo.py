import os
from PIL import Image, ImageDraw, ImageFont

def annotate():
    photo_path = r'C:\Users\Admin\.gemini\antigravity\brain\612cfb69-8680-4c79-a00a-dd82e013b40f\.user_uploaded\media_1793503321761_97bf9975.jpg'
    base_img = Image.open(photo_path).convert('RGBA')
    orig_w, orig_h = base_img.size

    # We will expand the canvas at the top and bottom to make ample room for clear labels and callout lines!
    # Canvas: width = orig_w (1024), height = 1100
    top_pad = 280
    bot_pad = 360
    total_h = orig_h + top_pad + bot_pad
    canvas = Image.new('RGBA', (orig_w, total_h), (11, 17, 32, 255))
    
    # Paste photo in the middle
    canvas.paste(base_img, (0, top_pad))
    draw = ImageDraw.Draw(canvas)

    # Let's try loading a nice TTF font or default
    try:
        font_title = ImageFont.truetype("arialbd.ttf", 20)
        font_bold = ImageFont.truetype("arialbd.ttf", 13)
        font_sm = ImageFont.truetype("arialbd.ttf", 11)
        font_xs = ImageFont.truetype("arial.ttf", 10)
    except:
        font_title = font_bold = font_sm = font_xs = ImageFont.load_default()

    # Title header
    draw.rectangle([(0, 0), (orig_w, 60)], fill=(17, 24, 39, 255))
    draw.text((20, 18), "CLASSREALM — EXACT BREADBOARD HOLE PLACEMENT GUIDE", fill=(56, 189, 248), font=font_title)

    # Pin coordinate geometry on the original image (offset by top_pad)
    # The ESP32 pins run from x_start around 118 to x_end around 332
    # Total 15 pins -> spacing dx is approx (332 - 118) / 14 = 15.3 pixels
    x_pin1 = 118
    dx_pin = 15.28

    def get_pin_x(idx): # 0-indexed (0 to 14)
        return int(x_pin1 + idx * dx_pin)

    # In the photo:
    # Row J (open holes row ABOVE ESP32): y ≈ 118 in photo -> y_j = top_pad + 118
    # Top Red (+) Rail: y ≈ 98 in photo -> y_top_plus = top_pad + 98
    # Top Blue (-) Rail: y ≈ 75 in photo -> y_top_minus = top_pad + 75
    y_j = top_pad + 118
    y_top_plus = top_pad + 98
    y_top_minus = top_pad + 75

    # Row A (open holes row BELOW ESP32): y ≈ 274 in photo -> y_a = top_pad + 274
    # Bottom Blue (-) Rail: y ≈ 298 in photo -> y_bot_minus = top_pad + 298
    # Bottom Red (+) Rail: y ≈ 318 in photo -> y_bot_plus = top_pad + 318
    y_a = top_pad + 274
    y_bot_minus = top_pad + 298
    y_bot_plus = top_pad + 318

    # Bottom pins (ESP32 Bottom Row: 3V3 .. D23):
    # Hole A is at y_a
    # Indices 0 to 14:
    # 0: 3V3
    # 1: GND
    # 4: D4
    # 7: D5
    # 8: D18
    # 9: D19
    # 10: D21
    # 13: D22
    # 14: D23
    bottom_targets = [
        (0, "3V3", "A60", "🟨 Jumper to Red (+) Rail", (234, 179, 8), y_bot_plus),
        (1, "GND", "A59", "🟨 Jumper to Blue (-) Rail", (234, 179, 8), y_bot_minus),
        (4, "D4",  "A56", "🟦 Blue F-M to RC522 RST", (59, 130, 246), None),
        (7, "D5",  "A53", "🟦 Blue F-M to RC522 SDA", (59, 130, 246), None),
        (8, "D18", "A52", "🟦 Blue F-M to RC522 SCK", (59, 130, 246), None),
        (9, "D19", "A51", "🟦 Blue F-M to RC522 MISO", (59, 130, 246), None),
        (10, "D21", "A50", "🟦 Blue F-M to OLED SDA", (59, 130, 246), None),
        (13, "D22", "A47", "🟦 Blue F-M to OLED SCL", (59, 130, 246), None),
        (14, "D23", "A46", "🟦 Blue F-M to RC522 MOSI", (59, 130, 246), None),
    ]

    # Staggered label positions for bottom
    bot_label_y_levels = [total_h - 260, total_h - 180, total_h - 100, total_h - 20]

    for i, (pin_idx, pin_name, hole_name, action_text, clr, rail_target) in enumerate(bottom_targets):
        hx = get_pin_x(pin_idx)
        hy = y_a
        
        # Circle on the exact hole
        draw.ellipse([(hx - 6, hy - 6), (hx + 6, hy + 6)], outline=(0, 0, 0), width=3)
        draw.ellipse([(hx - 5, hy - 5), (hx + 5, hy + 5)], fill=clr, outline=(255, 255, 255), width=1)
        
        # Staggered y position
        box_y = bot_pad + orig_h + 30 + (i % 4) * 65
        box_x = max(10, min(hx - 80, orig_w - 220))
        
        # Connecting line
        draw.line([(hx, hy + 7), (hx, box_y - 8)], fill=clr, width=2)
        draw.line([(hx, box_y - 8), (box_x + 30, box_y)], fill=clr, width=2)
        
        # Label box
        box_w = 210
        box_h = 48
        draw.rectangle([(box_x, box_y), (box_x + box_w, box_y + box_h)], fill=(30, 41, 59, 240), outline=clr, width=2)
        draw.text((box_x + 8, box_y + 6), f"● HOLE {hole_name} ({pin_name})", fill=(255, 255, 255), font=font_bold)
        draw.text((box_x + 8, box_y + 26), action_text, fill=clr, font=font_sm)

    # Top Pins (ESP32 Top Row: VIN .. EN):
    # Hole J is at y_j
    # 4: D14 -> Red LED Anode
    # 5: D27 -> Green LED Anode
    # 9: D32 -> Buzzer (+)
    top_targets = [
        (4, "D14", "J56", "⬛ Black M-M to Red LED (+)", (239, 68, 68)),
        (5, "D27", "J55", "⬛ Black M-M to Green LED (+)", (34, 197, 94)),
        (9, "D32", "J51", "⬛ Black M-M to Buzzer (+)", (168, 85, 247)),
    ]

    for i, (pin_idx, pin_name, hole_name, action_text, clr) in enumerate(top_targets):
        hx = get_pin_x(pin_idx)
        hy = y_j
        
        draw.ellipse([(hx - 6, hy - 6), (hx + 6, hy + 6)], outline=(0, 0, 0), width=3)
        draw.ellipse([(hx - 5, hy - 5), (hx + 5, hy + 5)], fill=clr, outline=(255, 255, 255), width=1)
        
        box_y = 80 + i * 55
        box_x = max(10, min(hx - 80, orig_w - 240))
        
        draw.line([(hx, hy - 7), (hx, box_y + 45)], fill=clr, width=2)
        draw.line([(hx, box_y + 45), (box_x + 40, box_y + 40)], fill=clr, width=2)
        
        box_w = 230
        box_h = 42
        draw.rectangle([(box_x, box_y), (box_x + box_w, box_y + box_h)], fill=(30, 41, 59, 240), outline=clr, width=2)
        draw.text((box_x + 8, box_y + 5), f"● HOLE {hole_name} ({pin_name})", fill=(255, 255, 255), font=font_bold)
        draw.text((box_x + 8, box_y + 23), action_text, fill=clr, font=font_sm)

    # Open Area on the Right (Rows 20 to 45 in the photo):
    # In the photo, rows go horizontally from x ≈ 400 to x ≈ 950!
    # Let's place the Buzzer, Green LED, and Red LED in columns 22, 28, 35!
    # Column 20 is around x = 460
    # Column 25 is around x = 540
    # Column 32 is around x = 650
    # Column 40 is around x = 770

    # 1. Buzzer at Column 35:
    # Row G = +, Row I = - (Top half, above divider)
    # Divider is at y ≈ top_pad + 200
    # Row G is at y ≈ top_pad + 170
    # Row I is at y ≈ top_pad + 135
    bx = 700
    b_plus_y = top_pad + 170
    b_minus_y = top_pad + 135
    draw.ellipse([(bx - 22, (b_plus_y+b_minus_y)/2 - 22), (bx + 22, (b_plus_y+b_minus_y)/2 + 22)], fill=(24, 24, 27, 220), outline=(168, 85, 247), width=3)
    draw.text((bx - 18, (b_plus_y+b_minus_y)/2 - 8), "BUZZER", fill=(255, 255, 255), font=font_xs)
    draw.ellipse([(bx - 5, b_plus_y - 5), (bx + 5, b_plus_y + 5)], fill=(239, 68, 68), outline=(255, 255, 255), width=1)
    draw.ellipse([(bx - 5, b_minus_y - 5), (bx + 5, b_minus_y + 5)], fill=(59, 130, 246), outline=(255, 255, 255), width=1)
    # Buzzer callout
    draw.text((bx + 30, (b_plus_y+b_minus_y)/2 - 18), "ACTIVE BUZZER (Col 35)", fill=(168, 85, 247), font=font_bold)
    draw.text((bx + 30, (b_plus_y+b_minus_y)/2), "(+) Leg sa Row G (from J51 D32)", fill=(243, 244, 246), font=font_xs)
    draw.text((bx + 30, (b_plus_y+b_minus_y)/2 + 14), "(-) Leg sa Row I (to Blue - Rail)", fill=(56, 189, 248), font=font_xs)

    # 2. Green LED at Column 26:
    gx = 560
    g_plus_y = top_pad + 170
    g_minus_y = top_pad + 135
    draw.ellipse([(gx - 14, (g_plus_y+g_minus_y)/2 - 14), (gx + 14, (g_plus_y+g_minus_y)/2 + 14)], fill=(34, 197, 94, 220), outline=(255, 255, 255), width=2)
    draw.text((gx - 30, top_pad + 80), "GREEN LED (Col 26)", fill=(34, 197, 94), font=font_bold)
    draw.text((gx - 30, top_pad + 96), "(+) Mahabang paa: Row G", fill=(243, 244, 246), font=font_xs)
    draw.text((gx - 30, top_pad + 110), "(-) + 220Ω Resistor: Row I", fill=(209, 213, 219), font=font_xs)

    # 3. Red LED at Column 18:
    rx = 440
    r_plus_y = top_pad + 170
    r_minus_y = top_pad + 135
    draw.ellipse([(rx - 14, (r_plus_y+r_minus_y)/2 - 14), (rx + 14, (r_plus_y+r_minus_y)/2 + 14)], fill=(239, 68, 68, 220), outline=(255, 255, 255), width=2)
    draw.text((rx - 30, top_pad + 80), "RED LED (Col 18)", fill=(239, 68, 68), font=font_bold)
    draw.text((rx - 30, top_pad + 96), "(+) Mahabang paa: Row G", fill=(243, 244, 246), font=font_xs)
    draw.text((rx - 30, top_pad + 110), "(-) + 220Ω Resistor: Row I", fill=(209, 213, 219), font=font_xs)

    # Save output
    out_dir = r'c:\Users\Admin\AndroidStudioProjects\class_realm01\docs\hardware'
    out_path = os.path.join(out_dir, 'annotated_breadboard_real_photo.jpg')
    canvas.convert('RGB').save(out_path, quality=95)
    print(f"Saved annotated photo to {out_path}")

    # Also save in brain artifact dir
    brain_path = r'C:\Users\Admin\.gemini\antigravity\brain\612cfb69-8680-4c79-a00a-dd82e013b40f\annotated_breadboard_real_photo.jpg'
    canvas.convert('RGB').save(brain_path, quality=95)
    print(f"Saved copy to {brain_path}")

if __name__ == '__main__':
    annotate()

