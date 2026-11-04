import re
theme_path = 'lib/core/theme/app_theme.dart'
with open(theme_path, 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace("""        fillColor: const Color(0xFFF9FAFB),
        labelStyle: const TextStyle(color: Color(0xFF374151)),
        hintStyle: const TextStyle(color: Color(0xFF6B7280)),
        labelStyle: const TextStyle(color: Color(0xFF374151)),
        hintStyle: const TextStyle(color: Color(0xFF6B7280)),""", """        fillColor: const Color(0xFFF9FAFB),
        labelStyle: const TextStyle(color: Color(0xFF374151)),
        hintStyle: const TextStyle(color: Color(0xFF6B7280)),""")

content = content.replace("""        fillColor: _darkSurface,
        hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
        hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),""", """        fillColor: _darkSurface,
        hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),""")

content = re.sub(r'hintStyle:\s+const\s+TextStyle\([^)]+\),\s+hintStyle:\s+const\s+TextStyle\([^)]+\),', 'hintStyle: const TextStyle(color: Color(0xFF6B7280)),', content)
content = re.sub(r'labelStyle:\s+const\s+TextStyle\([^)]+\),\s+labelStyle:\s+const\s+TextStyle\([^)]+\),', 'labelStyle: const TextStyle(color: Color(0xFF374151)),', content)

with open(theme_path, 'w', encoding='utf-8') as f:
    f.write(content)
