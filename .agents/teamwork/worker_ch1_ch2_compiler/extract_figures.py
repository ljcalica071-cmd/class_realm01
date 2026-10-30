import zipfile
import os

source_docx = r"c:\Users\Admin\Downloads\Chapter2_ClassRealm_Revised_Corrected(1).docx"
output_dir = r"c:\Users\Admin\AndroidStudioProjects\class_realm01\.agents\teamwork\worker_ch1_ch2_compiler\figures"
os.makedirs(output_dir, exist_ok=True)

if os.path.exists(source_docx):
    with zipfile.ZipFile(source_docx, 'r') as z:
        for f in z.namelist():
            if f.startswith('word/media/'):
                fname = os.path.basename(f)
                outpath = os.path.join(output_dir, fname)
                with open(outpath, 'wb') as out_f:
                    out_f.write(z.read(f))
                print(f"Extracted {f} -> {outpath} ({os.path.getsize(outpath)} bytes)")
else:
    print(f"Source file {source_docx} does not exist!")
