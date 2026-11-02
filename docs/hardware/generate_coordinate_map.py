"""
Generator for High-Resolution Vertical Breadboard Coordinate Map with ESP32 Mounted
Matches the user's exact physical orientation in photo media_1793501545060_5555e940.jpg
Output: docs/hardware/breadboard_coordinate_map.svg
"""

def generate_svg():
    width = 1100
    height = 1950
    
    # Breadboard geometry (Vertical layout matching user's photo!)
    # Top has MicroUSB port (Row 60), Bottom has Row 1
    bb_x = 180
    bb_y = 120
    bb_w = 740
    bb_h = 1750
    
    # 60 rows from top (row 60) down to bottom (row 1)
    # y spacing per row: dy = 26
    row_y_start = bb_y + 90
    dy = 26.5
    
    def get_row_y(row_num):
        # row_num 60 is at top, row_num 1 is at bottom
        idx = 60 - row_num
        return row_y_start + idx * dy

    # Columns X coordinates:
    # Left Power: Blue (-), Red (+)
    rail_l_minus_x = bb_x + 35
    rail_l_plus_x  = bb_x + 65
    
    # Left Strip: A, B, C, D, E
    col_a_x = bb_x + 125
    col_b_x = bb_x + 155
    col_c_x = bb_x + 185
    col_d_x = bb_x + 215
    col_e_x = bb_x + 245
    
    # Center Divider: x = bb_x + 295, width = 60
    trench_x = bb_x + 290
    
    # Right Strip: F, G, H, I, J
    col_f_x = bb_x + 395
    col_g_x = bb_x + 425
    col_h_x = bb_x + 455
    col_i_x = bb_x + 485
    col_j_x = bb_x + 515
    
    # Right Power: Red (+), Blue (-)
    rail_r_plus_x  = bb_x + 675
    rail_r_minus_x = bb_x + 705

    svg = []
    svg.append(f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {width} {height}" width="100%" height="100%" style="background:#090D16; font-family: -apple-system, BlinkMacSystemFont, \'Segoe UI\', Roboto, sans-serif;">')
    
    svg.append('''<defs>
      <filter id="shadow-bb" x="-10%" y="-10%" width="130%" height="130%">
        <feDropShadow dx="0" dy="12" stdDeviation="16" flood-color="#000000" flood-opacity="0.6"/>
      </filter>
      <filter id="shadow-esp" x="-10%" y="-10%" width="130%" height="130%">
        <feDropShadow dx="0" dy="8" stdDeviation="12" flood-color="#000000" flood-opacity="0.7"/>
      </filter>
      <linearGradient id="bb-body" x1="0%" y1="0%" x2="100%" y2="0%">
        <stop offset="0%" stop-color="#F8FAFC"/>
        <stop offset="100%" stop-color="#E2E8F0"/>
      </linearGradient>
      <linearGradient id="esp-pcb" x1="0%" y1="0%" x2="0%" y2="100%">
        <stop offset="0%" stop-color="#1E293B"/>
        <stop offset="100%" stop-color="#0F172A"/>
      </linearGradient>
      <linearGradient id="metal-shield" x1="0%" y1="0%" x2="0%" y2="100%">
        <stop offset="0%" stop-color="#E2E8F0"/>
        <stop offset="50%" stop-color="#94A3B8"/>
        <stop offset="100%" stop-color="#CBD5E1"/>
      </linearGradient>
    </defs>''')
    
    # Top Header
    svg.append(f'''
    <!-- Header -->
    <rect x="0" y="0" width="{width}" height="100" fill="#111827"/>
    <text x="50" y="42" fill="#38BDF8" font-size="20" font-weight="800" letter-spacing="1">CLASSREALM HARDWARE LAB</text>
    <text x="50" y="76" fill="#F8FAFC" font-size="26" font-weight="700">Exact Breadboard Coordinate Map (Rows 1–60 &amp; Columns A–J)</text>
    ''')

    # Breadboard Base Plate
    svg.append(f'''
    <!-- Breadboard Base Body -->
    <g filter="url(#shadow-bb)">
      <rect x="{bb_x}" y="{bb_y}" width="{bb_w}" height="{bb_h}" rx="24" fill="url(#bb-body)" stroke="#CBD5E1" stroke-width="3"/>
      
      <!-- Power Rail Colored Lines (Vertical) -->
      <!-- Left Rail Lines -->
      <line x1="{rail_l_minus_x}" y1="{bb_y + 40}" x2="{rail_l_minus_x}" y2="{bb_y + bb_h - 40}" stroke="#2563EB" stroke-width="3" stroke-linecap="round"/>
      <line x1="{rail_l_plus_x}" y1="{bb_y + 40}" x2="{rail_l_plus_x}" y2="{bb_y + bb_h - 40}" stroke="#DC2626" stroke-width="3" stroke-linecap="round"/>
      <!-- Right Rail Lines -->
      <line x1="{rail_r_plus_x}" y1="{bb_y + 40}" x2="{rail_r_plus_x}" y2="{bb_y + bb_h - 40}" stroke="#DC2626" stroke-width="3" stroke-linecap="round"/>
      <line x1="{rail_r_minus_x}" y1="{bb_y + 40}" x2="{rail_r_minus_x}" y2="{bb_y + bb_h - 40}" stroke="#2563EB" stroke-width="3" stroke-linecap="round"/>

      <!-- Rail Polarity Symbols -->
      <text x="{rail_l_minus_x}" y="{bb_y + 30}" fill="#2563EB" font-size="16" font-weight="900" text-anchor="middle">-</text>
      <text x="{rail_l_plus_x}" y="{bb_y + 30}" fill="#DC2626" font-size="16" font-weight="900" text-anchor="middle">+</text>
      <text x="{rail_l_minus_x}" y="{bb_y + bb_h - 18}" fill="#2563EB" font-size="16" font-weight="900" text-anchor="middle">-</text>
      <text x="{rail_l_plus_x}" y="{bb_y + bb_h - 18}" fill="#DC2626" font-size="16" font-weight="900" text-anchor="middle">+</text>

      <text x="{rail_r_plus_x}" y="{bb_y + 30}" fill="#DC2626" font-size="16" font-weight="900" text-anchor="middle">+</text>
      <text x="{rail_r_minus_x}" y="{bb_y + 30}" fill="#2563EB" font-size="16" font-weight="900" text-anchor="middle">-</text>
      <text x="{rail_r_plus_x}" y="{bb_y + bb_h - 18}" fill="#DC2626" font-size="16" font-weight="900" text-anchor="middle">+</text>
      <text x="{rail_r_minus_x}" y="{bb_y + bb_h - 18}" fill="#2563EB" font-size="16" font-weight="900" text-anchor="middle">-</text>

      <!-- Center Divider Trench -->
      <rect x="{trench_x}" y="{bb_y + 40}" width="60" height="{bb_h - 80}" rx="4" fill="#CBD5E1"/>
      <rect x="{trench_x + 3}" y="{bb_y + 42}" width="54" height="{bb_h - 84}" rx="3" fill="#94A3B8" opacity="0.4"/>
    </g>''')

    # Holes & Labels
    def render_hole(cx, cy):
        return f'<rect x="{cx - 4.5}" y="{cy - 4.5}" width="9" height="9" rx="2" fill="#1E293B" stroke="#64748B" stroke-width="0.8"/>'
    
    holes_svg = ['<g id="breadboard-grid">']
    
    # Column Letter Headers at Top and Bottom
    col_positions = [
        ('A', col_a_x), ('B', col_b_x), ('C', col_c_x), ('D', col_d_x), ('E', col_e_x),
        ('F', col_f_x), ('G', col_g_x), ('H', col_h_x), ('I', col_i_x), ('J', col_j_x)
    ]
    for (label, cx) in col_positions:
        holes_svg.append(f'<text x="{cx}" y="{bb_y + 60}" fill="#1E293B" font-size="14" font-weight="900" text-anchor="middle">{label}</text>')
        holes_svg.append(f'<text x="{cx}" y="{bb_y + bb_h - 50}" fill="#1E293B" font-size="14" font-weight="900" text-anchor="middle">{label}</text>')

    # Rows 1 to 60
    for r in range(1, 61):
        ry = get_row_y(r)
        
        # Row Number Labels on left and right borders
        if r in [1, 5, 10, 15, 20, 25, 30, 35, 40, 45, 46, 50, 55, 60] or r >= 46:
            font_size = "11" if r >= 46 else "9"
            font_weight = "800" if r >= 46 else "600"
            color = "#0284C7" if r >= 46 else "#64748B"
            holes_svg.append(f'<text x="{bb_x + 95}" y="{ry + 4}" fill="{color}" font-size="{font_size}" font-weight="{font_weight}" text-anchor="middle">{r}</text>')
            holes_svg.append(f'<text x="{bb_x + bb_w - 95}" y="{ry + 4}" fill="{color}" font-size="{font_size}" font-weight="{font_weight}" text-anchor="middle">{r}</text>')

        # Power Rails holes
        holes_svg.append(render_hole(rail_l_minus_x, ry))
        holes_svg.append(render_hole(rail_l_plus_x, ry))
        holes_svg.append(render_hole(rail_r_plus_x, ry))
        holes_svg.append(render_hole(rail_r_minus_x, ry))

        # Terminal holes A, B, C, D, E and F, G, H, I, J
        holes_svg.append(render_hole(col_a_x, ry))
        holes_svg.append(render_hole(col_b_x, ry))
        holes_svg.append(render_hole(col_c_x, ry))
        holes_svg.append(render_hole(col_d_x, ry))
        holes_svg.append(render_hole(col_e_x, ry))

        holes_svg.append(render_hole(col_f_x, ry))
        holes_svg.append(render_hole(col_g_x, ry))
        holes_svg.append(render_hole(col_h_x, ry))
        holes_svg.append(render_hole(col_i_x, ry))
        holes_svg.append(render_hole(col_j_x, ry))

    holes_svg.append('</g>')
    svg.append('\n'.join(holes_svg))

    # ------------------ MOUNTED ESP32 MODULE (ROWS 46 TO 60) ------------------
    esp_top_y = get_row_y(60) - 25
    esp_bot_y = get_row_y(46) + 25
    esp_h = esp_bot_y - esp_top_y
    esp_w = 340
    esp_x = bb_x + (bb_w / 2) - (esp_w / 2)

    svg.append(f'''
    <!-- ESP32 DevKit Module Covering Columns B, C, D, E, F, G, H, I across Rows 46 to 60 -->
    <g id="mounted-esp32" filter="url(#shadow-esp)">
      <!-- Black PCB Body -->
      <rect x="{esp_x}" y="{esp_top_y}" width="{esp_w}" height="{esp_h}" rx="12" fill="url(#esp-pcb)" stroke="#475569" stroke-width="2.5"/>

      <!-- MicroUSB Port at Top Edge -->
      <rect x="{esp_x + (esp_w/2) - 18}" y="{esp_top_y - 12}" width="36" height="18" rx="3" fill="#94A3B8" stroke="#475569" stroke-width="1.5"/>
      <rect x="{esp_x + (esp_w/2) - 12}" y="{esp_top_y - 7}" width="24" height="8" rx="1.5" fill="#1E293B"/>

      <!-- EN and BOOT Buttons -->
      <rect x="{esp_x + 18}" y="{esp_top_y + 12}" width="16" height="14" rx="2" fill="#E2E8F0" stroke="#475569" stroke-width="1"/>
      <circle cx="{esp_x + 26}" cy="{esp_top_y + 19}" r="3" fill="#DC2626"/>
      <text x="{esp_x + 26}" y="{esp_top_y + 38}" fill="#94A3B8" font-size="8" font-weight="800" text-anchor="middle">EN</text>

      <rect x="{esp_x + esp_w - 34}" y="{esp_top_y + 12}" width="16" height="14" rx="2" fill="#E2E8F0" stroke="#475569" stroke-width="1"/>
      <circle cx="{esp_x + esp_w - 26}" cy="{esp_top_y + 19}" r="3" fill="#2563EB"/>
      <text x="{esp_x + esp_w - 26}" y="{esp_top_y + 38}" fill="#94A3B8" font-size="8" font-weight="800" text-anchor="middle">BOOT</text>

      <!-- Metal RF Shield (ESP-WROOM-32) -->
      <rect x="{esp_x + 25}" y="{esp_top_y + 140}" width="{esp_w - 50}" height="200" rx="6" fill="url(#metal-shield)" stroke="#64748B" stroke-width="1.5"/>
      <text x="{esp_x + (esp_w/2)}" y="{esp_top_y + 220}" fill="#0F172A" font-size="16" font-weight="900" text-anchor="middle">ESP-WROOM-32</text>
      <text x="{esp_x + (esp_w/2)}" y="{esp_top_y + 245}" fill="#334155" font-size="11" font-weight="700" text-anchor="middle">WiFi + Bluetooth MCU</text>
      <text x="{esp_x + (esp_w/2)}" y="{esp_top_y + 265}" fill="#475569" font-size="10" font-weight="800" text-anchor="middle">30-PIN DEVKIT V1</text>

      <!-- PCB Antenna at Bottom (near Row 46) -->
      <rect x="{esp_x + 25}" y="{esp_top_y + 350}" width="{esp_w - 50}" height="40" rx="3" fill="#92400E" stroke="#78350F" stroke-width="1"/>
      <path d="M {esp_x + 35} {esp_top_y + 360} h 270 v 8 h -270 v 8 h 270" fill="none" stroke="#FDE047" stroke-width="2.5" stroke-linecap="round"/>
    </g>''')

    # Mapping of Left & Right Pins with EXACT HOLE COORDINATE
    # Left Side: Hole A is the ONLY accessible hole!
    # Right Side: Hole J is the ONLY accessible hole!
    left_pins = [
        (60, '3V3', '3.3V Power Out', True, '#EF4444'),
        (59, 'GND', 'Ground', True, '#000000'),
        (58, 'D15', 'GPIO 15', False, '#64748B'),
        (57, 'D2',  'GPIO 2', False, '#64748B'),
        (56, 'D4',  'RFID RST', True, '#3B82F6'),
        (55, 'RX2', 'GPIO 16', False, '#64748B'),
        (54, 'TX2', 'GPIO 17', False, '#64748B'),
        (53, 'D5',  'RFID SDA (SS)', True, '#3B82F6'),
        (52, 'D18', 'RFID SCK (Clock)', True, '#3B82F6'),
        (51, 'D19', 'RFID MISO', True, '#3B82F6'),
        (50, 'D21', 'OLED SDA (Data)', True, '#3B82F6'),
        (49, 'RX0', 'GPIO 3', False, '#64748B'),
        (48, 'TX0', 'GPIO 1', False, '#64748B'),
        (47, 'D22', 'OLED SCL (Clock)', True, '#3B82F6'),
        (46, 'D23', 'RFID MOSI', True, '#3B82F6'),
    ]

    right_pins = [
        (60, 'VIN', '5V In (Do NOT use)', False, '#64748B'),
        (59, 'GND', 'Ground', False, '#64748B'),
        (58, 'D13', 'GPIO 13', False, '#64748B'),
        (57, 'D12', 'GPIO 12', False, '#64748B'),
        (56, 'D14', 'Red LED Anode (+)', True, '#111827'),
        (55, 'D27', 'Green LED Anode (+)', True, '#111827'),
        (54, 'D26', 'GPIO 26', False, '#64748B'),
        (53, 'D25', 'GPIO 25', False, '#64748B'),
        (52, 'D33', 'GPIO 33', False, '#64748B'),
        (51, 'D32', 'Active Buzzer (+)', True, '#111827'),
        (50, 'D35', 'GPIO 35', False, '#64748B'),
        (49, 'D34', 'GPIO 34', False, '#64748B'),
        (48, 'VN',  'Sensor VN', False, '#64748B'),
        (47, 'VP',  'Sensor VP', False, '#64748B'),
        (46, 'EN',  'Enable', False, '#64748B'),
    ]

    coords_svg = ['<!-- Hole Highlights & Coordinate Callout Tags -->']

    # Draw Left Pin Callouts (Pointing to Hole A)
    for row, pname, desc, is_target, tag_clr in left_pins:
        ry = get_row_y(row)
        hole_name = f"A{row}"
        
        # Highlight Hole A on breadboard
        ring_color = "#38BDF8" if is_target else "#64748B"
        coords_svg.append(f'<circle cx="{col_a_x}" cy="{ry}" r="6.5" fill="none" stroke="{ring_color}" stroke-width="2.5"/>')
        
        # Silkscreen text on ESP32 PCB
        text_clr = "#38BDF8" if is_target else "#94A3B8"
        font_wt = "900" if is_target else "600"
        coords_svg.append(f'<text x="{esp_x + 18}" y="{ry + 4}" fill="{text_clr}" font-size="11" font-weight="{font_wt}">{pname}</text>')
        
        # Callout Pill on Left Margin
        if is_target:
            pill_w = 145
            pill_x = bb_x - 165
            coords_svg.append(f'''
            <g>
              <line x1="{col_a_x - 8}" y1="{ry}" x2="{pill_x + pill_w}" y2="{ry}" stroke="#38BDF8" stroke-width="1.8" stroke-dasharray="3,2"/>
              <rect x="{pill_x}" y="{ry - 12}" width="{pill_w}" height="24" rx="6" fill="#1E293B" stroke="#0284C7" stroke-width="1.5"/>
              <circle cx="{pill_x + 14}" cy="{ry}" r="4" fill="{tag_clr}" stroke="#F8FAFC" stroke-width="1"/>
              <text x="{pill_x + 26}" y="{ry + 4}" fill="#38BDF8" font-size="11" font-weight="900">HOLE {hole_name}</text>
              <text x="{pill_x + 85}" y="{ry + 4}" fill="#F8FAFC" font-size="10" font-weight="700">({pname})</text>
            </g>''')

    # Draw Right Pin Callouts (Pointing to Hole J)
    for row, pname, desc, is_target, tag_clr in right_pins:
        ry = get_row_y(row)
        hole_name = f"J{row}"
        
        ring_color = "#38BDF8" if is_target else "#64748B"
        coords_svg.append(f'<circle cx="{col_j_x}" cy="{ry}" r="6.5" fill="none" stroke="{ring_color}" stroke-width="2.5"/>')
        
        text_clr = "#38BDF8" if is_target else "#94A3B8"
        font_wt = "900" if is_target else "600"
        coords_svg.append(f'<text x="{esp_x + esp_w - 18}" y="{ry + 4}" fill="{text_clr}" font-size="11" font-weight="{font_wt}" text-anchor="end">{pname}</text>')
        
        if is_target:
            pill_w = 145
            pill_x = bb_x + bb_w + 20
            coords_svg.append(f'''
            <g>
              <line x1="{col_j_x + 8}" y1="{ry}" x2="{pill_x}" y2="{ry}" stroke="#38BDF8" stroke-width="1.8" stroke-dasharray="3,2"/>
              <rect x="{pill_x}" y="{ry - 12}" width="{pill_w}" height="24" rx="6" fill="#1E293B" stroke="#0284C7" stroke-width="1.5"/>
              <circle cx="{pill_x + 14}" cy="{ry}" r="4" fill="{tag_clr}" stroke="#F8FAFC" stroke-width="1"/>
              <text x="{pill_x + 26}" y="{ry + 4}" fill="#38BDF8" font-size="11" font-weight="900">HOLE {hole_name}</text>
              <text x="{pill_x + 85}" y="{ry + 4}" fill="#F8FAFC" font-size="10" font-weight="700">({pname})</text>
            </g>''')

    svg.append('\n'.join(coords_svg))

    # Bracket showing open space below (Rows 1 to 45)
    open_top_y = get_row_y(45) - 10
    open_bot_y = get_row_y(1) + 15
    svg.append(f'''
    <!-- Open Prototyping Area Bracket -->
    <g transform="translate({bb_x + bb_w + 20}, {open_top_y})">
      <rect x="0" y="0" width="160" height="{open_bot_y - open_top_y}" rx="10" fill="#111827" stroke="#10B981" stroke-width="2" stroke-dasharray="6,4"/>
      <text x="80" y="40" fill="#10B981" font-size="14" font-weight="900" text-anchor="middle">BAKANTENG SPACE</text>
      <text x="80" y="65" fill="#6EE7B7" font-size="12" font-weight="800" text-anchor="middle">ROWS 1 TO 45</text>
      <text x="80" y="95" fill="#E2E8F0" font-size="10" font-weight="600" text-anchor="middle">Lahat ng Columns</text>
      <text x="80" y="112" fill="#E2E8F0" font-size="10" font-weight="800" text-anchor="middle">A, B, C, D, E</text>
      <text x="80" y="130" fill="#E2E8F0" font-size="10" font-weight="600" text-anchor="middle">at</text>
      <text x="80" y="148" fill="#E2E8F0" font-size="10" font-weight="800" text-anchor="middle">F, G, H, I, J</text>
      <text x="80" y="175" fill="#94A3B8" font-size="9" font-weight="600" text-anchor="middle">ay LIBRE at BUONG</text>
      <text x="80" y="190" fill="#94A3B8" font-size="9" font-weight="600" text-anchor="middle">magagamit para sa:</text>
      <text x="80" y="215" fill="#F8FAFC" font-size="11" font-weight="700" text-anchor="middle">• Buzzer</text>
      <text x="80" y="235" fill="#4ADE80" font-size="11" font-weight="700" text-anchor="middle">• Green LED</text>
      <text x="80" y="255" fill="#F87171" font-size="11" font-weight="700" text-anchor="middle">• Red LED</text>
      <text x="80" y="275" fill="#FDE047" font-size="11" font-weight="700" text-anchor="middle">• 220Ω Resistors</text>
    </g>''')

    svg.append('</svg>')
    return '\n'.join(svg)

if __name__ == '__main__':
    svg_data = generate_svg()
    out_file = 'docs/hardware/breadboard_coordinate_map.svg'
    with open(out_file, 'w', encoding='utf-8') as f:
        f.write(svg_data)
    print(f"Generated {out_file} ({len(svg_data)} bytes)")
