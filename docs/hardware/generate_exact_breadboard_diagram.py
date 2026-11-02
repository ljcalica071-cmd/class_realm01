import os
import shutil
from PIL import Image, ImageDraw, ImageFont

w, h = 1920, 1080
img = Image.new('RGB', (w, h), (24, 27, 36))
draw = ImageDraw.Draw(img)

try:
    font_title = ImageFont.truetype('arialbd.ttf', 30)
    font_sub = ImageFont.truetype('arial.ttf', 16)
    font_section = ImageFont.truetype('arialbd.ttf', 18)
    font_block = ImageFont.truetype('arialbd.ttf', 15)
    font_hole = ImageFont.truetype('arial.ttf', 11)
    font_pin = ImageFont.truetype('arialbd.ttf', 12)
    font_callout = ImageFont.truetype('arialbd.ttf', 13)
except:
    font_title = font_sub = font_section = font_block = font_hole = font_pin = font_callout = ImageFont.load_default()

# Header
draw.rectangle([0, 0, w, 75], fill=(15, 23, 42))
draw.text((40, 12), 'CLASSREALM: MASTER BREADBOARD HOLE GUIDE (NO CONFLICTS, 100% UNIFIED)', fill=(255, 255, 255), font=font_title)
draw.text((40, 48), 'RFID (Cols 20-27) | Buzzer (Cols 35 & 38) | OLED at Block J (Cols 54-57) | Complete Pin Breakdown', fill=(148, 163, 184), font=font_sub)

# Breadboard area
bb_x, bb_y = 50, 95
bb_w, bb_h = 1820, 520
draw.rectangle([bb_x, bb_y, bb_x + bb_w, bb_y + bb_h], fill=(250, 250, 252), outline=(203, 213, 225), width=3)

# Power rails UP
up_plus_y = bb_y + 40
up_minus_y = bb_y + 70
draw.line([bb_x + 20, up_plus_y - 12, bb_x + bb_w - 20, up_plus_y - 12], fill=(239, 68, 68), width=3)
draw.text((bb_x + 6, up_plus_y - 10), '+', fill=(239, 68, 68), font=font_block)

draw.line([bb_x + 20, up_minus_y + 12, bb_x + bb_w - 20, up_minus_y + 12], fill=(59, 130, 246), width=3)
draw.text((bb_x + 8, up_minus_y - 8), '-', fill=(59, 130, 246), font=font_block)

# Power rails DOWN
down_plus_y = bb_y + bb_h - 70
down_minus_y = bb_y + bb_h - 40
draw.line([bb_x + 20, down_plus_y - 12, bb_x + bb_w - 20, down_plus_y - 12], fill=(239, 68, 68), width=3)
draw.text((bb_x + 6, down_plus_y - 10), '+', fill=(239, 68, 68), font=font_block)

draw.line([bb_x + 20, down_minus_y + 12, bb_x + bb_w - 20, down_minus_y + 12], fill=(59, 130, 246), width=3)
draw.text((bb_x + 8, down_minus_y - 8), '-', fill=(59, 130, 246), font=font_block)

# Grid rows A-E and F-J
grid_start_y = bb_y + 125
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

# Center divider
trough_y = (row_y['E'] + row_y['F']) // 2
draw.rectangle([bb_x + 20, trough_y - 8, bb_x + bb_w - 20, trough_y + 8], fill=(226, 232, 240))

# Row Labels
for r_name, ry in row_y.items():
    draw.text((bb_x + 10, ry - 7), r_name, fill=(100, 116, 139), font=font_block)
    draw.text((bb_x + bb_w - 25, ry - 7), r_name, fill=(100, 116, 139), font=font_block)

col_start_x = bb_x + 45
col_pitch = 29

# 10 Blocks: A to J with 1 gap after every 5 holes
block_letters = ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J']
block_holes = {}

for b_idx, b_let in enumerate(block_letters):
    base_col = b_idx * 6
    b_center_x = col_start_x + (base_col + 2) * col_pitch
    
    # Block Badge
    draw.rectangle([b_center_x - 28, bb_y + 6, b_center_x + 28, bb_y + 24], fill=(254, 226, 226), outline=(239, 68, 68))
    draw.text((b_center_x - 24, bb_y + 7), f'Block {b_let}', fill=(185, 28, 28), font=font_block)
    
    for h_i in range(1, 6):
        c = base_col + (h_i - 1)
        block_holes[c] = (b_let, h_i)

