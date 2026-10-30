import shutil
import os

src = r"c:\Users\Admin\AndroidStudioProjects\class_realm01\INTEGRATED SENIOR HIGH SCHOOL ATTENDANCE.docx"
dst = r"c:\Users\Admin\AndroidStudioProjects\class_realm01\.agents\teamwork\worker_ch1_ch2_compiler\INTEGRATED SENIOR HIGH SCHOOL ATTENDANCE.backup.docx"

if os.path.exists(src):
    shutil.copy2(src, dst)
    print(f"Backup created at {dst} ({os.path.getsize(dst)} bytes)")
else:
    print("Source file not found!")
