import os
import shutil
from PIL import Image, ImageDraw, ImageFont

w, h = 1920, 1080
img = Image.new('RGB', (w, h), (24, 27, 36))
draw = ImageDraw.Draw(img)

try:
    font_title = ImageFont.truetype('arialbd.ttf', 32)
    font_sub = ImageFont.truetype('arial.ttf', 18)
    font_section = ImageFont.truetype('arialbd.ttf', 20)
    font_block = ImageFont.truetype('arialbd.ttf', 16)
    font_hole = ImageFont.truetype('arial.ttf', 11)
    font_pin = ImageFont.truetype('arialbd.ttf', 12)
    font_callout = ImageFont.truetype('arialbd.ttf', 14)
except:
    font_title = font_sub = font_section = font_block = font_hole = font_pin = font_callout = ImageFont.load_default()

# Header
draw.rectangle([0, 0, w, 80], fill=(15, 23, 42))
draw.text((40, 15), 'CLASSREALM HARDWARE: EXACT HOLE-BY-HOLE WIRING GUIDE', fill=(255, 255, 255), font=font_title)
draw.text((40, 52), 'Direct breadboard placement for OLED (Cols 48-51 in Row D) and RFID (Cols 20-27 in Row D)', fill=(148, 163, 184), font=font_sub)

# Breadboard area
bb_x, bb_y = 60, 110
bb_w, bb_h = 1800, 520
draw.rectangle([bb_x, bb_y, bb_x + bb_w, bb_y + bb_h], fill=(250, 250, 252), outline=(203, 213, 225), width=3)

# Power rails UP
up_plus_y = bb_y + 45
up_minus_y = bb_y + 75
draw.line([bb_x + 25, up_plus_y - 12, bb_x + bb_w - 25, up_plus_y - 12], fill=(239, 68, 68), width=3)
draw.text((bb_x + 8, up_plus_y - 10), '+', fill=(239, 68, 68), font=font_block)

draw.line([bb_x + 25, up_minus_y + 12, bb_x + bb_w - 25, up_minus_y + 12], fill=(59, 130, 246), width=3)
draw.text((bb_x + 10, up_minus_y - 8), '-', fill=(59, 130, 246), font=font_block)

# Power rails DOWN
down_plus_y = bb_y + bb_h - 75
down_minus_y = bb_y + bb_h - 45
draw.line([bb_x + 25, down_plus_y - 12, bb_x + bb_w - 25, down_plus_y - 12], fill=(239, 68, 68), width=3)
draw.text((bb_x + 8, down_plus_y - 10), '+', fill=(239, 68, 68), font=font_block)

draw.line([bb_x + 25, down_minus_y + 12, bb_x + bb_w - 25, down_minus_y + 12], fill=(59, 130, 246), width=3)
draw.text((bb_x + 10, down_minus_y - 8), '-', fill=(59, 130, 246), font=font_block)

# Main Grid Row Y-coordinates
grid_start_y = bb_y + 130
pitch_y = 28
row_y = {
    'A': grid_start_y + 0 * pitch_y,
    'B': grid_start_y + 1 * pitch_y,
    'C': grid_start_y + 2 * pitch_y,
    'D': grid_start_y + 3 * pitch_y,
    'E': grid_start_y + 4 * pitch_y,
    'F': grid_start_y + 6 * pitch_y + 10,
    'G': grid_start_y + 7 * pitch_y + 10,
    'H': grid_start_y + 8 * pitch_y + 10,
    'I': grid_start_y + 9 * pitch_y + 10,
    'J': grid_start_y + 10 * pitch_y + 10,
}

# Center trough
trough_y = (row_y['E'] + row_y['F']) // 2
draw.rectangle([bb_x + 25, trough_y - 8, bb_x + bb_w - 25, trough_y + 8], fill=(226, 232, 240))

# Row Labels on left and right
for r_name, ry in row_y.items():
    draw.text((bb_x + 15, ry - 7), r_name, fill=(100, 116, 139), font=font_block)
    draw.text((bb_x + bb_w - 25, ry - 7), r_name, fill=(100, 116, 139), font=font_block)

col_start_x = bb_x + 55
col_pitch = 28

