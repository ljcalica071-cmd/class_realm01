import os
import datetime
import sys

project_root = r"c:\Users\Admin\AndroidStudioProjects\class_realm01"
prompt_time = datetime.datetime(2026, 10, 29, 8, 50, 0, tzinfo=datetime.timezone.utc)

dirs_to_check = [
    os.path.join(project_root, "lib"),
    os.path.join(project_root, "test")
]

modified_after_prompt = []
all_files_scanned = 0

for d in dirs_to_check:
    for root, dirs, files in os.walk(d):
        for f in files:
            all_files_scanned += 1
            path = os.path.join(root, f)
            mtime = os.path.getmtime(path)
            dt = datetime.datetime.fromtimestamp(mtime, tz=datetime.timezone.utc)
            if dt >= prompt_time:
                modified_after_prompt.append((path, dt.isoformat()))

print(f"Total files scanned in lib/ and test/: {all_files_scanned}")
print(f"Files modified after prompt timestamp ({prompt_time.isoformat()}): {len(modified_after_prompt)}")
for p, t in modified_after_prompt:
    print(f"  VIOLATION: {p} modified at {t}")

if modified_after_prompt:
    sys.exit(1)
else:
    print("CODE ISOLATION VERIFIED: Exactly ZERO files in lib/ and test/ were modified after prompt time.")
    sys.exit(0)
