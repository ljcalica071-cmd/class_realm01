import docx
import re
import json

doc_path = r"c:\Users\Admin\AndroidStudioProjects\class_realm01\INTEGRATED SENIOR HIGH SCHOOL ATTENDANCE.docx"
doc = docx.Document(doc_path)

ch1_paras = []
in_ch1 = False

for i, p in enumerate(doc.paragraphs):
    t = p.text.strip()
    if t == "CHAPTER I":
        in_ch1 = True
    elif t == "CHAPTER II":
        in_ch1 = False
        break
    if in_ch1 and t:
        ch1_paras.append((i, t))

print(f"Total Chapter 1 non-empty paragraphs: {len(ch1_paras)}")

ch1_full_text = "\n\n".join([f"[{idx}] {t}" for idx, t in ch1_paras])

with open(r"c:\Users\Admin\AndroidStudioProjects\class_realm01\.agents\teamwork\reviewer_ch1_ch2_1\ch1_full_text.txt", "w", encoding="utf-8") as f:
    f.write(ch1_full_text)

# Analysis findings
audit = {}

# 1. Pilot institution naming
school_hits = re.findall(r"Eduardo Barreto\s+[A-Za-z\.]+\s+High School", ch1_full_text, re.IGNORECASE)
wrong_school_hits = re.findall(r"Eduardo Barretto|Barretto|Integrated School", ch1_full_text, re.IGNORECASE)
audit["pilot_school"] = {
    "hits": school_hits,
    "wrong_hits": wrong_school_hits,
    "exact_count": ch1_full_text.count("Eduardo Barreto Sr. High School")
}

# 2. Client naming
client_hits = re.findall(r"Karen P\. Gonzaga[^,\.]*", ch1_full_text)
audit["client"] = {
    "hits": client_hits,
    "has_maam": "Ma’am Karen P. Gonzaga" in ch1_full_text or "Ma'am Karen P. Gonzaga" in ch1_full_text,
    "has_title": "Senior High School Mathematics Teacher" in ch1_full_text
}

# 3. Roles
roles = {
    "Admin": "Admin Portal" in ch1_full_text,
    "Teacher_web_app": "Teacher Portal (Web & Responsive App)" in ch1_full_text or "Teacher Portal (Responsive Web and App)" in ch1_full_text,
    "Student_app": "Student Portal" in ch1_full_text,
    "Parent_app": "Parent Portal" in ch1_full_text
}
audit["roles"] = roles

# 4. Scope & Boundaries
boundaries = {
    "admin_rollover_provisioning_only": "solely for academic year transitions and teacher provisioning" in ch1_full_text or "academic year transitions and teacher provisioning" in ch1_full_text,
    "admin_no_access_details": "Admin CANNOT manage" in ch1_full_text or "without access to classroom instructional data or student grades" in ch1_full_text,
    "teacher_self_manage_rosters": "Teachers self-manage sections, subjects, and students after receiving class rosters" in ch1_full_text,
    "exclude_registrar_principal": "excludes Registrar and Principal" in ch1_full_text or "excludes registrar and principal" in ch1_full_text.lower(),
    "exclude_transfer_drop": "transfer" in ch1_full_text.lower() and "dropping" in ch1_full_text.lower(),
    "preservation_and_export": "preserves academic and grade records" in ch1_full_text.lower() or "downloading and exporting" in ch1_full_text.lower()
}
audit["boundaries"] = boundaries

# 5. Attendance tracking
attendance = {
    "rfid_specified": "RFID" in ch1_full_text,
    "esp32_specified": "ESP32" in ch1_full_text,
    "nfc_fallback": "NFC" in ch1_full_text,
    "permanent_manual_fallback": "permanent" in ch1_full_text.lower() and "manual" in ch1_full_text.lower() and "fallback" in ch1_full_text.lower()
}
audit["attendance"] = attendance

# 6. SMART criteria
smart = {
    "sy_2026_2027": "2026–2027" in ch1_full_text or "2026-2027" in ch1_full_text,
    "tap_latency": "< 2.0 seconds" in ch1_full_text,
    "buffer_capacity": "5,000" in ch1_full_text,
    "sync_latency": "< 5.0 seconds" in ch1_full_text,
    "quiz_turnaround": "< 1.0 second" in ch1_full_text,
    "psychometrics": "< 2.0 seconds" in ch1_full_text,
    "push_notification": "< 3.0 seconds" in ch1_full_text,
    "iso_25010": "4.20" in ch1_full_text
}
audit["smart"] = smart

# 7. Parent auth, offline sync, duplicate attendance
policies = {
    "parent_auth": "Parent" in ch1_full_text and "linked" in ch1_full_text,
    "offline_sync": "synchroniz" in ch1_full_text.lower() and "offline" in ch1_full_text.lower(),
    "duplicate_detection_idempotent": "idempotent" in ch1_full_text.lower(),
    "test_thresholds_cutoffs": "Present window" in ch1_full_text and "Late cutoff" in ch1_full_text and "Absent cutoff" in ch1_full_text
}
audit["policies"] = policies

# 8. Definition of Terms (9 terms)
terms = [
    "ESP32", "RFID", "Firebase Authentication", "Supabase",
    "Row-Level Security", "Admin Portal", "Teacher Portal",
    "Student Portal", "Parent Portal"
]
def_checks = {}
for term in terms:
    def_checks[term] = term in ch1_full_text and f"1.6 Definition of Terms" in ch1_full_text
audit["definitions"] = def_checks

with open(r"c:\Users\Admin\AndroidStudioProjects\class_realm01\.agents\teamwork\reviewer_ch1_ch2_1\audit_results.json", "w", encoding="utf-8") as f:
    json.dump(audit, f, indent=2)

print("AUDIT RESULTS:")
print(json.dumps(audit, indent=2))