# Draw columns and holes
for c in range(60):
    cx = col_start_x + c * col_pitch
    
    if c in block_holes:
        b_let, h_i = block_holes[c]
        # UP Power holes
        draw.ellipse([cx - 4, up_plus_y - 4, cx + 4, up_plus_y + 4], fill=(220, 220, 220), outline=(140, 140, 140))
        draw.ellipse([cx - 4, up_minus_y - 4, cx + 4, up_minus_y + 4], fill=(220, 220, 220), outline=(140, 140, 140))
        draw.text((cx - 3, up_minus_y + 14), str(h_i), fill=(148, 163, 184), font=font_hole)
        
        # DOWN Power holes
        draw.ellipse([cx - 4, down_plus_y - 4, cx + 4, down_plus_y + 4], fill=(220, 220, 220), outline=(140, 140, 140))
        draw.ellipse([cx - 4, down_minus_y - 4, cx + 4, down_minus_y + 4], fill=(220, 220, 220), outline=(140, 140, 140))
    else:
        # 1-space gap
        draw.text((cx - 4, up_minus_y + 14), '-', fill=(203, 213, 225), font=font_hole)
    
    # Main grid holes A to J
    for r_name in ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J']:
        ry = row_y[r_name]
        draw.ellipse([cx - 4, ry - 4, cx + 4, ry + 4], fill=(220, 220, 220), outline=(140, 140, 140))
        
    if c % 5 == 0:
        draw.text((cx - 6, grid_start_y - 18), str(c), fill=(51, 65, 85), font=font_callout)

# 1. ESP32 DevKit V1 (Cols 0-14, Rows B-J)
esp_x1 = col_start_x - 10
esp_y1 = row_y['B'] - 10
esp_x2 = col_start_x + 14 * col_pitch + 10
esp_y2 = row_y['J'] + 10
draw.rectangle([esp_x1, esp_y1, esp_x2, esp_y2], fill=(30, 41, 59), outline=(71, 85, 105), width=2)
draw.text((esp_x1 + 60, esp_y1 + 95), 'ESP32 DevKit V1', fill=(241, 245, 249), font=font_title)
draw.text((esp_x1 + 75, esp_y1 + 135), '(Row A: Pin assignments below)', fill=(148, 163, 184), font=font_sub)

# ESP32 Row A Pin labels
esp_pins = ['VIN', 'GND', 'D13', 'D12', 'D14', 'D27', 'D26', 'D25', 'D33', 'D32', 'D35', 'D34', 'VN', 'VP', 'EN']
for idx, pin_lbl in enumerate(esp_pins):
    cx = col_start_x + idx * col_pitch
    draw.text((cx - 10, row_y['A'] - 18), pin_lbl, fill=(16, 185, 129), font=font_hole)

# Existing Yellow Power Jumpers
c0_x = col_start_x
draw.line([c0_x, row_y['A'], c0_x, up_plus_y], fill=(234, 179, 8), width=5)
c1_x = col_start_x + col_pitch
draw.line([c1_x, row_y['A'], c1_x, up_minus_y], fill=(234, 179, 8), width=5)

# 2. RFID Reader in Row D (Cols 20-27)
rfid_x1 = col_start_x + 20 * col_pitch - 8
rfid_x2 = col_start_x + 27 * col_pitch + 8
rfid_y1 = row_y['D'] - 8
rfid_y2 = row_y['H'] + 8
draw.rectangle([rfid_x1, rfid_y1, rfid_x2, rfid_y2], fill=(37, 99, 235), outline=(30, 64, 175), width=2)
draw.text((rfid_x1 + 25, rfid_y1 + 25), 'RC522 RFID READER', fill=(255, 255, 255), font=font_section)
draw.text((rfid_x1 + 35, rfid_y1 + 55), 'Row D, Cols 20-27', fill=(219, 234, 254), font=font_callout)

rfid_pins = ['SDA', 'SCK', 'MOSI', 'MISO', 'IRQ', 'GND', 'RST', '3.3V']
for p_i, p_name in enumerate(rfid_pins):
    cx = col_start_x + (20 + p_i) * col_pitch
    draw.ellipse([cx - 5, row_y['D'] - 5, cx + 5, row_y['D'] + 5], fill=(254, 240, 138), outline=(202, 138, 4), width=2)
    draw.text((cx - 10, row_y['D'] - 18), p_name, fill=(30, 58, 138), font=font_pin)

