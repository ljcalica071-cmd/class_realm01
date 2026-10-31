import zipfile

for name, path in [
    ("Target Doc", r"c:\Users\Admin\AndroidStudioProjects\class_realm01\INTEGRATED SENIOR HIGH SCHOOL ATTENDANCE.docx"),
    ("Sample Ch2", r"c:\Users\Admin\Downloads\Acitivity#3_Chapter2.docx"),
    ("Calica Ch1-2", r"c:\Users\Admin\Downloads\Calica, L jay & San Juan, John Rex.docx"),
    ("Chapter2_ClassRealm_Revised", r"c:\Users\Admin\Downloads\Chapter2_ClassRealm_Revised_Corrected(1).docx")
]:
    try:
        with zipfile.ZipFile(path, 'r') as z:
            media = [f for f in z.namelist() if f.startswith('word/media/')]
            print(f"{name}: {len(media)} media files -> {media[:5]}")
    except Exception as e:
        print(f"{name}: Error {e}")