# Block letters on UP rail
block_names = ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L']
for b_i, b_l in enumerate(block_names):
    b_center_x = col_start_x + (b_i * 5 * col_pitch) + (2 * col_pitch)
    draw.rectangle([b_center_x - 30, bb_y + 8, b_center_x + 30, bb_y + 28], fill=(254, 226, 226), outline=(239, 68, 68))
    draw.text((b_center_x - 22, bb_y + 10), f'Block {b_l}', fill=(185, 28, 28), font=font_block)

# Holes
for c in range(61):
    cx = col_start_x + c * col_pitch
    b_i = c // 5
    h_i = (c % 5) + 1
    
    # Power Holes UP
    draw.ellipse([cx - 4, up_plus_y - 4, cx + 4, up_plus_y + 4], fill=(220, 220, 220), outline=(140, 140, 140))
    draw.ellipse([cx - 4, up_minus_y - 4, cx + 4, up_minus_y + 4], fill=(220, 220, 220), outline=(140, 140, 140))
    
    # Hole number inside block (1 to 5)
    draw.text((cx - 3, up_minus_y + 16), str(h_i), fill=(148, 163, 184), font=font_hole)
    
    # Main grid holes A-J
    for r_name in ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J']:
        ry = row_y[r_name]
        draw.ellipse([cx - 4, ry - 4, cx + 4, ry + 4], fill=(220, 220, 220), outline=(140, 140, 140))
        
    # Column number
    if c % 5 == 0:
        draw.text((cx - 6, grid_start_y - 20), str(c), fill=(51, 65, 85), font=font_callout)

# 1. ESP32 Representation (Cols 0 to 14, Rows B to J)
esp_x1 = col_start_x - 12
esp_y1 = row_y['B'] - 12
esp_x2 = col_start_x + 14 * col_pitch + 12
esp_y2 = row_y['J'] + 12
draw.rectangle([esp_x1, esp_y1, esp_x2, esp_y2], fill=(30, 41, 59), outline=(71, 85, 105), width=2)
draw.text((esp_x1 + 60, esp_y1 + 100), 'ESP32 DevKit V1 (30-Pin)', fill=(241, 245, 249), font=font_title)
draw.text((esp_x1 + 80, esp_y1 + 140), '(Rows B to J Occupied — Row A is FREE!)', fill=(203, 213, 225), font=font_sub)

# ESP32 Row A Pin labels
esp_top_pins = ['VIN', 'GND', 'D13', 'D12', 'D14', 'D27', 'D26', 'D25', 'D33', 'D32', 'D35', 'D34', 'VN', 'VP', 'EN']
for idx, pin_lbl in enumerate(esp_top_pins):
    cx = col_start_x + idx * col_pitch
    draw.text((cx - 10, row_y['A'] - 18), pin_lbl, fill=(16, 185, 129), font=font_hole)

# Existing Yellow Jumpers (VIN to UP +, GND to UP -)
c0_x = col_start_x
draw.line([c0_x, row_y['A'], c0_x, up_plus_y], fill=(234, 179, 8), width=5)
c1_x = col_start_x + col_pitch
draw.line([c1_x, row_y['A'], c1_x, up_minus_y], fill=(234, 179, 8), width=5)

# 2. RFID Module in Row D, Cols 20 to 27
rfid_x1 = col_start_x + 20 * col_pitch - 10
rfid_x2 = col_start_x + 27 * col_pitch + 10
rfid_y1 = row_y['D'] - 10
rfid_y2 = row_y['H'] + 10
draw.rectangle([rfid_x1, rfid_y1, rfid_x2, rfid_y2], fill=(37, 99, 235), outline=(30, 64, 175), width=2)
draw.text((rfid_x1 + 30, rfid_y1 + 30), 'RC522 RFID READER', fill=(255, 255, 255), font=font_section)
draw.text((rfid_x1 + 25, rfid_y1 + 60), 'Pins in Row D (Cols 20-27)', fill=(219, 234, 254), font=font_callout)

