import os
import stat

path = r"c:\Users\Admin\AndroidStudioProjects\class_realm01\INTEGRATED_SENIOR_HIGH_SCHOOL_ATTENDANCE_CH1_CH2_CH3.docx"
st = os.stat(path)
print(f"Mode: {oct(st.st_mode)}")
is_readonly = not bool(st.st_mode & stat.S_IWRITE)
print(f"Is readonly: {is_readonly}")

if is_readonly:
    os.chmod(path, stat.S_IWRITE)
    print("Removed readonly attribute via chmod!")

# Try opening in 'ab' mode
try:
    with open(path, 'ab') as f:
        print("Successfully opened in 'ab' mode!")
except Exception as e:
    print(f"Open failed: {type(e)} {e}")
