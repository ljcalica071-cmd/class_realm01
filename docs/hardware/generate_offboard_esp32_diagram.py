import os
import shutil
from PIL import Image, ImageDraw, ImageFont

w, h = 1920, 1080
img = Image.new('RGB', (w, h), (15, 23, 42))
draw = ImageDraw.Draw(img)

try:
    font_title = ImageFont.truetype('arialbd.ttf', 28)
    font_sub = ImageFont.truetype('arial.ttf', 15)
    font_section = ImageFont.truetype('arialbd.ttf', 17)
    font_block = ImageFont.truetype('arialbd.ttf', 13)
    font_hole = ImageFont.truetype('arial.ttf', 10)
    font_pin = ImageFont.truetype('arialbd.ttf', 11)
    font_callout = ImageFont.truetype('arialbd.ttf', 12)
    font_badge = ImageFont.truetype('arialbd.ttf', 11)
except:
    font_title = font_sub = font_section = font_block = font_hole = font_pin = font_callout = font_badge = ImageFont.load_default()

# Header
draw.rectangle([0, 0, w, 70], fill=(11, 17, 32))
draw.text((40, 12), 'CLASSREALM: METHOD 2 — OFF-BOARD ESP32 WIRING GUIDE (NATANGGAL SA BREADBOARD)', fill=(56, 189, 248), font=font_title)
draw.text((40, 44), 'ESP32 nasa Labas gamit ang Female-to-Male (F-M) Wires | 100% Direct 3.3V Power | Zero Crowding sa Breadboard', fill=(148, 163, 184), font=font_sub)

# =========================================================================
# LEFT: ESP32 DEVKIT V1 MODULE (OFF-BOARD)
# =========================================================================
esp_x, esp_y = 45, 90
esp_w, esp_h = 360, 540

# Module background card
draw.rectangle([esp_x - 10, esp_y - 10, esp_x + esp_w + 10, esp_y + esp_h + 10], fill=(24, 32, 47), outline=(56, 189, 248), width=2)
draw.text((esp_x + 10, esp_y - 2), 'ESP32 DEVKIT V1 (STANDALONE / NASA LABAS)', fill=(56, 189, 248), font=font_callout)

# ESP32 PCB Board
pcb_x = esp_x + 35
pcb_y = esp_y + 35
pcb_w = esp_w - 70
pcb_h = esp_h - 60
draw.rectangle([pcb_x, pcb_y, pcb_x + pcb_w, pcb_y + pcb_h], fill=(30, 41, 59), outline=(71, 85, 105), width=2)

# Micro USB Port at top
usb_w, usb_h = 50, 26
usb_x = pcb_x + (pcb_w - usb_w) // 2
draw.rectangle([usb_x, pcb_y - 12, usb_x + usb_w, pcb_y + 14], fill=(148, 163, 184), outline=(203, 213, 225), width=2)
draw.text((usb_x + 10, pcb_y - 8), 'USB', fill=(15, 23, 42), font=font_badge)

# Metal RF Shield
shield_w, shield_h = 160, 130
shield_x = pcb_x + (pcb_w - shield_w) // 2
shield_y = pcb_y + 55
draw.rectangle([shield_x, shield_y, shield_x + shield_w, shield_y + shield_h], fill=(71, 85, 105), outline=(148, 163, 184), width=1)
draw.text((shield_x + 25, shield_y + 50), 'ESP-WROOM-32', fill=(241, 245, 249), font=font_callout)
draw.text((shield_x + 35, shield_y + 70), 'Dual Core 240MHz', fill=(203, 213, 225), font=font_hole)

# AMS1117-3.3 Regulator chip
draw.rectangle([pcb_x + 40, pcb_y + 210, pcb_x + 90, pcb_y + 245], fill=(15, 23, 42), outline=(100, 116, 139))
draw.text((pcb_x + 45, pcb_y + 222), '3.3V LDO', fill=(234, 179, 8), font=font_hole)