rfid_pins = ['SDA', 'SCK', 'MOSI', 'MISO', 'IRQ', 'GND', 'RST', '3.3V']
for p_i, p_name in enumerate(rfid_pins):
    cx = col_start_x + (20 + p_i) * col_pitch
    draw.ellipse([cx - 6, row_y['D'] - 6, cx + 6, row_y['D'] + 6], fill=(254, 240, 138), outline=(202, 138, 4), width=2)
    draw.text((cx - 12, row_y['D'] - 20), p_name, fill=(30, 58, 138), font=font_pin)

# 3. OLED Module in Row D, Cols 48 to 51
oled_x1 = col_start_x + 48 * col_pitch - 10
oled_x2 = col_start_x + 51 * col_pitch + 10
oled_y1 = row_y['D'] - 10
oled_y2 = row_y['I'] + 10
draw.rectangle([oled_x1, oled_y1, oled_x2, oled_y2], fill=(15, 23, 42), outline=(56, 189, 248), width=3)
draw.text((oled_x1 + 5, oled_y1 + 45), 'OLED DISPLAY', fill=(56, 189, 248), font=font_callout)
draw.text((oled_x1 + 15, oled_y1 + 70), '0.96 inch I2C', fill=(148, 163, 184), font=font_hole)

oled_pins = ['GND', 'VDD', 'SCK', 'SDA']
for o_i, o_name in enumerate(oled_pins):
    cx = col_start_x + (48 + o_i) * col_pitch
    draw.ellipse([cx - 6, row_y['D'] - 6, cx + 6, row_y['D'] + 6], fill=(186, 230, 253), outline=(2, 132, 199), width=2)
    draw.text((cx - 12, row_y['D'] - 22), o_name, fill=(2, 132, 199), font=font_pin)

# DRAW OLED JUMPER WIRES
c48_x = col_start_x + 48 * col_pitch
draw.line([c48_x, row_y['C'], c48_x, up_minus_y], fill=(59, 130, 246), width=4)
draw.ellipse([c48_x - 5, up_minus_y - 5, c48_x + 5, up_minus_y + 5], fill=(59, 130, 246))
draw.text((c48_x - 45, up_minus_y - 25), 'UP [-] Blk J H4', fill=(37, 99, 235), font=font_pin)

c49_x = col_start_x + 49 * col_pitch
draw.line([c49_x, row_y['C'], c49_x, up_plus_y], fill=(239, 68, 68), width=4)
draw.ellipse([c49_x - 5, up_plus_y - 5, c49_x + 5, up_plus_y + 5], fill=(239, 68, 68))
draw.text((c49_x - 10, up_plus_y - 28), 'UP [+] Blk J H5', fill=(220, 38, 38), font=font_pin)

c50_x = col_start_x + 50 * col_pitch
esp_d26_x = col_start_x + 6 * col_pitch
draw.line([(c50_x, row_y['C']), (c50_x, row_y['A'] - 35), (esp_d26_x, row_y['A'] - 35), (esp_d26_x, row_y['A'])], fill=(245, 158, 11), width=4)
draw.ellipse([esp_d26_x - 5, row_y['A'] - 5, esp_d26_x + 5, row_y['A'] + 5], fill=(245, 158, 11))

c51_x = col_start_x + 51 * col_pitch
esp_d25_x = col_start_x + 7 * col_pitch
draw.line([(c51_x, row_y['C']), (c51_x, row_y['A'] - 45), (esp_d25_x, row_y['A'] - 45), (esp_d25_x, row_y['A'])], fill=(16, 185, 129), width=4)
draw.ellipse([esp_d25_x - 5, row_y['A'] - 5, esp_d25_x + 5, row_y['A'] + 5], fill=(16, 185, 129))

# DRAW RFID WIRES
c25_x = col_start_x + 25 * col_pitch
draw.line([c25_x, row_y['C'], c25_x, up_minus_y], fill=(59, 130, 246), width=4)
draw.ellipse([c25_x - 5, up_minus_y - 5, c25_x + 5, up_minus_y + 5], fill=(59, 130, 246))
draw.text((c25_x - 30, up_minus_y - 25), 'UP [-] Blk F H1', fill=(37, 99, 235), font=font_pin)

# Summary Cards at Bottom
card_y = bb_y + bb_h + 30
card_w = 520
card_h = 360

