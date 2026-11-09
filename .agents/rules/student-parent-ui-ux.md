---
name: student-parent-ui-ux
description: Strict 60-30-10 color palette, proportional typography scale, and compact button/control design standards for Student and Parent portals (Light & Dark mode).
---

# Student & Parent Portal UI/UX Standards (60-30-10 & Typography Rule)

All screens, widgets, and flows in the **Student** and **Parent** portals must strictly follow these visual, typographic, and interaction rules in both Light and Dark mode:

## 1. Strict 60-30-10 Color Allocation
- **60% Dominant (Backgrounds & Primary Surfaces)**:
  - Light Mode: Scaffold `#F5F5F5`, Card Surface `#FFFFFF`.
  - Dark Mode: Scaffold `#111827`, Card Surface `#263040`.
- **30% Secondary (Supporting Containers, Subtle Headers, Unselected Pills, Borders)**:
  - Light Mode: `#E8EBE2` (warm sage) / `#F8FAFC` (slate tint), borders `#E2E8F0`.
  - Dark Mode: `#1F2937` / `#1E293B`, borders `onSurface.withValues(alpha: 0.10)`.
- **10% Accent (Primary CTAs, Active Question Pills, Selected Option Borders, Progress Fills)**:
  - Light Mode: `#487898` (Steel Blue — `colorScheme.primary`).
  - Dark Mode: `#60A5FA` (Sky Blue — `colorScheme.primary`).
- **No Loud Semantic Theme Overrides**:
  - **NEVER** paint `AppBar` backgrounds, full-screen overlays, or primary start/navigation buttons in `AppTheme.catRed` or `AppTheme.catOrange` (e.g. for Examinations or timers).
  - Semantic colors (`catGreen`, `catOrange`, `catRed`) must only be used at small scale (status dots, subtle text/icon accents, or inline validation errors).

## 2. Proportional Typography Scale (No Oversized Text)
Student and Parent portals are frequently used on mobile viewports (`360px–430px` width). Text sizes must remain balanced and compact:
- **AppBar / Screen Title**: `15px–16px`, `FontWeight.w700` (never `20px+`).
- **Card / Section Header**: `14px–15px`, `FontWeight.w700`.
- **Assessment Question / Primary Prompt**: `14.5px–15.5px`, `FontWeight.w600`, `height: 1.45` (never `18px–22px`).
- **Body / Choice Option / Input Text**: `13px–13.5px`, `FontWeight.w500`.
- **Pills / Badges / Timer / Metadata**: `11px–12px`, `FontWeight.w600`.

## 3. Compact Buttons, Choices & Unboxed Navigation
- **Button Dimensions**:
  - Primary & Secondary buttons: `height: 36px–38px`, `padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8)`, `fontSize: 13px`, `FontWeight.w600`, `borderRadius: 8px`.
  - Avoid oversized `48px–56px` height buttons or wide fixed-width buttons that cause text truncation (`"7 ..."`).
- **Unboxed Flow Navigation (`Previous` / `Next` / `Submit`)**:
  - Do not trap `Previous` and `Next` buttons inside a heavy bordered box at the bottom of the card. Place them cleanly in the content flow with a subtle top divider or natural spacing.
  - `Previous` should be a clean, low-emphasis text/ghost button (`← Previous`), while `Next` / `Submit` uses the 10% primary accent (`#487898` / `#60A5FA`).
- **Compact Choice Cards**:
  - Use custom compact option rows (`padding: EdgeInsets.symmetric(horizontal: 14, vertical: 11)`, 18px radio circle) instead of bulky default `RadioListTile`.

## 4. Non-Intrusive Loading & Freeze States
- Never block active student assessments with pop-up warning modals when pressing back or experiencing brief network jitter.
- When syncing or waiting for connection recovery, use a calm **frosted freeze + loading indicator** (`BackdropFilter` blur + steel-blue `CircularProgressIndicator` + concise `13px` status text) rather than alarming red full-screen error walls.
- Strictly use vector icons (`LucideIcons` / `Icons`); never use emojis.