# ESP32 Pins Definition
left_pins = [
    ('3V3', '3.3V Power Out (500mA)', (239, 68, 68)),
    ('GND', 'System Ground', (59, 130, 246)),
    ('D15', 'GPIO 15', (100, 116, 139)),
    ('D2',  'GPIO 2 (Blue LED)', (100, 116, 139)),
    ('D4',  'GPIO 4', (100, 116, 139)),
    ('RX2', 'UART RX2', (100, 116, 139)),
    ('TX2', 'UART TX2', (100, 116, 139)),
    ('D5',  'GPIO 5', (100, 116, 139)),
    ('D18', 'GPIO 18', (100, 116, 139)),
    ('D19', 'GPIO 19', (100, 116, 139)),
    ('D21', 'GPIO 21', (100, 116, 139)),
    ('RX0', 'Serial RX', (100, 116, 139)),
    ('TX0', 'Serial TX', (100, 116, 139)),
    ('D22', 'GPIO 22', (100, 116, 139)),
    ('D23', 'GPIO 23', (100, 116, 139)),
]

right_pins = [
    ('VIN', '5V Power In (from USB)', (245, 158, 11)),
    ('GND', 'System Ground', (59, 130, 246)),
    ('D13', 'RFID MOSI', (34, 197, 94)),
    ('D12', 'RFID SDA / SS', (59, 130, 246)),
    ('D14', 'RFID RST', (249, 115, 22)),
    ('D27', 'GPIO 27', (100, 116, 139)),
    ('D26', 'OLED SCK (Clock)', (245, 158, 11)),
    ('D25', 'OLED SDA (Data)', (16, 185, 129)),
    ('D33', 'RFID SCK (Clock)', (148, 163, 184)),
    ('D32', 'Active Buzzer (+)', (168, 85, 247)),
    ('D35', 'RFID MISO', (241, 245, 249)),
    ('D34', 'GPIO 34', (100, 116, 139)),
    ('VN',  'Sensor VN', (100, 116, 139)),
    ('VP',  'Sensor VP', (100, 116, 139)),
    ('EN',  'Chip Enable', (100, 116, 139)),
]

pin_pitch = 28
pin_start_y = pcb_y + 40

left_pin_coords = {}
right_pin_coords = {}

# Draw Left Pin Header
for i, (p_name, p_desc, p_clr) in enumerate(left_pins):
    py = pin_start_y + i * pin_pitch
    px = pcb_x + 12
    draw.ellipse([px - 5, py - 5, px + 5, py + 5], fill=(245, 158, 11), outline=(255, 255, 255))
    draw.text((px - 32, py - 6), p_name, fill=p_clr, font=font_badge)
    left_pin_coords[p_name] = (px, py)

# Draw Right Pin Header
for i, (p_name, p_desc, p_clr) in enumerate(right_pins):
    py = pin_start_y + i * pin_pitch
    px = pcb_x + pcb_w - 12
    draw.ellipse([px - 5, py - 5, px + 5, py + 5], fill=(245, 158, 11), outline=(255, 255, 255))
    draw.text((px + 10, py - 6), p_name, fill=p_clr, font=font_badge)
    right_pin_coords[p_name] = (px, py)

# =========================================================================
# RIGHT: BREADBOARD WITH RFID, OLED, AND BUZZER
# =========================================================================
bb_x, bb_y = 445, 90
bb_w, bb_h = 1430, 540

draw.rectangle([bb_x, bb_y, bb_x + bb_w, bb_y + bb_h], fill=(250, 250, 252), outline=(203, 213, 225), width=3)

# Top Power rails UP
up_plus_y = bb_y + 45
up_minus_y = bb_y + 75
draw.line([bb_x + 20, up_plus_y - 12, bb_x + bb_w - 20, up_plus_y - 12], fill=(239, 68, 68), width=3)
draw.text((bb_x + 6, up_plus_y - 10), '+', fill=(239, 68, 68), font=font_block)