# RFID Ground: Row C, Col 25 -> UP [-] Block E, Hole 1! (User confirmed change!)
c25_x = col_start_x + 25 * col_pitch
c24_x = col_start_x + 24 * col_pitch # Col 24 is Block E Hole 1!
draw.line([(c25_x, row_y['C']), (c24_x, up_minus_y)], fill=(59, 130, 246), width=4)
draw.ellipse([c24_x - 5, up_minus_y - 5, c24_x + 5, up_minus_y + 5], fill=(59, 130, 246))
draw.text((c24_x - 25, up_minus_y - 25), 'UP [-] Blk E H1', fill=(37, 99, 235), font=font_pin)

# RFID Signal Wires (Already Connected by User!)
# SDA (Col 20) -> Row A, Col 3 (D12)
c20_x = col_start_x + 20 * col_pitch
esp_d12_x = col_start_x + 3 * col_pitch
draw.line([(c20_x, row_y['C']), (c20_x, row_y['A'] - 25), (esp_d12_x, row_y['A'] - 25), (esp_d12_x, row_y['A'])], fill=(59, 130, 246), width=3)

# SCK (Col 21) -> Row A, Col 8 (D33)
c21_x = col_start_x + 21 * col_pitch
esp_d33_x = col_start_x + 8 * col_pitch
draw.line([(c21_x, row_y['C']), (c21_x, row_y['A'] - 30), (esp_d33_x, row_y['A'] - 30), (esp_d33_x, row_y['A'])], fill=(148, 163, 184), width=3)

# MOSI (Col 22) -> Row A, Col 2 (D13)
c22_x = col_start_x + 22 * col_pitch
esp_d13_x = col_start_x + 2 * col_pitch
draw.line([(c22_x, row_y['C']), (c22_x, row_y['A'] - 35), (esp_d13_x, row_y['A'] - 35), (esp_d13_x, row_y['A'])], fill=(34, 197, 94), width=3)

# MISO (Col 23) -> Row A, Col 10 (D35)
c23_x = col_start_x + 23 * col_pitch
esp_d35_x = col_start_x + 10 * col_pitch
draw.line([(c23_x, row_y['C']), (c23_x, row_y['A'] - 40), (esp_d35_x, row_y['A'] - 40), (esp_d35_x, row_y['A'])], fill=(241, 245, 249), width=3)

# RST (Col 26) -> Row A, Col 4 (D14)
c26_x = col_start_x + 26 * col_pitch
esp_d14_x = col_start_x + 4 * col_pitch
draw.line([(c26_x, row_y['C']), (c26_x, row_y['A'] - 45), (esp_d14_x, row_y['A'] - 45), (esp_d14_x, row_y['A'])], fill=(249, 115, 22), width=3)

# 3.3V (Col 27) -> Row A, Col 5 (D27)
c27_x = col_start_x + 27 * col_pitch
esp_d27_x = col_start_x + 5 * col_pitch
draw.line([(c27_x, row_y['C']), (c27_x, row_y['A'] - 50), (esp_d27_x, row_y['A'] - 50), (esp_d27_x, row_y['A'])], fill=(239, 68, 68), width=3)

# 3. Buzzer (Cols 35 and 38)
c35_x = col_start_x + 35 * col_pitch
c38_x = col_start_x + 38 * col_pitch
draw.rectangle([c35_x - 10, row_y['D'] - 12, c38_x + 10, row_y['G'] + 12], fill=(15, 23, 42), outline=(100, 116, 139), width=2)
draw.text((c35_x + 10, row_y['E'] - 10), 'BUZZER', fill=(255, 255, 255), font=font_section)

# Buzzer (+) in Col 35 (Row A 35 to Row A 9 D32)
draw.ellipse([c35_x - 6, row_y['D'] - 6, c35_x + 6, row_y['D'] + 6], fill=(245, 158, 11), outline=(180, 83, 9), width=2)
draw.text((c35_x - 10, row_y['D'] - 22), '(+)', fill=(245, 158, 11), font=font_pin)
esp_d32_x = col_start_x + 9 * col_pitch
draw.line([(c35_x, row_y['A']), (c35_x, row_y['A'] - 55), (esp_d32_x, row_y['A'] - 55), (esp_d32_x, row_y['A'])], fill=(245, 158, 11), width=4)

