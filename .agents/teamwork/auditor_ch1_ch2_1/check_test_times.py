import os
import datetime

for folder in [r"c:\Users\Admin\AndroidStudioProjects\class_realm01\test\scripts", r"c:\Users\Admin\AndroidStudioProjects\class_realm01\test\features\teacher\grading"]:
    if os.path.exists(folder):
        for f in os.listdir(folder):
            fp = os.path.join(folder, f)
            mtime = os.path.getmtime(fp)
            ctime = os.path.getctime(fp)
            m_dt = datetime.datetime.fromtimestamp(mtime, tz=datetime.timezone.utc)
            c_dt = datetime.datetime.fromtimestamp(ctime, tz=datetime.timezone.utc)
            print(f"{fp}: mtime={m_dt.isoformat()}, ctime={c_dt.isoformat()}")
