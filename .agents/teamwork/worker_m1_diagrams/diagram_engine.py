import os
import math
from PIL import Image, ImageDraw, ImageFont

# Professional Educational Palette
PALETTE = {
    'bg': '#FFFFFF',
    'canvas_bg': '#F8FAFC',
    'navy': '#1E3A8A',       # Primary dark navy
    'slate_blue': '#2563EB', # Primary accent
    'sky': '#0284C7',        # Secondary accent
    'soft_blue': '#EFF6FF',  # Card highlight background
    'border': '#94A3B8',     # Slate border
    'border_dark': '#475569',
    'border_light': '#E2E8F0',
    'text_dark': '#0F172A',  # Headings & primary text
    'text_muted': '#475569', # Secondary & description
    'text_light': '#64748B',
    'white': '#FFFFFF',
    'card_bg': '#FFFFFF',
    'card_alt_bg': '#F1F5F9',
    # Semantic accents
    'emerald': '#059669',    # Hardware / Sync / Success
    'emerald_bg': '#ECFDF5',
    'emerald_border': '#10B981',
    'amber': '#D97706',      # Cutoff / Warnings / Alert
    'amber_bg': '#FFFBEB',
    'amber_border': '#F59E0B',
    'purple': '#7C3AED',     # Process / AI / Gemini
    'purple_bg': '#F5F3FF',
    'purple_border': '#8B5CF6',
    'rose': '#E11D48',       # Admin / Strict validation
    'rose_bg': '#FFF1F2',
    'rose_border': '#F43F5E',
    'gray_pill': '#F3F4F6'
}

FONTS = {}

def init_fonts():
    global FONTS
    font_bold = "C:/Windows/Fonts/segoeuib.ttf"
    font_reg = "C:/Windows/Fonts/segoeui.ttf"
    font_semi = "C:/Windows/Fonts/segoeuisl.ttf"
    font_mono = "C:/Windows/Fonts/consola.ttf"
    
    # Fallback to calibri/arial if segoe not found
    if not os.path.exists(font_bold):
        font_bold = "C:/Windows/Fonts/arialbd.ttf"
        font_reg = "C:/Windows/Fonts/arial.ttf"
        font_mono = "C:/Windows/Fonts/cour.ttf"

    FONTS = {
        'super_title': ImageFont.truetype(font_bold, 54),
        'title': ImageFont.truetype(font_bold, 40),
        'subtitle': ImageFont.truetype(font_reg, 24),
        'section_header': ImageFont.truetype(font_bold, 28),
        'card_header': ImageFont.truetype(font_bold, 24),
        'card_sub': ImageFont.truetype(font_reg, 20),
        'body_bold': ImageFont.truetype(font_bold, 19),
        'body': ImageFont.truetype(font_reg, 19),
        'body_sm': ImageFont.truetype(font_reg, 16),
        'body_sm_bold': ImageFont.truetype(font_bold, 16),
        'code': ImageFont.truetype(font_mono, 17),
        'badge': ImageFont.truetype(font_bold, 15),
        'arrow_label': ImageFont.truetype(font_bold, 17),
        'arrow_sub': ImageFont.truetype(font_reg, 15),
    }

init_fonts()

def text_size(draw, text, font):
    bbox = font.getbbox(text)
    return (bbox[2] - bbox[0], bbox[3] - bbox[1])

def wrap_text(text, font, max_width):
    words = text.split()
    if not words:
        return []
    lines = []
    current_line = words[0]
    for word in words[1:]:
        test_line = current_line + " " + word
        bbox = font.getbbox(test_line)
        w = bbox[2] - bbox[0]
        if w <= max_width:
            current_line = test_line
        else:
            lines.append(current_line)
            current_line = word
    lines.append(current_line)
    return lines

