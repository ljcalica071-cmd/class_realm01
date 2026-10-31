import os
import subprocess
import datetime

def check_file_isolation():
    print("=== FILE ISOLATION AUDIT ===")
    
    # 1. Get git status for lib/ and test/
    cmd = ["git", "status", "--porcelain", "lib", "test"]
    res = subprocess.run(cmd, capture_output=True, text=True)
    print("git status --porcelain lib test:")
    print(res.stdout)
    
    lines = res.stdout.strip().splitlines()
    files_in_git = []
    for line in lines:
        parts = line.strip().split()
        if len(parts) >= 2:
            files_in_git.append(parts[-1])
            
    print(f"Total entries reported by git in lib/ and test/: {len(files_in_git)}")
    
    # 2. Check timestamps of these files
    print("\n--- Timestamps of modified/untracked files in lib/ and test/ ---")
    for f in files_in_git:
        if os.path.exists(f):
            mtime = os.path.getmtime(f)
            dt = datetime.datetime.fromtimestamp(mtime, tz=datetime.timezone.utc)
            print(f"{f}: {dt.isoformat()}")
            
    # 3. Check when the worker started compiling Chapters 1 & 2
    # Check worker_ch1_ch2_compiler files timestamps
    worker_dir = r"c:\Users\Admin\AndroidStudioProjects\class_realm01\.agents\teamwork\worker_ch1_ch2_compiler"
    if os.path.exists(worker_dir):
        print(f"\n--- Timestamps of worker files in {worker_dir} ---")
        for root, dirs, files in os.walk(worker_dir):
            for file in files:
                fp = os.path.join(root, file)
                mtime = os.path.getmtime(fp)
                dt = datetime.datetime.fromtimestamp(mtime, tz=datetime.timezone.utc)
                print(f"{file}: {dt.isoformat()}")
                
    # Check git diff stat to see when the commits or modifications were made
    res_diff = subprocess.run(["git", "diff", "--stat", "lib", "test"], capture_output=True, text=True)
    print("\ngit diff --stat lib test:")
    print(res_diff.stdout)
    
    # Check last commit log
    res_log = subprocess.run(["git", "log", "-n", "3", "--oneline"], capture_output=True, text=True)
    print("\nLast 3 git commits:")
    print(res_log.stdout)

if __name__ == '__main__':
    check_file_isolation()