# Buzzer (-) in Col 38 -> UP [-] Block G, Hole 3!
draw.ellipse([c38_x - 6, row_y['D'] - 6, c38_x + 6, row_y['D'] + 6], fill=(59, 130, 246), outline=(30, 64, 175), width=2)
draw.text((c38_x - 10, row_y['D'] - 22), '(-)', fill=(59, 130, 246), font=font_pin)
draw.line([c38_x, row_y['C'], c38_x, up_minus_y], fill=(59, 130, 246), width=4)
draw.ellipse([c38_x - 5, up_minus_y - 5, c38_x + 5, up_minus_y + 5], fill=(59, 130, 246))
draw.text((c38_x - 35, up_minus_y - 25), 'UP [-] Blk G H3', fill=(37, 99, 235), font=font_pin)

# 4. OLED Display at Block J (Cols 54-57)
oled_x1 = col_start_x + 54 * col_pitch - 8
oled_x2 = col_start_x + 57 * col_pitch + 8
oled_y1 = row_y['D'] - 8
oled_y2 = row_y['I'] + 8
draw.rectangle([oled_x1, oled_y1, oled_x2, oled_y2], fill=(15, 23, 42), outline=(56, 189, 248), width=3)
draw.text((oled_x1 + 8, oled_y1 + 45), 'OLED DISPLAY', fill=(56, 189, 248), font=font_callout)
draw.text((oled_x1 + 18, oled_y1 + 70), '0.96 inch I2C', fill=(148, 163, 184), font=font_hole)

oled_pins = ['GND', 'VDD', 'SCK', 'SDA']
for o_i, o_name in enumerate(oled_pins):
    cx = col_start_x + (54 + o_i) * col_pitch
    draw.ellipse([cx - 5, row_y['D'] - 5, cx + 5, row_y['D'] + 5], fill=(186, 230, 253), outline=(2, 132, 199), width=2)
    draw.text((cx - 10, row_y['D'] - 20), o_name, fill=(2, 132, 199), font=font_pin)

# OLED GND (Col 54) -> UP [-] Block J, Hole 1!
c54_x = col_start_x + 54 * col_pitch
draw.line([c54_x, row_y['C'], c54_x, up_minus_y], fill=(59, 130, 246), width=4)
draw.ellipse([c54_x - 5, up_minus_y - 5, c54_x + 5, up_minus_y + 5], fill=(59, 130, 246))
draw.text((c54_x - 30, up_minus_y - 25), 'UP [-] Blk J H1', fill=(37, 99, 235), font=font_pin)

# OLED VDD (Col 55) -> UP [+] Block J, Hole 2!
c55_x = col_start_x + 55 * col_pitch
draw.line([c55_x, row_y['C'], c55_x, up_plus_y], fill=(239, 68, 68), width=4)
draw.ellipse([c55_x - 5, up_plus_y - 5, c55_x + 5, up_plus_y + 5], fill=(239, 68, 68))
draw.text((c55_x - 10, up_plus_y - 28), 'UP [+] Blk J H2', fill=(220, 38, 38), font=font_pin)

# OLED SCK (Col 56) -> Row A, Col 6 (D26)
c56_x = col_start_x + 56 * col_pitch
esp_d26_x = col_start_x + 6 * col_pitch
draw.line([(c56_x, row_y['C']), (c56_x, row_y['A'] - 60), (esp_d26_x, row_y['A'] - 60), (esp_d26_x, row_y['A'])], fill=(245, 158, 11), width=4)

# OLED SDA (Col 57) -> Row A, Col 7 (D25)
c57_x = col_start_x + 57 * col_pitch
esp_d25_x = col_start_x + 7 * col_pitch
draw.line([(c57_x, row_y['C']), (c57_x, row_y['A'] - 65), (esp_d25_x, row_y['A'] - 65), (esp_d25_x, row_y['A'])], fill=(16, 185, 129), width=4)

# Bottom Cards
card_y = bb_y + bb_h + 25
card_w = 560
card_h = 390