def draw_header(draw, width, title, subtitle, category="CLASSREALM ARCHITECTURE & SYSTEM MODELING"):
    # Top banner bar
    draw.rectangle([0, 0, width, 140], fill=PALETTE['navy'])
    draw.rectangle([0, 140, width, 148], fill=PALETTE['slate_blue'])
    
    # Category tag
    draw.text((60, 24), category.upper(), font=FONTS['badge'], fill='#93C5FD')
    # Title
    draw.text((60, 46), title, font=FONTS['title'], fill=PALETTE['white'])
    # Subtitle
    draw.text((60, 98), subtitle, font=FONTS['subtitle'], fill='#E2E8F0')

def draw_footer(draw, width, height, note="CLASSREALM • Eduardo Barretto Sr. High School • Pilot Client: Ma'am Karen P. Gonzaga"):
    draw.rectangle([0, height - 50, width, height], fill=PALETTE['card_alt_bg'])
    draw.line([(0, height - 50), (width, height - 50)], fill=PALETTE['border_light'], width=2)
    draw.text((60, height - 35), note, font=FONTS['body_sm'], fill=PALETTE['text_muted'])
    draw.text((width - 450, height - 35), "High-Resolution System Architecture Specification", font=FONTS['body_sm_bold'], fill=PALETTE['navy'])

def draw_card(draw, x, y, w, h, title, subtitle=None, bg=PALETTE['white'], border=PALETTE['border'], border_w=2, radius=12, header_bg=None, header_h=46):
    # Rounded rect background
    draw.rounded_rectangle([x, y, x + w, y + h], radius=radius, fill=bg, outline=border, width=border_w)
    
    # Header bar if provided
    if header_bg:
        # draw header slice
        draw.rounded_rectangle([x, y, x + w, y + header_h + 10], radius=radius, fill=header_bg)
        draw.rectangle([x, y + radius, x + w, y + header_h], fill=header_bg)
        # re-outline box
        draw.rounded_rectangle([x, y, x + w, y + h], radius=radius, outline=border, width=border_w)
        # header text
        draw.text((x + 18, y + 10), title, font=FONTS['card_header'], fill=PALETTE['white'])
        if subtitle:
            draw.text((x + 18, y + 36), subtitle, font=FONTS['card_sub'], fill='#E0E7FF')
    else:
        if title:
            draw.text((x + 18, y + 14), title, font=FONTS['card_header'], fill=PALETTE['navy'])
            if subtitle:
                draw.text((x + 18, y + 42), subtitle, font=FONTS['card_sub'], fill=PALETTE['text_muted'])

def draw_bullet_item(draw, x, y, max_w, bold_prefix, text, bullet="•", icon_color=PALETTE['slate_blue']):
    draw.text((x, y), bullet, font=FONTS['body_bold'], fill=icon_color)
    prefix_w, _ = text_size(draw, bold_prefix + " ", FONTS['body_bold'])
    draw.text((x + 22, y), bold_prefix, font=FONTS['body_bold'], fill=PALETTE['text_dark'])
    
    # wrap rest of text
    remaining_w = max_w - 22 - prefix_w
    lines = wrap_text(text, FONTS['body'], remaining_w)
    if lines:
        draw.text((x + 22 + prefix_w, y), lines[0], font=FONTS['body'], fill=PALETTE['text_muted'])
        cur_y = y + 25
        for line in lines[1:]:
            draw.text((x + 22, cur_y), line, font=FONTS['body'], fill=PALETTE['text_muted'])
            cur_y += 25
        return cur_y
    return y + 26

def draw_badge(draw, x, y, text, bg=PALETTE['soft_blue'], text_color=PALETTE['slate_blue'], border=PALETTE['border_light']):
    tw, th = text_size(draw, text, FONTS['badge'])
    pad_x, pad_y = 10, 4
    draw.rounded_rectangle([x, y, x + tw + pad_x*2, y + th + pad_y*2], radius=6, fill=bg, outline=border, width=1)
    draw.text((x + pad_x, y + pad_y - 1), text, font=FONTS['badge'], fill=text_color)
    return x + tw + pad_x*2

