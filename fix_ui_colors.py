import os
import re

# 1. App Theme
theme_path = 'lib/core/theme/app_theme.dart'
with open(theme_path, 'r', encoding='utf-8') as f:
    theme_content = f.read()

# Fix light theme input
theme_content = theme_content.replace(
    "fillColor: const Color(0xFFF9FAFB),",
    "fillColor: const Color(0xFFF9FAFB),\n        labelStyle: const TextStyle(color: Color(0xFF374151)),\n        hintStyle: const TextStyle(color: Color(0xFF6B7280)),"
)
# Fix dark theme input hint and borders
theme_content = theme_content.replace(
    "fillColor: _darkSurface,",
    "fillColor: _darkSurface,\n        hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),"
)
theme_content = theme_content.replace(
    "color: Colors.white.withValues(alpha: 0.06),",
    "color: Colors.white.withValues(alpha: 0.15),"
)
theme_content = theme_content.replace(
    "borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),",
    "borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.2)),"
)
with open(theme_path, 'w', encoding='utf-8') as f:
    f.write(theme_content)

# 2. Modals Background
modals = [
    'lib/features/teacher/sub_features/assessments/screens/create_assessment_flow.dart',
    'lib/features/teacher/sub_features/assessments/screens/create_requirement_flow.dart',
    'lib/features/teacher/sub_features/assessments/screens/edit_assessment_flow.dart',
    'lib/features/teacher/sub_features/schedule_and_lessons/widgets/teacher_material_viewer_modal.dart'
]
for m in modals:
    if os.path.exists(m):
        with open(m, 'r', encoding='utf-8') as f:
            m_content = f.read()
        m_content = m_content.replace("backgroundColor: Colors.white,", "backgroundColor: Theme.of(context).colorScheme.surface,")
        m_content = m_content.replace("backgroundColor: theme.colorScheme.surface,", "backgroundColor: Theme.of(context).colorScheme.surface,")
        with open(m, 'w', encoding='utf-8') as f:
            f.write(m_content)

# 3. Gradebook Overflow
grade_path = 'lib/features/teacher/sub_features/grading/widgets/teacher_gradebook_tab.dart'
with open(grade_path, 'r', encoding='utf-8') as f:
    g_content = f.read()
g_content = g_content.replace("width: 231.5", "width: 232.0")
g_content = g_content.replace("width: 231.0", "width: 232.0")
g_content = g_content.replace("Container(\n                  height: 37,", "Container(\n                  height: 39,")
g_content = g_content.replace("Container(\n                  height: 38,", "Container(\n                  height: 39,")
g_content = g_content.replace("height: 74,", "height: 76,")
g_content = g_content.replace("height: 75,", "height: 76,")
g_content = g_content.replace("height: 111,", "height: 113,")
g_content = g_content.replace("height: 112,", "height: 113,")
with open(grade_path, 'w', encoding='utf-8') as f:
    f.write(g_content)

# 4. Schedule Grid Dark Mode
grid_path = 'lib/features/teacher/widgets/timetable_grid_widget.dart'
with open(grid_path, 'r', encoding='utf-8') as f:
    gr_content = f.read()

gr_content = gr_content.replace("Widget _buildHeader(double dayWidth) {", "Widget _buildHeader(BuildContext context, double dayWidth) {")
gr_content = gr_content.replace("_buildHeader(dayWidth)", "_buildHeader(context, dayWidth)")

gr_content = gr_content.replace("Widget _buildGridBackground(double dayWidth) {", "Widget _buildGridBackground(BuildContext context, double dayWidth) {")
gr_content = gr_content.replace("_buildGridBackground(dayWidth)", "_buildGridBackground(context, dayWidth)")

gr_content = gr_content.replace("""    return Container(
      height: 50,
      decoration: const BoxDecoration(
        color: Color(0xFFF1F5F9),
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),
      ),""", """    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1F2937) : const Color(0xFFF1F5F9),
        border: Border(bottom: BorderSide(color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF374151) : const Color(0xFFE2E8F0))),
      ),""")

gr_content = gr_content.replace("""              decoration: const BoxDecoration(
                border: Border(left: BorderSide(color: Color(0xFFE2E8F0))),
              ),
              child: Text(
                day.substring(0, 3).toUpperCase(),
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                  color: Color(0xFF475569),
                  letterSpacing: 1.2,
                ),""", """              decoration: BoxDecoration(
                border: Border(left: BorderSide(color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF374151) : const Color(0xFFE2E8F0))),
              ),
              child: Text(
                day.substring(0, 3).toUpperCase(),
                style: TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                  letterSpacing: 1.2,
                ),""")

gr_content = gr_content.replace("""                color: isHourStart
                    ? const Color(0xFFE2E8F0)
                    : const Color(0xFFF1F5F9),""", """                color: isHourStart
                    ? (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF374151) : const Color(0xFFE2E8F0))
                    : (Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1F2937) : const Color(0xFFF1F5F9)),""")

gr_content = gr_content.replace("""                    color: isHourStart
                        ? const Color(0xFF1E293B)
                        : const Color(0xFF94A3B8),""", """                    color: isHourStart
                        ? Theme.of(context).colorScheme.onSurface
                        : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),""")

gr_content = gr_content.replace("""                  decoration: const BoxDecoration(
                    border: Border(
                      left: BorderSide(color: Color(0xFFF1F5F9), width: 1),
                    ),
                  ),""", """                  decoration: BoxDecoration(
                    border: Border(
                      left: BorderSide(color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF1F2937) : const Color(0xFFF1F5F9), width: 1),
                    ),
                  ),""")
with open(grid_path, 'w', encoding='utf-8') as f:
    f.write(gr_content)

print("All UI changes applied.")
