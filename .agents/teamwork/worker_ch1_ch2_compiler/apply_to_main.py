import os
import shutil

src = r"c:\Users\Admin\AndroidStudioProjects\class_realm01\INTEGRATED SENIOR HIGH SCHOOL ATTENDANCE_REVISED.docx"
dst = r"c:\Users\Admin\AndroidStudioProjects\class_realm01\INTEGRATED SENIOR HIGH SCHOOL ATTENDANCE.docx"

if os.path.exists(src):
    try:
        shutil.copy2(src, dst)
        print(f"Successfully copied {src} to {dst}!")
    except PermissionError:
        print("Notice: Word still has the original file open. Please close Microsoft Word first.")
    except Exception as e:
        print(f"Error copying file: {e}")
else:
    print(f"Source file {src} not found.")