def draw_arrow(draw, start, end, label=None, sublabel=None, color=PALETTE['slate_blue'], width=3, dashed=False, arrow_at_end=True, arrow_at_start=False):
    # straight or orthogonal arrow
    x1, y1 = start
    x2, y2 = end
    
    if dashed:
        # draw dashed line
        total_dist = math.hypot(x2 - x1, y2 - y1)
        dash_len = 10
        gap_len = 6
        if total_dist > 0:
            num_dashes = int(total_dist / (dash_len + gap_len))
            dx = (x2 - x1) / total_dist
            dy = (y2 - y1) / total_dist
            for i in range(num_dashes):
                s_dist = i * (dash_len + gap_len)
                e_dist = min(s_dist + dash_len, total_dist)
                draw.line([(x1 + dx * s_dist, y1 + dy * s_dist), (x1 + dx * e_dist, y1 + dy * e_dist)], fill=color, width=width)
    else:
        draw.line([start, end], fill=color, width=width)
        
    # Draw arrow heads
    def draw_head(tip_x, tip_y, from_x, from_y):
        angle = math.atan2(tip_y - from_y, tip_x - from_x)
        arrow_size = 14
        left_angle = angle + math.pi * 5 / 6
        right_angle = angle - math.pi * 5 / 6
        p1 = (tip_x, tip_y)
        p2 = (tip_x + arrow_size * math.cos(left_angle), tip_y + arrow_size * math.sin(left_angle))
        p3 = (tip_x + arrow_size * math.cos(right_angle), tip_y + arrow_size * math.sin(right_angle))
        draw.polygon([p1, p2, p3], fill=color)

    if arrow_at_end:
        draw_head(x2, y2, x1, y1)
    if arrow_at_start:
        draw_head(x1, y1, x2, y2)
        
    # Draw label if present
    if label:
        mid_x = (x1 + x2) / 2
        mid_y = (y1 + y2) / 2
        lw, lh = text_size(draw, label, FONTS['arrow_label'])
        sw, sh = (0, 0)
        if sublabel:
            sw, sh = text_size(draw, sublabel, FONTS['arrow_sub'])
        box_w = max(lw, sw) + 20
        box_h = lh + (sh + 6 if sublabel else 0) + 12
        bx = mid_x - box_w / 2
        by = mid_y - box_h / 2
        draw.rounded_rectangle([bx, by, bx + box_w, by + box_h], radius=6, fill=PALETTE['white'], outline=PALETTE['border'], width=1)
        draw.text((mid_x - lw/2, by + 5), label, font=FONTS['arrow_label'], fill=color)
        if sublabel:
            draw.text((mid_x - sw/2, by + 5 + lh + 4), sublabel, font=FONTS['arrow_sub'], fill=PALETTE['text_muted'])

def draw_elbow_arrow(draw, points, label=None, sublabel=None, color=PALETTE['slate_blue'], width=3, dashed=False, arrow_at_end=True):
    for i in range(len(points) - 1):
        p1 = points[i]
        p2 = points[i+1]
        is_last = (i == len(points) - 2)
        draw_arrow(draw, p1, p2, color=color, width=width, dashed=dashed, arrow_at_end=(is_last and arrow_at_end))
    
    if label and len(points) >= 2:
        # place on middle segment
        mid_seg = len(points) // 2
        p1 = points[mid_seg - 1]
        p2 = points[mid_seg]
        mid_x = (p1[0] + p2[0]) / 2
        mid_y = (p1[1] + p2[1]) / 2
        lw, lh = text_size(draw, label, FONTS['arrow_label'])
        sw, sh = (0, 0)
        if sublabel:
            sw, sh = text_size(draw, sublabel, FONTS['arrow_sub'])
        box_w = max(lw, sw) + 20
        box_h = lh + (sh + 6 if sublabel else 0) + 12
        bx = mid_x - box_w / 2
        by = mid_y - box_h / 2
        draw.rounded_rectangle([bx, by, bx + box_w, by + box_h], radius=6, fill=PALETTE['white'], outline=PALETTE['border'], width=1)
        draw.text((mid_x - lw/2, by + 5), label, font=FONTS['arrow_label'], fill=color)
        if sublabel:
            draw.text((mid_x - sw/2, by + 5 + lh + 4), sublabel, font=FONTS['arrow_sub'], fill=PALETTE['text_muted'])
