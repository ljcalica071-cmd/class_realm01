import re
file_path = 'lib/core/utils/validators.dart'

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace("static const int maxClassworkInstructionsLength = 30000;", "static const int maxClassworkInstructionsLength = 1000;")

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)