draw.line([bb_x + 20, up_minus_y + 12, bb_x + bb_w - 20, up_minus_y + 12], fill=(59, 130, 246), width=3)
draw.text((bb_x + 8, up_minus_y - 8), '-', fill=(59, 130, 246), font=font_block)

# Bottom Power rails DOWN
down_plus_y = bb_y + bb_h - 75
down_minus_y = bb_y + bb_h - 45
draw.line([bb_x + 20, down_plus_y - 12, bb_x + bb_w - 20, down_plus_y - 12], fill=(239, 68, 68), width=3)
draw.text((bb_x + 6, down_plus_y - 10), '+', fill=(239, 68, 68), font=font_block)

draw.line([bb_x + 20, down_minus_y + 12, bb_x + bb_w - 20, down_minus_y + 12], fill=(59, 130, 246), width=3)
draw.text((bb_x + 8, down_minus_y - 8), '-', fill=(59, 130, 246), font=font_block)

# Grid rows A-E and F-J
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

# Center divider
trough_y = (row_y['E'] + row_y['F']) // 2
draw.rectangle([bb_x + 20, trough_y - 8, bb_x + bb_w - 20, trough_y + 8], fill=(226, 232, 240))

# Row Labels
for r_name, ry in row_y.items():
    draw.text((bb_x + 10, ry - 7), r_name, fill=(100, 116, 139), font=font_block)
    draw.text((bb_x + bb_w - 25, ry - 7), r_name, fill=(100, 116, 139), font=font_block)

col_start_x = bb_x + 40
col_pitch = 22.5

# 10 Blocks: A to J with 5 holes each
block_letters = ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J']
block_holes = {}

for b_idx, b_let in enumerate(block_letters):
    base_col = b_idx * 6
    b_center_x = col_start_x + (base_col + 2) * col_pitch
    
    # Block Badge
    draw.rectangle([b_center_x - 22, bb_y + 8, b_center_x + 22, bb_y + 24], fill=(254, 226, 226), outline=(239, 68, 68))
    draw.text((b_center_x - 20, bb_y + 9), f'Blk {b_let}', fill=(185, 28, 28), font=font_hole)
    
    for h_i in range(1, 6):
        c = base_col + (h_i - 1)
        block_holes[c] = (b_let, h_i)

# Draw columns and holes
for c in range(60):
    cx = col_start_x + c * col_pitch
    
    if c in block_holes:
        b_let, h_i = block_holes[c]
        # UP Power holes
        draw.ellipse([cx - 3, up_plus_y - 3, cx + 3, up_plus_y + 3], fill=(220, 220, 220), outline=(140, 140, 140))
        draw.ellipse([cx - 3, up_minus_y - 3, cx + 3, up_minus_y + 3], fill=(220, 220, 220), outline=(140, 140, 140))
        
        # DOWN Power holes
        draw.ellipse([cx - 3, down_plus_y - 3, cx + 3, down_plus_y + 3], fill=(220, 220, 220), outline=(140, 140, 140))
        draw.ellipse([cx - 3, down_minus_y - 3, cx + 3, down_minus_y + 3], fill=(220, 220, 220), outline=(140, 140, 140))
    
    # Main grid holes A to J
    for r_name in ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J']:
        ry = row_y[r_name]
        draw.ellipse([cx - 3, ry - 3, cx + 3, ry + 3], fill=(220, 220, 220), outline=(140, 140, 140))
        
    if c % 5 == 0:
        draw.text((cx - 6, grid_start_y - 18), str(c), fill=(51, 65, 85), font=font_hole)

# =========================================================================
# COMPONENTS ON BREADBOARD
# =========================================================================

# 1. RC522 RFID READER (Cols 20-27, Row D)
rfid_x1 = col_start_x + 20 * col_pitch - 6
rfid_x2 = col_start_x + 27 * col_pitch + 6
rfid_y1 = row_y['D'] - 8
rfid_y2 = row_y['H'] + 8
draw.rectangle([rfid_x1, rfid_y1, rfid_x2, rfid_y2], fill=(37, 99, 235), outline=(30, 64, 175), width=2)
draw.text((rfid_x1 + 18, rfid_y1 + 25), 'RC522 RFID READER', fill=(255, 255, 255), font=font_section)
draw.text((rfid_x1 + 25, rfid_y1 + 55), 'Row D, Cols 20-27', fill=(219, 234, 254), font=font_callout)

