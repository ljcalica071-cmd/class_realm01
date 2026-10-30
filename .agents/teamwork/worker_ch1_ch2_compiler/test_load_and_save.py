"""
test_load_and_save.py
Tests loading from backup_path directly and saving to revised docx
"""

import os
import sys
import docx
from docx import Document

BACKUP_PATH = r"c:\Users\Admin\AndroidStudioProjects\class_realm01\.agents\teamwork\worker_ch1_ch2_compiler\INTEGRATED SENIOR HIGH SCHOOL ATTENDANCE.backup.docx"
DOC_PATH = r"c:\Users\Admin\AndroidStudioProjects\class_realm01\INTEGRATED SENIOR HIGH SCHOOL ATTENDANCE.docx"
REVISED_PATH = r"c:\Users\Admin\AndroidStudioProjects\class_realm01\INTEGRATED SENIOR HIGH SCHOOL ATTENDANCE_REVISED.docx"

print(f"Loading template from {BACKUP_PATH}...", flush=True)
doc = Document(BACKUP_PATH)
print(f"Loaded! Body elements: {len(doc._body._body)}", flush=True)

print(f"Testing save to {REVISED_PATH}...", flush=True)
doc.save(REVISED_PATH)
print(f"Saved to {REVISED_PATH} successfully! Size: {os.path.getsize(REVISED_PATH)}", flush=True)

print(f"Testing write to {DOC_PATH}...", flush=True)
try:
    doc.save(DOC_PATH)
    print(f"Saved to {DOC_PATH} successfully!", flush=True)
except PermissionError as e:
    print(f"DOC_PATH is currently locked: {e}", flush=True)
except Exception as e:
    print(f"Error saving to DOC_PATH: {e}", flush=True)