# Card 1: OLED Wiring Table
draw.rectangle([60, card_y, 60 + card_w, card_y + card_h], fill=(30, 41, 59), outline=(56, 189, 248), width=2)
draw.text((80, card_y + 15), 'OLED DISPLAY (0.96 inch I2C)', fill=(56, 189, 248), font=font_section)
oled_info = [
    '* Nakatusok sa Row D (Cols 48, 49, 50, 51)',
    '* Wire 1: Row C, Col 48 (GND) ->',
    '    UP [-] (Blue line) Block J, Hole 4',
    '* Wire 2: Row C, Col 49 (VDD) ->',
    '    UP [+] (Red line) Block J, Hole 5',
    '* Wire 3: Row C, Col 50 (SCK) ->',
    '    Row A, Col 6 (ESP32 D26)',
    '* Wire 4: Row C, Col 51 (SDA) ->',
    '    Row A, Col 7 (ESP32 D25)',
]
cy = card_y + 50
for line in oled_info:
    draw.text((80, cy), line, fill=(241, 245, 249), font=font_sub)
    cy += 32

# Card 2: RFID Wiring Table
draw.rectangle([620, card_y, 620 + 580, card_y + card_h], fill=(30, 41, 59), outline=(37, 99, 235), width=2)
draw.text((640, card_y + 15), 'RC522 RFID READER (In Row D, Cols 20-27)', fill=(96, 165, 250), font=font_section)
rfid_info = [
    '* SDA  (Col 20): Row C, Col 20 -> Row A, Col 3 (D12)',
    '* SCK  (Col 21): Row C, Col 21 -> Row A, Col 8 (D33)',
    '* MOSI (Col 22): Row C, Col 22 -> Row A, Col 2 (D13)',
    '* MISO (Col 23): Row C, Col 23 -> Row A, Col 10 (D35)',
    '* IRQ  (Col 24): [BAKANTE / WALANG WIRE]',
    '* GND  (Col 25): Row C, Col 25 -> UP [-] Blk F H1',
    '* RST  (Col 26): Row C, Col 26 -> Row A, Col 4 (D14)',
    '* 3.3V (Col 27): Row C, Col 27 -> Row A, Col 5 (D27 HIGH)',
]
cy = card_y + 50
for line in rfid_info:
    draw.text((640, cy), line, fill=(241, 245, 249), font=font_sub)
    cy += 32

# Card 3: Buzzer & LEDs
draw.rectangle([1240, card_y, 1240 + 580, card_y + card_h], fill=(30, 41, 59), outline=(16, 185, 129), width=2)
draw.text((1260, card_y + 15), 'BUZZER & LEDS (Rows B & C)', fill=(52, 211, 153), font=font_section)
extra_info = [
    '* Buzzer (+) [Col 35]: Row C, Col 35 -> Row A, Col 9 (D32)',
    '* Buzzer (-) [Col 37]: Row C, Col 37 -> UP [-] Block H, Hole 3',
    '* Green LED (+) [Col 40]: Row C, Col 40 -> Row A, Col 5 (D27)',
    '* Green LED (-) [Col 41]: 220 Resistor -> UP [-] Block I, Hole 2',
    '* Red LED (+) [Col 43]: Row C, Col 43 -> Row A, Col 4 (D14)',
    '* Red LED (-) [Col 44]: 220 Resistor -> UP [-] Block I, Hole 5',
    '*(Lahat ng butas sa Row C at UP rails ay direktang katapat!)*',
]
cy = card_y + 50
for line in extra_info:
    draw.text((1260, cy), line, fill=(241, 245, 249), font=font_sub)
    cy += 32

out_path = 'docs/hardware/exact_breadboard_hole_diagram.jpg'
img.save(out_path, quality=95)
print('Saved diagram to:', out_path)

# Copy to artifacts directory
artifact_dir = r'C:/Users/Admin/.gemini/antigravity/brain/612cfb69-8680-4c79-a00a-dd82e013b40f'
artifact_path = os.path.join(artifact_dir, 'exact_breadboard_hole_diagram.jpg')
shutil.copyfile(out_path, artifact_path)
print('Copied to artifact:', artifact_path)