rfid_pins = ['SDA', 'SCK', 'MOSI', 'MISO', 'IRQ', 'GND', 'RST', '3.3V']
rfid_coords = {}
for p_i, p_name in enumerate(rfid_pins):
    cx = col_start_x + (20 + p_i) * col_pitch
    draw.ellipse([cx - 4, row_y['D'] - 4, cx + 4, row_y['D'] + 4], fill=(254, 240, 138), outline=(202, 138, 4), width=1)
    draw.text((cx - 8, row_y['D'] - 16), p_name, fill=(30, 58, 138), font=font_badge)
    rfid_coords[p_name] = (cx, row_y['C'])

# 2. ACTIVE BUZZER (Cols 35 and 38)
c35_x = col_start_x + 35 * col_pitch
c38_x = col_start_x + 38 * col_pitch
draw.rectangle([c35_x - 10, row_y['D'] - 10, c38_x + 10, row_y['G'] + 10], fill=(15, 23, 42), outline=(100, 116, 139), width=2)
draw.text((c35_x + 4, row_y['E'] - 10), 'BUZZER', fill=(255, 255, 255), font=font_callout)

# Buzzer (+) and (-)
draw.ellipse([c35_x - 5, row_y['D'] - 5, c35_x + 5, row_y['D'] + 5], fill=(245, 158, 11), outline=(180, 83, 9), width=2)
draw.text((c35_x - 8, row_y['D'] - 18), '(+)', fill=(245, 158, 11), font=font_badge)

draw.ellipse([c38_x - 5, row_y['D'] - 5, c38_x + 5, row_y['D'] + 5], fill=(59, 130, 246), outline=(30, 64, 175), width=2)
draw.text((c38_x - 8, row_y['D'] - 18), '(-)', fill=(59, 130, 246), font=font_badge)

# 3. OLED DISPLAY (Cols 54-57 at Block J)
oled_x1 = col_start_x + 54 * col_pitch - 6
oled_x2 = col_start_x + 57 * col_pitch + 6
oled_y1 = row_y['D'] - 8
oled_y2 = row_y['I'] + 8
draw.rectangle([oled_x1, oled_y1, oled_x2, oled_y2], fill=(15, 23, 42), outline=(56, 189, 248), width=2)
draw.text((oled_x1 + 6, oled_y1 + 45), 'OLED DISPLAY', fill=(56, 189, 248), font=font_callout)
draw.text((oled_x1 + 10, oled_y1 + 70), '0.96" I2C Screen', fill=(148, 163, 184), font=font_hole)

oled_pins = ['GND', 'VDD', 'SCK', 'SDA']
oled_coords = {}
for o_i, o_name in enumerate(oled_pins):
    cx = col_start_x + (54 + o_i) * col_pitch
    draw.ellipse([cx - 4, row_y['D'] - 4, cx + 4, row_y['D'] + 4], fill=(186, 230, 253), outline=(2, 132, 199), width=1)
    draw.text((cx - 8, row_y['D'] - 18), o_name, fill=(2, 132, 199), font=font_badge)
    oled_coords[o_name] = (cx, row_y['C'])

# =========================================================================
# WIRING TRACES (FEMALE-TO-MALE FROM ESP32 TO BREADBOARD)
# =========================================================================

# Helper to draw clean path
def draw_trace(p_start, p_end, clr, width=3, y_offset=0):
    sx, sy = p_start
    ex, ey = p_end
    if y_offset != 0:
        draw.line([(sx, sy), (sx + 20, sy), (sx + 20, y_offset), (ex, y_offset), (ex, ey)], fill=clr, width=width)
    else:
        mid_x = (sx + ex) // 2
        draw.line([(sx, sy), (mid_x, sy), (mid_x, ey), (ex, ey)], fill=clr, width=width)