# Card 1: Master Wiring Table (Current Physical State)
draw.rectangle([50, card_y, 50 + card_w, card_y + card_h], fill=(30, 41, 59), outline=(56, 189, 248), width=2)
draw.text((70, card_y + 12), 'KASALUKUYANG SETUP (100% MATCH SA BOARD MO)', fill=(56, 189, 248), font=font_section)
b_o_lines = [
    '* A0 (VIN) -> UP [+] Block A, Hole 1',
    '* A1 (GND) -> UP [-] Block A, Hole 2',
    '* RFID SDA  (Col 20) -> Row A, Col 3 (D12)',
    '* RFID SCK  (Col 21) -> Row A, Col 8 (D33)',
    '* RFID MOSI (Col 22) -> Row A, Col 2 (D13)',
    '* RFID MISO (Col 23) -> Row A, Col 10 (D35)',
    '* RFID GND  (Col 25) -> UP [-] Block E, Hole 1',
    '* RFID RST  (Col 26) -> Row A, Col 4 (D14)',
    '* RFID 3.3V (Col 27) -> Row A, Col 5 (D27)',
    '* BUZZER (+) [Col 35] -> Row A, Col 9 (D32)',
    '* BUZZER (-) [Col 38] -> UP [-] Block G, Hole 3',
]
cy = card_y + 45
for l in b_o_lines:
    draw.text((70, cy), l, fill=(241, 245, 249), font=font_sub)
    cy += 28

# Card 2: OLED at Block J
draw.rectangle([640, card_y, 640 + card_w, card_y + card_h], fill=(30, 41, 59), outline=(34, 197, 94), width=2)
draw.text((660, card_y + 12), 'OLED DISPLAY SA BLOCK J (Cols 54-57)', fill=(74, 222, 128), font=font_section)
oled_lines = [
    '* Pin 1: GND (Col 54):',
    '    Row C, Col 54 -> UP [-] Block J, Hole 1',
    '* Pin 2: VDD (Col 55):',
    '    Row C, Col 55 -> UP [+] Block J, Hole 2',
    '* Pin 3: SCK (Col 56):',
    '    Row C, Col 56 -> Row A, Col 6 (D26)',
    '* Pin 4: SDA (Col 57):',
    '    Row C, Col 57 -> Row A, Col 7 (D25)',
    '',
    '*(Ito ang tamang pwesto sa dulo tapat ng Block J!)*',
]
cy = card_y + 45
for l in oled_lines:
    draw.text((660, cy), l, fill=(241, 245, 249), font=font_sub)
    cy += 28

# Card 3: Paliwanag sa LEDs at Pins
draw.rectangle([1230, card_y, 1230 + card_w, card_y + card_h], fill=(30, 41, 59), outline=(245, 158, 11), width=2)
draw.text((1250, card_y + 12), 'BAKIT WALANG ESP PIN PARA SA LEDS?', fill=(251, 191, 36), font=font_section)
led_exp = [
    '* Puno na ang Row A pins mo:',
    '    - D14 (Col 4) ay hawak na ng RFID RST',
    '    - D27 (Col 5) ay hawak na ng RFID 3.3V',
    '* KAYA HINDI NA PWEDE ISAKSAK ANG LED SA D14/D27',
    '  nang hindi nagduduplicate!',
    '',
    '* MAGANDANG BALITA:',
    '  1. May OLED Screen ka (nagdi-display ng pangalan,',
    '     STATUS: ACCESS GRANTED / REJECTED)',
    '  2. May Buzzer ka (tumutunog sa bawat tap)',
    '  -> HINDI MO NA KAILANGAN NG PHYSICAL LEDS!',
]
cy = card_y + 45
for l in led_exp:
    draw.text((1250, cy), l, fill=(241, 245, 249), font=font_sub)
    cy += 26

out_path = 'docs/hardware/exact_breadboard_hole_diagram.jpg'
img.save(out_path, quality=95)
print('Saved diagram to:', out_path)

# Copy to artifacts
artifact_dir = r'C:/Users/Admin/.gemini/antigravity/brain/612cfb69-8680-4c79-a00a-dd82e013b40f'
artifact_path = os.path.join(artifact_dir, 'exact_breadboard_hole_diagram.jpg')
shutil.copyfile(out_path, artifact_path)
print('Copied to artifact:', artifact_path)
