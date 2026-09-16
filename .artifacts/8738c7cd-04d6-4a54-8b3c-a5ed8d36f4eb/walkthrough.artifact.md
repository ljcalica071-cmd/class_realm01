# Walkthrough - Manage Students Table & Actions Redesign

## Summary of Completed Updates
In accordance with your feedback and reference design:

1. **Columns Removed**:
   - Removed `PARENT`, `REMARKS`, and `FILES` columns from the table.

2. **Actions Column Enhanced**:
   - Added the **Transfer Section** action button (`Icons.swap_horiz`) with tooltip `"Transfer to another section"`.
   - Clicking opens a clean transfer modal allowing selection of a target section from the available managed sections, updating the student's assigned section with a confirmation dialogue.
   - Retained the **Edit Student** (`Icons.edit_outlined`) and **Archive Student / Restore** (`Icons.delete_outline` / `Icons.restore`) buttons.

3. **Table Column Styling & Separation**:
   - Matched the design in the reference screenshots with prominent vertical divider borders on each column header (`0xFF2563EB`) and row cell (`0xFFF1F5F9`).
   - Highlighted blue header container (`#1A56DB`) matching the reference web portal.

4. **Clickable Header Sorting & Filter Icons**:
   - Each column title (`LAST NAME ▴`, `FIRST NAME ↕`, `LRN ↕`, `GENDER ↕`, `BIRTHDATE ↕`, `EMAIL ↕`, `CONTACT NO. ↕`, `STATUS ↕`) is clickable with sort indicators (`▴` / `▾` / `↕`) that toggle ascending/descending order.

5. **Bidirectional Scrolling (Horizontal & Vertical)**:
   - Wrapped the table in a horizontal `SingleChildScrollView` with fixed column widths, preventing any text truncation on long names or email addresses.
   - Enabled vertical scrolling via `ListView.builder` for the rows.