# 1. 3V3 POWER (ESP32 3V3 -> RC522 3.3V Col 27)
# DIRECT WIRE! THE REASON FOR METHOD 2!
esp_3v3 = left_pin_coords['3V3']
rfid_3v3 = rfid_coords['3.3V']
draw.line([(esp_3v3[0], esp_3v3[1]), (esp_3v3[0] - 25, esp_3v3[1]), (esp_3v3[0] - 25, 48), (rfid_3v3[0], 48), (rfid_3v3[0], rfid_3v3[1])], fill=(239, 68, 68), width=5)
draw.text((esp_3v3[0] + 50, 40), '⚡ REAL 3.3V (500mA) DIRECT TO RC522 PIN 8!', fill=(239, 68, 68), font=font_callout)

# 2. ESP32 GND -> UP [-] Blue Rail (Col 5)
esp_gnd = right_pin_coords['GND']
up_gnd_target = (col_start_x + 5 * col_pitch, up_minus_y)
draw.line([(esp_gnd[0], esp_gnd[1]), (esp_gnd[0] + 15, esp_gnd[1]), (up_gnd_target[0], up_minus_y)], fill=(59, 130, 246), width=4)

# 3. ESP32 VIN -> OLED VDD (Col 55)
esp_vin = right_pin_coords['VIN']
oled_vdd = oled_coords['VDD']
draw.line([(esp_vin[0], esp_vin[1]), (esp_vin[0] + 35, esp_vin[1]), (esp_vin[0] + 35, up_plus_y), (oled_vdd[0], up_plus_y), (oled_vdd[0], oled_vdd[1])], fill=(245, 158, 11), width=4)

# 4. RC522 GND (Col 25) -> UP [-] Rail
rfid_gnd = rfid_coords['GND']
draw.line([rfid_gnd[0], rfid_gnd[1], rfid_gnd[0], up_minus_y], fill=(59, 130, 246), width=3)

# 5. RC522 RST (Col 26) -> ESP32 D14
esp_d14 = right_pin_coords['D14']
rfid_rst = rfid_coords['RST']
draw.line([(rfid_rst[0], rfid_rst[1]), (rfid_rst[0], rfid_rst[1] - 40), (esp_d14[0] + 50, rfid_rst[1] - 40), (esp_d14[0] + 50, esp_d14[1]), (esp_d14[0], esp_d14[1])], fill=(249, 115, 22), width=3)

# 6. RC522 SDA (Col 20) -> ESP32 D12
esp_d12 = right_pin_coords['D12']
rfid_sda = rfid_coords['SDA']
draw.line([(rfid_sda[0], rfid_sda[1]), (rfid_sda[0], rfid_sda[1] - 35), (esp_d12[0] + 40, rfid_sda[1] - 35), (esp_d12[0] + 40, esp_d12[1]), (esp_d12[0], esp_d12[1])], fill=(59, 130, 246), width=3)

# 7. RC522 SCK (Col 21) -> ESP32 D33
esp_d33 = right_pin_coords['D33']
rfid_sck = rfid_coords['SCK']
draw.line([(rfid_sck[0], rfid_sck[1]), (rfid_sck[0], rfid_sck[1] - 30), (esp_d33[0] + 30, rfid_sck[1] - 30), (esp_d33[0] + 30, esp_d33[1]), (esp_d33[0], esp_d33[1])], fill=(148, 163, 184), width=3)

# 8. RC522 MOSI (Col 22) -> ESP32 D13
esp_d13 = right_pin_coords['D13']
rfid_mosi = rfid_coords['MOSI']
draw.line([(rfid_mosi[0], rfid_mosi[1]), (rfid_mosi[0], rfid_mosi[1] - 25), (esp_d13[0] + 20, rfid_mosi[1] - 25), (esp_d13[0] + 20, esp_d13[1]), (esp_d13[0], esp_d13[1])], fill=(34, 197, 94), width=3)

