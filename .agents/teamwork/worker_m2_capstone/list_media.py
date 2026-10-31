import zipfile
import xml.etree.ElementTree as ET

file_path = r"c:\Users\Admin\AndroidStudioProjects\class_realm01\INTEGRATED_SENIOR_HIGH_SCHOOL_ATTENDANCE_CH1_CH2_CH3.docx"

with zipfile.ZipFile(file_path, 'r') as z:
    for name in z.namelist():
        if name.startswith('word/media/'):
            info = z.getinfo(name)
            print(f"{name}: {info.file_size} bytes")
