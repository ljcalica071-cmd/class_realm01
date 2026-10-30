import os
import sys
import shutil

backup_candidates = [
    r"c:\Users\Admin\AndroidStudioProjects\class_realm01\INTEGRATED SENIOR HIGH SCHOOL ATTENDANCE.backup.docx",
    r"c:\Users\Admin\AndroidStudioProjects\class_realm01\.agents\teamwork\worker_ch1_ch2_compiler\INTEGRATED SENIOR HIGH SCHOOL ATTENDANCE.backup.docx"
]

target = r"c:\Users\Admin\AndroidStudioProjects\class_realm01\INTEGRATED SENIOR HIGH SCHOOL ATTENDANCE.docx"

print("Checking backup file...", flush=True)
for b in backup_candidates:
    if os.path.exists(b):
        print(f"Found backup at: {b} (size: {os.path.getsize(b)})", flush=True)
        try:
            shutil.copy2(b, target)
            print(f"Restored backup to {target}", flush=True)
        except Exception as e:
            print(f"Error copying backup: {e}", flush=True)
        break
else:
    print("No backup file found, proceeding with target directly.", flush=True)

print("Now executing build_full_document.py...", flush=True)
try:
    import docx
    print(f"python-docx version: {docx.__version__}", flush=True)
    # Import and run main
    sys.path.insert(0, r"c:\Users\Admin\AndroidStudioProjects\class_realm01\.agents\teamwork\worker_ch1_ch2_compiler")
    import build_full_document
    build_full_document.main()
    print("build_full_document completed successfully!", flush=True)
except Exception as e:
    import traceback
    print("Exception during build:", flush=True)
    traceback.print_exc()