# 9. RC522 MISO (Col 23) -> ESP32 D35
esp_d35 = right_pin_coords['D35']
rfid_miso = rfid_coords['MISO']
draw.line([(rfid_miso[0], rfid_miso[1]), (rfid_miso[0], rfid_miso[1] - 20), (esp_d35[0] + 15, rfid_miso[1] - 20), (esp_d35[0] + 15, esp_d35[1]), (esp_d35[0], esp_d35[1])], fill=(241, 245, 249), width=3)

# 10. Buzzer (+) [Col 35] -> ESP32 D32
esp_d32 = right_pin_coords['D32']
draw.line([(c35_x, row_y['C']), (c35_x, row_y['A'] - 15), (esp_d32[0] + 60, row_y['A'] - 15), (esp_d32[0] + 60, esp_d32[1]), (esp_d32[0], esp_d32[1])], fill=(168, 85, 247), width=3)

# 11. Buzzer (-) [Col 38] -> UP [-] Rail
draw.line([c38_x, row_y['C'], c38_x, up_minus_y], fill=(59, 130, 246), width=3)

# 12. OLED GND (Col 54) -> UP [-] Rail
oled_gnd = oled_coords['GND']
draw.line([oled_gnd[0], oled_gnd[1], oled_gnd[0], up_minus_y], fill=(59, 130, 246), width=3)

# 13. OLED SCK (Col 56) -> ESP32 D26
esp_d26 = right_pin_coords['D26']
oled_sck = oled_coords['SCK']
draw.line([(oled_sck[0], oled_sck[1]), (oled_sck[0], row_y['A'] - 20), (esp_d26[0] + 70, row_y['A'] - 20), (esp_d26[0] + 70, esp_d26[1]), (esp_d26[0], esp_d26[1])], fill=(245, 158, 11), width=3)

# 14. OLED SDA (Col 57) -> ESP32 D25
esp_d25 = right_pin_coords['D25']
oled_sda = oled_coords['SDA']
draw.line([(oled_sda[0], oled_sda[1]), (oled_sda[0], row_y['A'] - 25), (esp_d25[0] + 80, row_y['A'] - 25), (esp_d25[0] + 80, esp_d25[1]), (esp_d25[0], esp_d25[1])], fill=(16, 185, 129), width=3)

# =========================================================================
# BOTTOM CARDS (SUMMARY & TABLES)
# =========================================================================
card_y = 660
card_w = 580
card_h = 390

# Card 1: Master Wiring Table (Off-Board Setup)
draw.rectangle([45, card_y, 45 + card_w, card_y + card_h], fill=(24, 32, 47), outline=(56, 189, 248), width=2)
draw.text((65, card_y + 14), '📋 MASTER WIRING TABLE (OFF-BOARD F-M SETUP)', fill=(56, 189, 248), font=font_section)
card1_lines = [
    '• ESP32 3V3   -> RC522 Pin 8 (3.3V) [Col 27]   (⚡ Tunay na 3.3V!)',
    '• ESP32 GND   -> UP [-] Blue Rail              (System Ground)',
    '• ESP32 VIN   -> OLED Pin 2 (VDD) [Col 55]     (5V Power)',
    '• ESP32 D14   -> RC522 RST [Col 26]            (Reset Line)',
    '• ESP32 D12   -> RC522 SDA [Col 20]            (SPI Chip Select)',
    '• ESP32 D33   -> RC522 SCK [Col 21]            (SPI Clock)',
    '• ESP32 D13   -> RC522 MOSI [Col 22]           (SPI MOSI)',
    '• ESP32 D35   -> RC522 MISO [Col 23]           (SPI MISO)',
    '• ESP32 D26   -> OLED SCK / SCL [Col 56]       (I2C Clock)',
    '• ESP32 D25   -> OLED SDA [Col 57]             (I2C Data)',
    '• ESP32 D32   -> Buzzer (+) [Col 35]           (Beep Audio)',
    '• Buzzer (-)  -> UP [-] Blue Rail              (Col 38 Ground)',
]
cy = card_y + 48
for l in card1_lines:
    draw.text((65, cy), l, fill=(241, 245, 249), font=font_sub)
    cy += 27

