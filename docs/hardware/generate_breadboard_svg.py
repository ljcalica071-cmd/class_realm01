"""
Generator for High-Resolution Vector Fritzing-Style Breadboard Wiring Diagram
Customized for User's Exact Hardware Kit & Wire Types:
- Breadboard: 830-tie point, ESP32 plugged directly at Rows 46 to 60 (leaving Hole A & Hole J free)
- BLACK Wire: M-M (Male-to-Male)
- WHITE Wire: F-F (Female-to-Female)
- BLUE Wire: F-M (Female-to-Male)
- YELLOW Wire: Maliit na U-shaped breadboard jumper
"""

def generate_svg():
    width = 1750
    height = 1250
    
    # Breadboard geometry (drawn horizontally for wide desktop viewing or standard orientation)
    # Let's draw the breadboard horizontally:
    # 63 columns (rows 1 to 60 labelled)
    bb_x = 70
    bb_y = 260
    bb_w = 1600
    bb_h = 580
    
    col_x_start = bb_x + 95
    dx = 23.5
    
    # Rows Y coordinates:
    # Top Power: (-) Blue rail, (+) Red rail
    top_rail_minus_y = bb_y + 40
    top_rail_plus_y  = bb_y + 70
    
    # Upper strip: Rows A, B, C, D, E
    row_a_y = bb_y + 125
    row_b_y = bb_y + 152
    row_c_y = bb_y + 179
    row_d_y = bb_y + 206
    row_e_y = bb_y + 233
    
    # Divider trench at bb_y + 270 (height 40)
    trench_y = bb_y + 270
    
    # Lower strip: Rows F, G, H, I, J
    row_f_y = bb_y + 345
    row_g_y = bb_y + 372
    row_h_y = bb_y + 399
    row_i_y = bb_y + 426
    row_j_y = bb_y + 453
    
    # Bottom Power: (+) Red rail, (-) Blue rail
    bot_rail_plus_y  = bb_y + 510
    bot_rail_minus_y = bb_y + 540
    
    def get_col_x(col):
        # 1-indexed: col 1..60
        return col_x_start + (col - 1) * dx

    svg = []
    svg.append(f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {width} {height}" width="100%" height="100%" style="background:#090D16; font-family: -apple-system, BlinkMacSystemFont, \'Segoe UI\', Roboto, sans-serif;">')
    
    # Defs
    svg.append('''<defs>
      <filter id="shadow-main" x="-10%" y="-10%" width="130%" height="130%">
        <feDropShadow dx="0" dy="10" stdDeviation="14" flood-color="#000000" flood-opacity="0.6"/>
      </filter>
      <filter id="shadow-wire" x="-20%" y="-20%" width="140%" height="140%">
        <feDropShadow dx="0" dy="4" stdDeviation="3.5" flood-color="#000000" flood-opacity="0.5"/>
      </filter>
      <filter id="glow-green" x="-30%" y="-30%" width="160%" height="160%">
        <feGaussianBlur stdDeviation="5" result="blur" />
        <feMerge><feMergeNode in="blur"/><feMergeNode in="SourceGraphic"/></feMerge>
      </filter>
      <filter id="glow-red" x="-30%" y="-30%" width="160%" height="160%">
        <feGaussianBlur stdDeviation="5" result="blur" />
        <feMerge><feMergeNode in="blur"/><feMergeNode in="SourceGraphic"/></feMerge>
      </filter>
      <linearGradient id="bb-body" x1="0%" y1="0%" x2="0%" y2="100%">
        <stop offset="0%" stop-color="#F8FAFC"/>
        <stop offset="100%" stop-color="#E2E8F0"/>
      </linearGradient>
      <linearGradient id="esp-pcb" x1="0%" y1="0%" x2="100%" y2="100%">
        <stop offset="0%" stop-color="#1E293B"/>
        <stop offset="100%" stop-color="#0F172A"/>
      </linearGradient>
      <linearGradient id="metal-shield" x1="0%" y1="0%" x2="100%" y2="100%">
        <stop offset="0%" stop-color="#E2E8F0"/>
        <stop offset="50%" stop-color="#94A3B8"/>
        <stop offset="100%" stop-color="#CBD5E1"/>
      </linearGradient>
      <linearGradient id="rfid-blue" x1="0%" y1="0%" x2="0%" y2="100%">
        <stop offset="0%" stop-color="#1D4ED8"/>
        <stop offset="100%" stop-color="#1E40AF"/>
      </linearGradient>
      <linearGradient id="oled-blue" x1="0%" y1="0%" x2="0%" y2="100%">
        <stop offset="0%" stop-color="#2563EB"/>
        <stop offset="100%" stop-color="#1D4ED8"/>
      </linearGradient>
      <linearGradient id="resistor-body" x1="0%" y1="0%" x2="100%" y2="0%">
        <stop offset="0%" stop-color="#D4B996"/>
        <stop offset="50%" stop-color="#F3E5AB"/>
        <stop offset="100%" stop-color="#D4B996"/>
      </linearGradient>
    </defs>''')
    
    # Top Header & User Kit Color Legend Pill
    svg.append(f'''
    <!-- Top Header -->
    <rect x="0" y="0" width="{width}" height="105" fill="#111827"/>
    <text x="70" y="42" fill="#38BDF8" font-size="22" font-weight="800" letter-spacing="1">CLASSREALM HARDWARE ASSEMBLY GUIDE</text>
    <text x="70" y="78" fill="#F8FAFC" font-size="26" font-weight="700">ESP32 Plugged Directly into 830-Tie Breadboard (Custom Wire Coding)</text>
    
    <!-- User Kit Legend Pill Box -->
    <g transform="translate({width - 660}, 20)">
      <rect x="0" y="0" width="590" height="65" rx="10" fill="#1F2937" stroke="#374151" stroke-width="1.5"/>
      <text x="15" y="24" fill="#9CA3AF" font-size="11" font-weight="700">YOUR WIRE KIT CODING:</text>
      
      <circle cx="22" cy="45" r="7" fill="#111827" stroke="#9CA3AF" stroke-width="1.5"/>
      <text x="35" y="49" fill="#F9FAFB" font-size="12" font-weight="700">BLACK (M-M)</text>

      <circle cx="165" cy="45" r="7" fill="#3B82F6" stroke="#1D4ED8" stroke-width="1.5"/>
      <text x="178" y="49" fill="#F9FAFB" font-size="12" font-weight="700">BLUE (F-M)</text>

      <circle cx="295" cy="45" r="7" fill="#F9FAFB" stroke="#9CA3AF" stroke-width="1.5"/>
      <text x="308" y="49" fill="#F9FAFB" font-size="12" font-weight="700">WHITE (F-F)</text>

      <rect x="425" y="40" width="22" height="10" rx="3" fill="#EAB308" stroke="#CA8A04" stroke-width="1"/>
      <text x="455" y="49" fill="#F9FAFB" font-size="12" font-weight="700">YELLOW (U-Jumper)</text>
    </g>
    ''')

    # ------------------ BREADBOARD BODY ------------------
    svg.append(f'''
    <!-- Breadboard Outer Base -->
    <g filter="url(#shadow-main)">
      <rect x="{bb_x}" y="{bb_y}" width="{bb_w}" height="{bb_h}" rx="22" fill="url(#bb-body)" stroke="#CBD5E1" stroke-width="3"/>
      
      <!-- Power Rail Colored Lines -->
      <line x1="{bb_x + 60}" y1="{top_rail_minus_y - 12}" x2="{bb_x + bb_w - 60}" y2="{top_rail_minus_y - 12}" stroke="#2563EB" stroke-width="3" stroke-linecap="round"/>
      <line x1="{bb_x + 60}" y1="{top_rail_plus_y + 12}" x2="{bb_x + bb_w - 60}" y2="{top_rail_plus_y + 12}" stroke="#DC2626" stroke-width="3" stroke-linecap="round"/>
      
      <line x1="{bb_x + 60}" y1="{bot_rail_plus_y - 12}" x2="{bb_x + bb_w - 60}" y2="{bot_rail_plus_y - 12}" stroke="#DC2626" stroke-width="3" stroke-linecap="round"/>
      <line x1="{bb_x + 60}" y1="{bot_rail_minus_y + 12}" x2="{bb_x + bb_w - 60}" y2="{bot_rail_minus_y + 12}" stroke="#2563EB" stroke-width="3" stroke-linecap="round"/>

      <!-- Polarity Symbols -->
      <text x="{bb_x + 35}" y="{top_rail_minus_y + 5}" fill="#2563EB" font-size="18" font-weight="900" text-anchor="middle">-</text>
      <text x="{bb_x + 35}" y="{top_rail_plus_y + 5}" fill="#DC2626" font-size="18" font-weight="900" text-anchor="middle">+</text>
      <text x="{bb_x + bb_w - 35}" y="{top_rail_minus_y + 5}" fill="#2563EB" font-size="18" font-weight="900" text-anchor="middle">-</text>
      <text x="{bb_x + bb_w - 35}" y="{top_rail_plus_y + 5}" fill="#DC2626" font-size="18" font-weight="900" text-anchor="middle">+</text>

      <text x="{bb_x + 35}" y="{bot_rail_plus_y + 5}" fill="#DC2626" font-size="18" font-weight="900" text-anchor="middle">+</text>
      <text x="{bb_x + 35}" y="{bot_rail_minus_y + 5}" fill="#2563EB" font-size="18" font-weight="900" text-anchor="middle">-</text>
      <text x="{bb_x + bb_w - 35}" y="{bot_rail_plus_y + 5}" fill="#DC2626" font-size="18" font-weight="900" text-anchor="middle">+</text>
      <text x="{bb_x + bb_w - 35}" y="{bot_rail_minus_y + 5}" fill="#2563EB" font-size="18" font-weight="900" text-anchor="middle">-</text>

      <!-- Center Divider Trench -->
      <rect x="{bb_x + 50}" y="{trench_y}" width="{bb_w - 100}" height="35" rx="4" fill="#CBD5E1"/>
      <rect x="{bb_x + 52}" y="{trench_y + 2}" width="{bb_w - 104}" height="31" rx="3" fill="#94A3B8" opacity="0.45"/>
    </g>''')

    # Holes rendering
    def render_hole(cx, cy):
        return f'<rect x="{cx - 4.5}" y="{cy - 4.5}" width="9" height="9" rx="2" fill="#1E293B" stroke="#64748B" stroke-width="0.8"/>'
    
    holes_svg = ['<g id="breadboard-holes" opacity="0.95">']
    for c in range(1, 61):
        cx = get_col_x(c)
        if c in [1, 5, 10, 15, 20, 25, 30, 35, 40, 45, 46, 50, 55, 60]:
            holes_svg.append(f'<text x="{cx}" y="{row_a_y - 18}" fill="#64748B" font-size="9" font-weight="700" text-anchor="middle">{c}</text>')
            holes_svg.append(f'<text x="{cx}" y="{row_j_y + 26}" fill="#64748B" font-size="9" font-weight="700" text-anchor="middle">{c}</text>')
            
        # Top power rails
        holes_svg.append(render_hole(cx, top_rail_minus_y))
        holes_svg.append(render_hole(cx, top_rail_plus_y))

        # Upper terminal rows (A, B, C, D, E)
        holes_svg.append(render_hole(cx, row_a_y))
        holes_svg.append(render_hole(cx, row_b_y))
        holes_svg.append(render_hole(cx, row_c_y))
        holes_svg.append(render_hole(cx, row_d_y))
        holes_svg.append(render_hole(cx, row_e_y))

        # Lower terminal rows (F, G, H, I, J)
        holes_svg.append(render_hole(cx, row_f_y))
        holes_svg.append(render_hole(cx, row_g_y))
        holes_svg.append(render_hole(cx, row_h_y))
        holes_svg.append(render_hole(cx, row_i_y))
        holes_svg.append(render_hole(cx, row_j_y))

        # Bottom power rails
        holes_svg.append(render_hole(cx, bot_rail_plus_y))
        holes_svg.append(render_hole(cx, bot_rail_minus_y))

    # Row Letters Labels on sides
    for (label, y_pos) in [('A', row_a_y), ('B', row_b_y), ('C', row_c_y), ('D', row_d_y), ('E', row_e_y),
                           ('F', row_f_y), ('G', row_g_y), ('H', row_h_y), ('I', row_i_y), ('J', row_j_y)]:
        holes_svg.append(f'<text x="{bb_x + 58}" y="{y_pos + 4}" fill="#64748B" font-size="11" font-weight="800" text-anchor="middle">{label}</text>')
        holes_svg.append(f'<text x="{bb_x + bb_w - 58}" y="{y_pos + 4}" fill="#64748B" font-size="11" font-weight="800" text-anchor="middle">{label}</text>')

    holes_svg.append('</g>')
    svg.append('\n'.join(holes_svg))

    # ------------------ ESP32 PLUGGED AT ROWS 46 TO 60 ------------------
    # As shown in user's photo 2:
    # Placed across center trench.
    # Upper pins plug into Row B (leaving Row A free on top!)
    # Lower pins plug into Row I (leaving Row J free on bottom!)
    esp_c_start = 46
    esp_c_end = 60
    esp_x1 = get_col_x(esp_c_start) - 18
    esp_x2 = get_col_x(esp_c_end) + 18
    esp_w = esp_x2 - esp_x1
    esp_y = row_b_y - 12
    esp_h = (row_i_y + 12) - esp_y
    
    svg.append(f'''
    <!-- ESP32 DevKit Module (Plugged at Rows 46 to 60) -->
    <g id="esp32-plugged" filter="url(#shadow-main)">
      <!-- PCB Body covering Rows B, C, D, E, F, G, H, I -->
      <rect x="{esp_x1}" y="{esp_y}" width="{esp_w}" height="{esp_h}" rx="10" fill="url(#esp-pcb)" stroke="#334155" stroke-width="2.5"/>

      <!-- MicroUSB Port at Right end (Row 60) -->
      <rect x="{esp_x2 - 4}" y="{esp_y + (esp_h/2) - 16}" width="16" height="32" rx="3" fill="#94A3B8" stroke="#475569" stroke-width="1.5"/>
      <rect x="{esp_x2}" y="{esp_y + (esp_h/2) - 10}" width="7" height="20" rx="1.5" fill="#1E293B"/>

      <!-- Metal RF Shield (WROOM-32) -->
      <rect x="{esp_x1 + 35}" y="{esp_y + 18}" width="180" height="{esp_h - 36}" rx="5" fill="url(#metal-shield)" stroke="#64748B" stroke-width="1.5"/>
      <text x="{esp_x1 + 125}" y="{esp_y + (esp_h/2) - 10}" fill="#0F172A" font-size="14" font-weight="900" text-anchor="middle">ESP-WROOM-32</text>
      <text x="{esp_x1 + 125}" y="{esp_y + (esp_h/2) + 10}" fill="#334155" font-size="9" font-weight="700" text-anchor="middle">Wi-Fi + BT + BLE</text>
      <text x="{esp_x1 + 125}" y="{esp_y + (esp_h/2) + 24}" fill="#475569" font-size="8" font-weight="800" text-anchor="middle">30-PIN DEVKIT V1</text>

      <!-- PCB Antenna at Left end (near Row 46) -->
      <rect x="{esp_x1 + 6}" y="{esp_y + 20}" width="22" height="{esp_h - 40}" rx="3" fill="#92400E" stroke="#78350F" stroke-width="1"/>
      <path d="M {esp_x1 + 10} {esp_y + 26} h 14 v 7 h -14 v 7 h 14 v 7 h -14 v 7 h 14 v 7 h -14 v 7 h 14" fill="none" stroke="#FDE047" stroke-width="2" stroke-linecap="round"/>

      <!-- Push buttons: EN & BOOT -->
      <rect x="{esp_x2 - 32}" y="{esp_y + 14}" width="14" height="12" rx="2" fill="#E2E8F0" stroke="#475569" stroke-width="1"/>
      <circle cx="{esp_x2 - 25}" cy="{esp_y + 20}" r="2.5" fill="#DC2626"/>
      <text x="{esp_x2 - 25}" y="{esp_y + 36}" fill="#94A3B8" font-size="7" font-weight="800" text-anchor="middle">EN</text>

      <rect x="{esp_x2 - 32}" y="{esp_y + esp_h - 26}" width="14" height="12" rx="2" fill="#E2E8F0" stroke="#475569" stroke-width="1"/>
      <circle cx="{esp_x2 - 25}" cy="{esp_y + esp_h - 20}" r="2.5" fill="#2563EB"/>
      <text x="{esp_x2 - 25}" y="{esp_y + esp_h - 32}" fill="#94A3B8" font-size="7" font-weight="800" text-anchor="middle">BOOT</text>

      <!-- Indicator arrow pointing to accessible hole A & J -->
      <rect x="{esp_x1}" y="{row_a_y - 2}" width="{esp_w}" height="4" fill="#38BDF8" opacity="0.3"/>
      <rect x="{esp_x1}" y="{row_j_y - 2}" width="{esp_w}" height="4" fill="#38BDF8" opacity="0.3"/>
    </g>''')

    # Mapping of ESP32 Pins on the breadboard rows 46 to 60:
    # Row 60 (near USB) down to Row 46 (near antenna):
    # Top side (Hole A is free!):
    # Col 60: 3V3
    # Col 59: GND
    # Col 58: D15
    # Col 57: D2
    # Col 56: D4  (RFID RST)
    # Col 55: RX2
    # Col 54: TX2
    # Col 53: D5  (RFID SDA)
    # Col 52: D18 (RFID SCK)
    # Col 51: D19 (RFID MISO)
    # Col 50: D21 (OLED SDA)
    # Col 49: RX0
    # Col 48: TX0
    # Col 47: D22 (OLED SCL)
    # Col 46: D23 (RFID MOSI)
    esp_top_pins = {
        60: ('3V3', True, '#EF4444'),
        59: ('GND', True, '#000000'),
        58: ('D15', False, '#64748B'),
        57: ('D2',  False, '#64748B'),
        56: ('D4',  True, '#3B82F6'),  # Blue F-M to RFID RST
        55: ('RX2', False, '#64748B'),
        54: ('TX2', False, '#64748B'),
        53: ('D5',  True, '#3B82F6'),  # Blue F-M to RFID SDA
        52: ('D18', True, '#3B82F6'),  # Blue F-M to RFID SCK
        51: ('D19', True, '#3B82F6'),  # Blue F-M to RFID MISO
        50: ('D21', True, '#3B82F6'),  # Blue F-M to OLED SDA
        49: ('RX0', False, '#64748B'),
        48: ('TX0', False, '#64748B'),
        47: ('D22', True, '#3B82F6'),  # Blue F-M to OLED SCL
        46: ('D23', True, '#3B82F6'),  # Blue F-M to RFID MOSI
    }

    # Bottom side (Hole J is free!):
    # Col 60: VIN
    # Col 59: GND
    # Col 58: D13
    # Col 57: D12
    # Col 56: D14 (Red LED Anode)
    # Col 55: D27 (Green LED Anode)
    # Col 54: D26
    # Col 53: D25
    # Col 52: D33
    # Col 51: D32 (Buzzer +)
    # Col 50: D35
    # Col 49: D34
    # Col 48: VN
    # Col 47: VP
    # Col 46: EN
    esp_bot_pins = {
        60: ('VIN', False, '#64748B'),
        59: ('GND', False, '#64748B'),
        58: ('D13', False, '#64748B'),
        57: ('D12', False, '#64748B'),
        56: ('D14', True, '#111827'),  # Black M-M to Red LED
        55: ('D27', True, '#111827'),  # Black M-M to Green LED
        54: ('D26', False, '#64748B'),
        53: ('D25', False, '#64748B'),
        52: ('D33', False, '#64748B'),
        51: ('D32', True, '#111827'),  # Black M-M to Buzzer (+)
        50: ('D35', False, '#64748B'),
        49: ('D34', False, '#64748B'),
        48: ('VN',  False, '#64748B'),
        47: ('VP',  False, '#64748B'),
        46: ('EN',  False, '#64748B'),
    }

    esp_labels_svg = ['<!-- ESP32 Pin Labels on Board Silkscreen & Hole A/J Rings -->']
    for col, (pname, is_used, wire_clr) in esp_top_pins.items():
        cx = get_col_x(col)
        # Highlight Hole A
        if is_used:
            esp_labels_svg.append(f'<circle cx="{cx}" cy="{row_a_y}" r="6" fill="none" stroke="{wire_clr}" stroke-width="2.5"/>')
        # Silkscreen text on ESP32 board
        esp_labels_svg.append(f'<text x="{cx}" y="{row_b_y + 12}" fill="{"#38BDF8" if is_used else "#94A3B8"}" font-size="9" font-weight="{"800" if is_used else "600"}" text-anchor="middle">{pname}</text>')
        # Hole A indicator
        esp_labels_svg.append(f'<text x="{cx}" y="{row_a_y - 7}" fill="{"#F8FAFC" if is_used else "#64748B"}" font-size="8" font-weight="700" text-anchor="middle">A{col}</text>')

    for col, (pname, is_used, wire_clr) in esp_bot_pins.items():
        cx = get_col_x(col)
        if is_used:
            esp_labels_svg.append(f'<circle cx="{cx}" cy="{row_j_y}" r="6" fill="none" stroke="{wire_clr}" stroke-width="2.5"/>')
        esp_labels_svg.append(f'<text x="{cx}" y="{row_i_y - 4}" fill="{"#38BDF8" if is_used else "#94A3B8"}" font-size="9" font-weight="{"800" if is_used else "600"}" text-anchor="middle">{pname}</text>')
        esp_labels_svg.append(f'<text x="{cx}" y="{row_j_y + 15}" fill="{"#F8FAFC" if is_used else "#64748B"}" font-size="8" font-weight="700" text-anchor="middle">J{col}</text>')

    svg.append('\n'.join(esp_labels_svg))


    # ------------------ EXTERNAL MODULES (RFID & OLED) ------------------

    # 1. RC522 RFID Scanner (Placed on table above left breadboard cols 2 to 16)
    rfid_x = bb_x + 50
    rfid_y = 110
    rfid_w = 260
    rfid_h = 130
    svg.append(f'''
    <!-- RC522 RFID Module (External / Beside Breadboard) -->
    <g id="rfid-module" filter="url(#shadow-main)">
      <rect x="{rfid_x}" y="{rfid_y}" width="{rfid_w}" height="{rfid_h}" rx="12" fill="url(#rfid-blue)" stroke="#60A5FA" stroke-width="2"/>
      
      <!-- Mounting holes -->
      <circle cx="{rfid_x + 10}" cy="{rfid_y + 10}" r="4" fill="#090D16" stroke="#93C5FD" stroke-width="1"/>
      <circle cx="{rfid_x + rfid_w - 10}" cy="{rfid_y + 10}" r="4" fill="#090D16" stroke="#93C5FD" stroke-width="1"/>
      <circle cx="{rfid_x + 10}" cy="{rfid_y + rfid_h - 10}" r="4" fill="#090D16" stroke="#93C5FD" stroke-width="1"/>
      <circle cx="{rfid_x + rfid_w - 10}" cy="{rfid_y + rfid_h - 10}" r="4" fill="#090D16" stroke="#93C5FD" stroke-width="1"/>

      <!-- Antenna coil -->
      <rect x="{rfid_x + 15}" y="{rfid_y + 15}" width="110" height="{rfid_h - 30}" rx="6" fill="none" stroke="#FDE047" stroke-width="1.8"/>
      <text x="{rfid_x + 70}" y="{rfid_y + 70}" fill="#FFFFFF" font-size="11" font-weight="900" text-anchor="middle">RC522 RFID</text>
      <text x="{rfid_x + 70}" y="{rfid_y + 86}" fill="#93C5FD" font-size="8" font-weight="700" text-anchor="middle">13.56 MHz</text>

      <!-- MFRC522 IC -->
      <rect x="{rfid_x + 140}" y="{rfid_y + 35}" width="30" height="30" rx="3" fill="#0F172A" stroke="#475569" stroke-width="1"/>
      <text x="{rfid_x + 155}" y="{rfid_y + 53}" fill="#E2E8F0" font-size="7" font-weight="800" text-anchor="middle">MFRC</text>

      <!-- 8-Pin Male Header Strip at Bottom Edge -->
      <rect x="{rfid_x + 30}" y="{rfid_y + rfid_h - 16}" width="200" height="14" rx="2" fill="#1E293B" stroke="#475569" stroke-width="1"/>
    </g>''')

    # RFID Pins (8 pins along bottom edge of module)
    rfid_pin_data = [
        ('SDA',  rfid_x + 45),
        ('SCK',  rfid_x + 70),
        ('MOSI', rfid_x + 95),
        ('MISO', rfid_x + 120),
        ('IRQ',  rfid_x + 145),
        ('GND',  rfid_x + 170),
        ('RST',  rfid_x + 195),
        ('3.3V', rfid_x + 220),
    ]
    rfid_pins_svg = []
    for pname, px in rfid_pin_data:
        py = rfid_y + rfid_h - 9
        rfid_pins_svg.append(f'<circle cx="{px}" cy="{py}" r="4" fill="#F59E0B" stroke="#000" stroke-width="1.5"/>')
        rfid_pins_svg.append(f'<text x="{px}" y="{py - 8}" fill="#F8FAFC" font-size="8" font-weight="800" text-anchor="middle">{pname}</text>')
    svg.append('\n'.join(rfid_pins_svg))


    # 2. 0.96-inch OLED Display (Placed on table above breadboard cols 25 to 38)
    oled_x = bb_x + 480
    oled_y = 110
    oled_w = 200
    oled_h = 130
    svg.append(f'''
    <!-- 0.96 inch I2C OLED Module -->
    <g id="oled-module" filter="url(#shadow-main)">
      <rect x="{oled_x}" y="{oled_y}" width="{oled_w}" height="{oled_h}" rx="10" fill="url(#oled-blue)" stroke="#60A5FA" stroke-width="2"/>
      
      <!-- Glass Screen -->
      <rect x="{oled_x + 12}" y="{oled_y + 12}" width="{oled_w - 24}" height="75" rx="5" fill="#050B14" stroke="#334155" stroke-width="1.5"/>
      <text x="{oled_x + (oled_w/2)}" y="{oled_y + 36}" fill="#FDE047" font-size="10" font-weight="900" text-anchor="middle">CLASSREALM RFID</text>
      <text x="{oled_x + (oled_w/2)}" y="{oled_y + 58}" fill="#38BDF8" font-size="13" font-weight="800" text-anchor="middle">&gt;&gt; TAP CARD &lt;&lt;</text>
      <text x="{oled_x + (oled_w/2)}" y="{oled_y + 75}" fill="#4ADE80" font-size="8" font-weight="700" text-anchor="middle">WiFi: Ready</text>

      <!-- 4-Pin Header at Bottom Edge -->
      <rect x="{oled_x + 25}" y="{oled_y + oled_h - 16}" width="150" height="14" rx="2" fill="#1E293B" stroke="#475569" stroke-width="1"/>
    </g>''')

    oled_pin_data = [
        ('GND', oled_x + 45),
        ('VCC', oled_x + 80),
        ('SCL', oled_x + 120),
        ('SDA', oled_x + 155),
    ]
    oled_pins_svg = []
    for pname, px in oled_pin_data:
        py = oled_y + oled_h - 9
        oled_pins_svg.append(f'<circle cx="{px}" cy="{py}" r="4" fill="#F59E0B" stroke="#000" stroke-width="1.5"/>')
        oled_pins_svg.append(f'<text x="{px}" y="{py - 8}" fill="#F8FAFC" font-size="8" font-weight="800" text-anchor="middle">{pname}</text>')
    svg.append('\n'.join(oled_pins_svg))


    # ------------------ ON-BREADBOARD COMPONENTS (BUZZER, LEDS, RESISTORS) ------------------

    # 1. Active Buzzer: Placed at Col 35 across Rows G & I (Row G = +, Row I = -)
    buzzer_x = get_col_x(35)
    buzzer_plus_y = row_g_y
    buzzer_minus_y = row_i_y
    svg.append(f'''
    <!-- Active Buzzer (Col 35) -->
    <g id="active-buzzer" filter="url(#shadow-main)">
      <circle cx="{buzzer_x}" cy="{(buzzer_plus_y + buzzer_minus_y)/2}" r="22" fill="#18181B" stroke="#3F3F46" stroke-width="2"/>
      <circle cx="{buzzer_x}" cy="{(buzzer_plus_y + buzzer_minus_y)/2}" r="6" fill="#09090B"/>
      <text x="{buzzer_x - 12}" y="{(buzzer_plus_y + buzzer_minus_y)/2 - 7}" fill="#EF4444" font-size="14" font-weight="900">+</text>
      <text x="{buzzer_x}" y="{(buzzer_plus_y + buzzer_minus_y)/2 + 16}" fill="#A1A1AA" font-size="7" font-weight="800" text-anchor="middle">BUZZER</text>
    </g>
    <!-- Buzzer Pins -->
    <circle cx="{buzzer_x}" cy="{buzzer_plus_y}" r="3.5" fill="#F59E0B" stroke="#000" stroke-width="1"/>
    <circle cx="{buzzer_x}" cy="{buzzer_minus_y}" r="3.5" fill="#F59E0B" stroke="#000" stroke-width="1"/>
    <text x="{buzzer_x}" y="{buzzer_plus_y - 7}" fill="#EF4444" font-size="8" font-weight="800" text-anchor="middle">G35 (+)</text>
    <text x="{buzzer_x}" y="{buzzer_minus_y + 14}" fill="#38BDF8" font-size="8" font-weight="800" text-anchor="middle">I35 (-)</text>
    ''')

    # 2. Green LED at Col 25: Anode at Row G, Cathode at Row I
    grn_x = get_col_x(25)
    grn_anode_y = row_g_y
    grn_cathode_y = row_i_y

    # 3. Red LED at Col 18: Anode at Row G, Cathode at Row I
    red_x = get_col_x(18)
    red_anode_y = row_g_y
    red_cathode_y = row_i_y

    svg.append(f'''
    <!-- Green LED (Col 25) -->
    <g id="green-led" filter="url(#glow-green)">
      <circle cx="{grn_x}" cy="{(grn_anode_y + grn_cathode_y)/2}" r="11" fill="#22C55E" stroke="#15803D" stroke-width="2" opacity="0.95"/>
      <ellipse cx="{grn_x - 2.5}" cy="{(grn_anode_y + grn_cathode_y)/2 - 2.5}" rx="3.5" ry="2" fill="#DCFCE7" opacity="0.8"/>
      <text x="{grn_x}" y="{grn_anode_y - 8}" fill="#22C55E" font-size="8" font-weight="800" text-anchor="middle">G25 (Anode +)</text>
      <text x="{grn_x}" y="{grn_cathode_y + 14}" fill="#94A3B8" font-size="8" font-weight="700" text-anchor="middle">I25 (Cathode -)</text>
    </g>
    <!-- 220 Ohm Resistor for Green LED (Col 25, Row I to Bottom Blue Rail) -->
    <g id="resistor-grn">
      <line x1="{grn_x}" y1="{grn_cathode_y}" x2="{grn_x}" y2="{bot_rail_minus_y}" stroke="#94A3B8" stroke-width="2.5" stroke-linecap="round"/>
      <rect x="{grn_x - 6}" y="{row_j_y + 12}" width="12" height="30" rx="3" fill="url(#resistor-body)" stroke="#A16207" stroke-width="1.2"/>
      <rect x="{grn_x - 6}" y="{row_j_y + 15}" width="12" height="3" fill="#DC2626"/>
      <rect x="{grn_x - 6}" y="{row_j_y + 21}" width="12" height="3" fill="#DC2626"/>
      <rect x="{grn_x - 6}" y="{row_j_y + 27}" width="12" height="3" fill="#78350F"/>
      <rect x="{grn_x - 6}" y="{row_j_y + 34}" width="12" height="3" fill="#F59E0B"/>
      <circle cx="{grn_x}" cy="{bot_rail_minus_y}" r="3.5" fill="#2563EB" stroke="#000" stroke-width="1"/>
      <text x="{grn_x + 15}" y="{row_j_y + 30}" fill="#CBD5E1" font-size="8" font-weight="700">220Ω</text>
    </g>

    <!-- Red LED (Col 18) -->
    <g id="red-led" filter="url(#glow-red)">
      <circle cx="{red_x}" cy="{(red_anode_y + red_cathode_y)/2}" r="11" fill="#EF4444" stroke="#B91C1C" stroke-width="2" opacity="0.95"/>
      <ellipse cx="{red_x - 2.5}" cy="{(red_anode_y + red_cathode_y)/2 - 2.5}" rx="3.5" ry="2" fill="#FEE2E2" opacity="0.8"/>
      <text x="{red_x}" y="{red_anode_y - 8}" fill="#EF4444" font-size="8" font-weight="800" text-anchor="middle">G18 (Anode +)</text>
      <text x="{red_x}" y="{red_cathode_y + 14}" fill="#94A3B8" font-size="8" font-weight="700" text-anchor="middle">I18 (Cathode -)</text>
    </g>
    <!-- 220 Ohm Resistor for Red LED (Col 18, Row I to Bottom Blue Rail) -->
    <g id="resistor-red">
      <line x1="{red_x}" y1="{red_cathode_y}" x2="{red_x}" y2="{bot_rail_minus_y}" stroke="#94A3B8" stroke-width="2.5" stroke-linecap="round"/>
      <rect x="{red_x - 6}" y="{row_j_y + 12}" width="12" height="30" rx="3" fill="url(#resistor-body)" stroke="#A16207" stroke-width="1.2"/>
      <rect x="{red_x - 6}" y="{row_j_y + 15}" width="12" height="3" fill="#DC2626"/>
      <rect x="{red_x - 6}" y="{row_j_y + 21}" width="12" height="3" fill="#DC2626"/>
      <rect x="{red_x - 6}" y="{row_j_y + 27}" width="12" height="3" fill="#78350F"/>
      <rect x="{red_x - 6}" y="{row_j_y + 34}" width="12" height="3" fill="#F59E0B"/>
      <circle cx="{red_x}" cy="{bot_rail_minus_y}" r="3.5" fill="#2563EB" stroke="#000" stroke-width="1"/>
      <text x="{red_x + 15}" y="{row_j_y + 30}" fill="#CBD5E1" font-size="8" font-weight="700">220Ω</text>
    </g>
    ''')


    # ------------------ EXACT JUMPER WIRES AS REQUESTED BY USER ------------------
    # User Rules:
    # BLACK Wire = M-M (Male-to-Male)
    # BLUE Wire = F-M (Female-to-Male)
    # YELLOW Wire = Maliit na U-shaped jumper
    wires_svg = ['<!-- Jumper Wires Layer -->', '<g id="wires-layer" filter="url(#shadow-wire)">']

    def draw_curve(x1, y1, x2, y2, color, stroke_w=4, c1x_off=0, c1y_off=0, c2x_off=0, c2y_off=0):
        dx_w = x2 - x1
        dy_w = y2 - y1
        dist = (dx_w**2 + dy_w**2)**0.5
        c1x = x1 + c1x_off if c1x_off != 0 else x1 + dx_w * 0.25
        c1y = y1 + c1y_off if c1y_off != 0 else y1 - 30 - dist * 0.08
        c2x = x2 + c2x_off if c2x_off != 0 else x2 - dx_w * 0.25
        c2y = y2 + c2y_off if c2y_off != 0 else y2 - 30 - dist * 0.08
        path_d = f"M {x1} {y1} C {c1x} {c1y}, {c2x} {c2y}, {x2} {y2}"
        
        # Dual stroke: dark outline + colored core
        outline_w = stroke_w + 3
        return (f'<path d="{path_d}" fill="none" stroke="#000000" stroke-width="{outline_w}" stroke-linecap="round"/>\n'
                f'<path d="{path_d}" fill="none" stroke="{color}" stroke-width="{stroke_w}" stroke-linecap="round"/>\n'
                f'<circle cx="{x1}" cy="{y1}" r="4.5" fill="{color}" stroke="#000" stroke-width="1.2"/>\n'
                f'<circle cx="{x2}" cy="{y2}" r="4.5" fill="{color}" stroke="#000" stroke-width="1.2"/>')

    # A. YELLOW U-JUMPERS (Short breadboard hops)
    # 1. ESP32 3V3 (Hole A60) to Top Red (+) Rail
    wires_svg.append(draw_curve(get_col_x(60), row_a_y, get_col_x(60), top_rail_plus_y, "#EAB308", 4, 0, -15, 0, 15))
    
    # 2. ESP32 GND (Hole A59) to Top Blue (-) Rail
    wires_svg.append(draw_curve(get_col_x(59), row_a_y, get_col_x(59), top_rail_minus_y, "#EAB308", 4, 0, -25, 0, 15))

    # 3. Buzzer (-) (Hole I35) to Bottom Blue (-) Rail
    wires_svg.append(draw_curve(get_col_x(35), row_i_y, get_col_x(35), bot_rail_minus_y, "#EAB308", 4, 0, 25, 0, -20))

    # 4. Rail-to-Rail Bridge (Top to Bottom Red (+) and Blue (-)) at Col 10
    wires_svg.append(draw_curve(get_col_x(10), top_rail_plus_y, get_col_x(10), bot_rail_plus_y, "#EAB308", 4, -40, 0, -40, 0))
    wires_svg.append(draw_curve(get_col_x(12), top_rail_minus_y, get_col_x(12), bot_rail_minus_y, "#EAB308", 4, -55, 0, -55, 0))

    # B. BLUE F-M WIRES (Female on Module -> Male on Breadboard)
    # RFID Connections:
    # 1. RFID 3.3V -> Top Red (+) Rail (near Col 22)
    rfid_vcc_px = rfid_x + 220
    rfid_py = rfid_y + rfid_h - 9
    wires_svg.append(draw_curve(rfid_vcc_px, rfid_py, get_col_x(22), top_rail_plus_y, "#3B82F6", 4, 10, 40, -10, -40))

    # 2. RFID GND -> Top Blue (-) Rail (near Col 20)
    rfid_gnd_px = rfid_x + 170
    wires_svg.append(draw_curve(rfid_gnd_px, rfid_py, get_col_x(20), top_rail_minus_y, "#3B82F6", 4, 10, 50, -10, -50))

    # 3. RFID RST -> Hole A56 (ESP32 D4)
    rfid_rst_px = rfid_x + 195
    wires_svg.append(draw_curve(rfid_rst_px, rfid_py, get_col_x(56), row_a_y, "#3B82F6", 4, 60, -80, -30, -70))

    # 4. RFID MISO -> Hole A51 (ESP32 D19)
    rfid_miso_px = rfid_x + 120
    wires_svg.append(draw_curve(rfid_miso_px, rfid_py, get_col_x(51), row_a_y, "#3B82F6", 4, 80, -110, -40, -90))

    # 5. RFID MOSI -> Hole A46 (ESP32 D23)
    rfid_mosi_px = rfid_x + 95
    wires_svg.append(draw_curve(rfid_mosi_px, rfid_py, get_col_x(46), row_a_y, "#3B82F6", 4, 90, -130, -50, -100))

    # 6. RFID SCK -> Hole A52 (ESP32 D18)
    rfid_sck_px = rfid_x + 70
    wires_svg.append(draw_curve(rfid_sck_px, rfid_py, get_col_x(52), row_a_y, "#3B82F6", 4, 120, -150, -30, -110))

    # 7. RFID SDA -> Hole A53 (ESP32 D5)
    rfid_sda_px = rfid_x + 45
    wires_svg.append(draw_curve(rfid_sda_px, rfid_py, get_col_x(53), row_a_y, "#3B82F6", 4, 140, -170, -20, -120))

    # OLED Connections (using BLUE F-M wires):
    # 8. OLED VCC -> Top Red (+) Rail (near Col 30)
    oled_vcc_px = oled_x + 80
    oled_py = oled_y + oled_h - 9
    wires_svg.append(draw_curve(oled_vcc_px, oled_py, get_col_x(30), top_rail_plus_y, "#3B82F6", 4, 0, 30, 0, -30))

    # 9. OLED GND -> Top Blue (-) Rail (near Col 28)
    oled_gnd_px = oled_x + 45
    wires_svg.append(draw_curve(oled_gnd_px, oled_py, get_col_x(28), top_rail_minus_y, "#3B82F6", 4, 0, 40, 0, -40))

    # 10. OLED SCL -> Hole A47 (ESP32 D22)
    oled_scl_px = oled_x + 120
    wires_svg.append(draw_curve(oled_scl_px, oled_py, get_col_x(47), row_a_y, "#3B82F6", 4, 30, -50, -30, -50))

    # 11. OLED SDA -> Hole A50 (ESP32 D21)
    oled_sda_px = oled_x + 155
    wires_svg.append(draw_curve(oled_sda_px, oled_py, get_col_x(50), row_a_y, "#3B82F6", 4, 30, -60, -30, -60))

    # C. BLACK M-M WIRES (Breadboard to Breadboard):
    # 1. Hole J51 (ESP32 D32) -> Buzzer (+) (Hole G35)
    wires_svg.append(draw_curve(get_col_x(51), row_j_y, get_col_x(35), row_g_y, "#111827", 4.5, -30, 60, 30, 60))

    # 2. Hole J55 (ESP32 D27) -> Green LED Anode (Hole G25)
    wires_svg.append(draw_curve(get_col_x(55), row_j_y, get_col_x(25), row_g_y, "#111827", 4.5, -40, 90, 40, 90))

    # 3. Hole J56 (ESP32 D14) -> Red LED Anode (Hole G18)
    wires_svg.append(draw_curve(get_col_x(56), row_j_y, get_col_x(18), row_g_y, "#111827", 4.5, -50, 120, 50, 110))

    wires_svg.append('</g>')
    svg.append('\n'.join(wires_svg))

    # ------------------ LEGEND & STEP-BY-STEP PIN TABLE ------------------
    leg_y = 880
    leg_h = 330
    svg.append(f'''
    <!-- Bottom Reference Table -->
    <g id="bottom-reference">
      <rect x="{bb_x}" y="{leg_y}" width="{bb_w}" height="{leg_h}" rx="14" fill="#111827" stroke="#374151" stroke-width="2"/>
      <text x="{bb_x + 25}" y="{leg_y + 32}" fill="#38BDF8" font-size="16" font-weight="800" letter-spacing="1">STEP-BY-STEP WIRING CHECKLIST (MATCHED TO YOUR ACTUAL WIRES)</text>
      
      <!-- Col 1: Yellow Jumpers & Power -->
      <g transform="translate({bb_x + 25}, {leg_y + 55})">
        <text x="0" y="0" fill="#EAB308" font-size="12" font-weight="800">1. YELLOW U-JUMPERS (Breadboard)</text>
        <text x="0" y="24" fill="#F3F4F6" font-size="12" font-weight="600">• Hole A60 (ESP32 3V3) → Red (+) Power Rail</text>
        <text x="0" y="46" fill="#F3F4F6" font-size="12" font-weight="600">• Hole A59 (ESP32 GND) → Blue (-) Ground Rail</text>
        <text x="0" y="68" fill="#F3F4F6" font-size="12" font-weight="600">• Hole I35 (Buzzer -) → Blue (-) Ground Rail</text>
        <text x="0" y="90" fill="#F3F4F6" font-size="12" font-weight="600">• Top (+) Rail → Bottom (+) Rail (Col 10)</text>
        <text x="0" y="112" fill="#F3F4F6" font-size="12" font-weight="600">• Top (-) Rail → Bottom (-) Rail (Col 12)</text>

        <rect x="0" y="135" width="340" height="95" rx="8" fill="#7F1D1D" stroke="#DC2626" stroke-width="1.5"/>
        <text x="12" y="157" fill="#FEF2F2" font-size="11" font-weight="800">⚠️ CRITICAL 3.3V VOLTAGE RULE:</text>
        <text x="12" y="175" fill="#FEE2E2" font-size="10" font-weight="600">Ang RC522 at OLED ay 3.3V ONLY!</text>
        <text x="12" y="193" fill="#FEE2E2" font-size="10" font-weight="600">Huwag ikakabit sa VIN o 5V para hindi masunog</text>
        <text x="12" y="211" fill="#FEE2E2" font-size="10" font-weight="600">ang mga chips ng scanner at display.</text>
      </g>

      <!-- Col 2: Blue F-M to RFID -->
      <g transform="translate({bb_x + 400}, {leg_y + 55})">
        <text x="0" y="0" fill="#3B82F6" font-size="12" font-weight="800">2. BLUE F-M WIRES (RC522 RFID Scanner)</text>
        <text x="0" y="24" fill="#F3F4F6" font-size="12" font-weight="600">• RC522 3.3V → Red (+) Power Rail</text>
        <text x="0" y="46" fill="#F3F4F6" font-size="12" font-weight="600">• RC522 GND → Blue (-) Ground Rail</text>
        <text x="0" y="68" fill="#F3F4F6" font-size="12" font-weight="600">• RC522 RST → Hole A56 (ESP32 D4)</text>
        <text x="0" y="90" fill="#F3F4F6" font-size="12" font-weight="600">• RC522 MISO → Hole A51 (ESP32 D19)</text>
        <text x="0" y="112" fill="#F3F4F6" font-size="12" font-weight="600">• RC522 MOSI → Hole A46 (ESP32 D23)</text>
        <text x="0" y="134" fill="#F3F4F6" font-size="12" font-weight="600">• RC522 SCK → Hole A52 (ESP32 D18)</text>
        <text x="0" y="156" fill="#F3F4F6" font-size="12" font-weight="600">• RC522 SDA → Hole A53 (ESP32 D5)</text>
        <text x="0" y="178" fill="#9CA3AF" font-size="12" font-weight="600">• RC522 IRQ → (Walang nakakabit / Empty)</text>
      </g>

      <!-- Col 3: Blue F-M to OLED Display -->
      <g transform="translate({bb_x + 800}, {leg_y + 55})">
        <text x="0" y="0" fill="#3B82F6" font-size="12" font-weight="800">3. BLUE F-M WIRES (0.96" OLED Screen)</text>
        <text x="0" y="24" fill="#F3F4F6" font-size="12" font-weight="600">• OLED VCC → Red (+) Power Rail</text>
        <text x="0" y="46" fill="#F3F4F6" font-size="12" font-weight="600">• OLED GND → Blue (-) Ground Rail</text>
        <text x="0" y="68" fill="#F3F4F6" font-size="12" font-weight="600">• OLED SCL → Hole A47 (ESP32 D22)</text>
        <text x="0" y="90" fill="#F3F4F6" font-size="12" font-weight="600">• OLED SDA → Hole A50 (ESP32 D21)</text>

        <text x="0" y="130" fill="#9CA3AF" font-size="11" font-weight="800">PAANO KUNG WHITE F-F ANG GAMIT SA OLED?</text>
        <text x="0" y="150" fill="#CBD5E1" font-size="10" font-weight="500">Kung may kasamang header pins o module header,</text>
        <text x="0" y="166" fill="#CBD5E1" font-size="10" font-weight="500">pwede ring gamitin ang White F-F wires!</text>
      </g>

      <!-- Col 4: Black M-M to Buzzer & LEDs -->
      <g transform="translate({bb_x + 1190}, {leg_y + 55})">
        <text x="0" y="0" fill="#F9FAFB" font-size="12" font-weight="800">4. BLACK M-M WIRES (Buzzer & LEDs)</text>
        <text x="0" y="24" fill="#F3F4F6" font-size="12" font-weight="600">• Hole J51 (ESP32 D32) → Hole G35 (Buzzer +)</text>
        <text x="0" y="46" fill="#F3F4F6" font-size="12" font-weight="600">• Hole J55 (ESP32 D27) → Hole G25 (Green Anode)</text>
        <text x="0" y="68" fill="#F3F4F6" font-size="12" font-weight="600">• Hole J56 (ESP32 D14) → Hole G18 (Red Anode)</text>
        
        <text x="0" y="105" fill="#4ADE80" font-size="12" font-weight="800">5. 220Ω RESISTORS (Direct Bridge)</text>
        <text x="0" y="125" fill="#F3F4F6" font-size="12" font-weight="600">• Resistor 1: Hole I25 (Green -) → Blue (-) Rail</text>
        <text x="0" y="145" fill="#F3F4F6" font-size="12" font-weight="600">• Resistor 2: Hole I18 (Red -) → Blue (-) Rail</text>

        <rect x="0" y="170" width="310" height="55" rx="6" fill="#1F2937" stroke="#374151" stroke-width="1"/>
        <text x="12" y="190" fill="#38BDF8" font-size="10" font-weight="800">STATUS FEEDBACK NG FIRMWARE:</text>
        <text x="12" y="206" fill="#4ADE80" font-size="10" font-weight="700">✓ Valid Attendance: Green LED + 1 Beep</text>
      </g>
    </g>''')

    svg.append('</svg>')
    return '\n'.join(svg)

if __name__ == '__main__':
    svg_content = generate_svg()
    output_path = 'docs/hardware/esp32_rfid_breadboard_wiring.svg'
    with open(output_path, 'w', encoding='utf-8') as f:
        f.write(svg_content)
    print(f"Successfully generated updated {output_path} ({len(svg_content)} bytes)")