# Card 2: Bakit Ito ang Pinakamadali at 100% Gagana
draw.rectangle([665, card_y, 665 + card_w, card_y + card_h], fill=(24, 32, 47), outline=(34, 197, 94), width=2)
draw.text((685, card_y + 14), '🌟 BAKIT ITO ANG PINAKAMAGANDANG PARAAN?', fill=(74, 222, 128), font=font_section)
card2_lines = [
    '1. TUNAY NA 3.3V REGULATOR POWER (500mA):',
    '   Nakalantad na ang mismong 3V3 pin ng ESP32. Hindi na',
    '   magkukulang ng kuryente ang RFID antenna kapag nag-tap!',
    '',
    '2. WALANG NATATAKPANG BUTAS:',
    '   Malinis at maluwag ang breadboard. Hindi na kailangang',
    '   magsiksikan sa iisang row ng butas.',
    '',
    '3. HINDI MAGAGALAW ANG MGA COMPONENT:',
    '   Ang RFID, Buzzer, at OLED ay nananatiling nakatayo',
    '   sa kanilang eksaktong pwesto sa breadboard.',
    '',
    '4. 100% TUGMA SA CURRENT FIRMWARE:',
    '   Walang babaguhin sa Arduino code! Lahat ng pin numbers',
    '   ay eksaktong pareho pa rin.',
]
cy = card_y + 48
for l in card2_lines:
    draw.text((685, cy), l, fill=(241, 245, 249), font=font_sub)
    cy += 25

# Card 3: Paano Ligtas na Tatanggalin ang ESP32
draw.rectangle([1285, card_y, 1285 + card_w, card_y + card_h], fill=(24, 32, 47), outline=(245, 158, 11), width=2)
draw.text((1305, card_y + 14), '🛡️ ZERO-DAMAGE ESP32 REMOVAL GUIDE', fill=(251, 191, 36), font=font_section)
card3_lines = [
    'Paano tatanggalin nang ligtas nang walang nababaling pin:',
    '',
    '1. HUWAG HIHILAHIN SA GITNA GAMIT ANG KAMAY:',
    '   Mababali ang board kapag hinila lang sa gitna.',
    '',
    '2. GUMAMIT NG PLASTIC CARD (ATM card / Ruler / ID):',
    '   Isuksok ang plastic card sa ilalim ng dulo ng ESP32',
    '   (malapit sa micro-USB port).',
    '',
    '3. SALIT-SALITANG I-ANGAT NANG 1 MILLIMETER:',
    '   • I-angat nang 1mm ang itaas na dulo.',
    '   • Lumipat sa ibabang dulo, i-angat nang 1mm.',
    '   • Ulitin hanggang dahan-dahang kumalas ang lahat',
    '     ng metal clips sa breadboard.',
    '',
    'Napakadali at 100% ligtas ang mga pins!',
]
cy = card_y + 48
for l in card3_lines:
    draw.text((1305, cy), l, fill=(241, 245, 249), font=font_sub)
    cy += 25

# Save images (Preserving exact_breadboard_hole_diagram.jpg!)
out_dir = 'docs/hardware'
out_path = os.path.join(out_dir, 'offboard_esp32_breadboard_diagram.jpg')
img.save(out_path, quality=95)
print('Saved to:', out_path)

# Copy to artifacts directory under a NEW name so exact_breadboard_hole_diagram.jpg is 100% untouched
artifact_dir = r'C:/Users/Admin/.gemini/antigravity/brain/612cfb69-8680-4c79-a00a-dd82e013b40f'
artifact_path = os.path.join(artifact_dir, 'offboard_esp32_breadboard_diagram.jpg')
shutil.copyfile(out_path, artifact_path)
print('Copied to artifact:', artifact_path)
