# CLASSREALM UNIFIED RFID & NFC ATTENDANCE SYSTEM
## Complete Architectural Reference, Implementation Guide & Handover Documentation
*Created: November 4, 2026*  
*For: ClassRealm Development Team & Engineering Handover*

---

## 1. Executive Summary & Core Philosophy

Ang ClassRealm Attendance Engine ay gumagamit ng **Unified RFID Pipeline**. 
Ito ay nangangahulugan na:
1. **Isang RFID Card Lamang Bawat Estudyante Para sa Buong Eskwelahan:**
   - Ang `rfid_uid` ay nakatali sa profile ng estudyante (`student_profiles.rfid_uid`).
   - Kapag nai-link na ng kahit sinong teacher ang card sa estudyante, **awtomatikong gagana na ito sa lahat ng subjects, sections, at teachers**.
   - Hindi kailangang mag-register ng panibagong card si student sa bawat subject.
2. **Magkasamang Pipeline: ESP32 Hardware + Phone NFC:**
   - Ang **ESP32 (RC522) RFID Door Scanner** ang Primary Automated Scanner.
   - Ang **Teacher Android Phone NFC** ang Secondary / Reserve Scanner.
   - **IISANG RECORDING METHOD LANG:** Pareho silang naitatala sa database bilang:
     $$\text{recording\_method} = \text{'RFID'}$$
   - Walang hiwalay na `"NFC"` method. Ang pinagkaiba lamang nila ay ang **`device_id`**:
     - ESP32 Door Scanner: `device_id = 'HARDWARE_ESP32'`
     - Teacher Phone NFC: `device_id = 'MOBILE_NFC'`
     - Auto-Absent Job: `recording_method = 'System'`, `device_id = 'SYSTEM_CRON'`
     - Manual Teacher Override: `recording_method = 'Manual'`

---

## 2. Database Schema (Supabase PostgreSQL)

Kamakailan lamang ay inilapat ang migration sa live Supabase production project (`ClassRealm` / `wfilyatkfgqtybujmahf`).

### A. Table: `public.student_profiles`
| Column | Type | Constraints | Description |
| :--- | :--- | :--- | :--- |
| `student_id` | `varchar` | Primary Key | Unique Student ID |
| `lrn` | `varchar` | Unique | DepEd Learner Reference Number |
| `first_name` | `varchar` | Not Null | Pangalan ng estudyante |
| `last_name` | `varchar` | Not Null | Apelyido |
| `rfid_uid` | `varchar(64)` | Unique (`uq_student_profiles_rfid_uid`) | Canonical Hex UID ng RFID card (e.g. `04A1B2C3`) |

### B. Table: `public.attendance_records`
| Column | Type | Constraints | Description |
| :--- | :--- | :--- | :--- |
| `id` | `uuid` | Primary Key | UUID ng attendance record |
| `student_id` | `varchar` | References `student_profiles` | Foreign Key sa estudyante |
| `subject_offering_id` | `uuid` | References `subject_offerings` | Klase o subject session |
| `attendance_date` | `date` | Not Null | Petsa ng sesyon (YYYY-MM-DD) |
| `status` | `varchar` | `'present'`, `'late'`, `'absent'`, `'excused'` | Attendance status |
| `recording_method` | `varchar(20)` | `CHECK IN ('Manual', 'RFID', 'System')` | Paraan ng pag-record |
| `time_in` | `time` | e.g. `07:45:00` | Oras ng tap |
| `device_id` | `varchar(64)` | e.g. `MOBILE_NFC`, `HARDWARE_ESP32` | Pinagmulang reader hardware |
| `remarks` | `varchar` | Nullable | Opsyonal na tala o dahilan |

> [!IMPORTANT]
> **Unique Constraint:**
> May constraint na `uq_attendance_student_offering_date` sa `(student_id, subject_offering_id, attendance_date)`. 
> Pinipigilan nito ang kahit anong duplicate attendance record para sa iisang estudyante sa iisang subject sa iisang araw.

### C. Server-Side RPC Function: `record_rfid_attendance()`
Tinatanggap ng function na ito ang:
* `p_rfid_uid`: Hex UID ng card
* `p_subject_offering_id`: ID ng subject offering
* `p_scan_timestamp`: UTC timestamp ng tap
* `p_device_id`: `'MOBILE_NFC'` o `'HARDWARE_ESP32'`

Awtomatikong ginagawa ng RPC:
1. Holiday check laban sa `public.school_holidays`.
2. Student lookup gamit ang normalized uppercase `rfid_uid`.
3. Enrollment verification sa `public.student_enrollments`.
4. Cutoff grace period calculation (Present, Late, o Absent).
5. Idempotent check (kapag nag-tap ulit ang student).
6. Auto-Absent promotion (kung minarkahan ng System na absent pero humabol ang estudyante at nag-tap, mapo-promote siya sa Late o Present).

---

## 3. Sagot sa Edge Scenarios

### Scenario A: Paano kapag nag-tap ulit ang estudyante na may attendance na?
* **Database Behavior:** Hinding-hindi magkakaroon ng duplicate record. Dahil sa `uq_attendance_student_offering_date`, hindi magpapasok ng bagong row.
* **RPC & Engine Logic:**
  - Nagbabalik ito ng outcome code: `IDEMPOTENT_ALREADY_RECORDED`.
  - Pinapanatili ang naunang status (hal. Present) at orihinal na `time_in`. Hindi ito mabubura o mapapalitan.
* **UI Feedback:**
  - Nagpapakita ang app ng warning notice sa teacher:
    > *"Attendance Already Recorded: [Pangalan ng Estudyante] was already marked PRESENT at 07:45 AM."*

### Scenario B: Paano kapag ang RFID card ay gamit na ng ibang estudyante?
* **Database Behavior:** May unique index na `uq_student_profiles_rfid_uid`. Hindi papayag ang database na dalawang estudyante ang may parehong card.
* **UI Feedback:**
  - Walang "Transfer Card" dialog (alinsunod sa inyong kagustuhan upang maiwasan ang maling pag-agaw ng card).
  - Agad magpapakita ng babala:
    > *"Card Already Registered: This RFID card is already assigned to [Pangalan ng May-ari]."*
  - Hindi itutuloy ang pag-link at mananatiling protektado ang card ng orihinal na may-ari.

### Scenario C: Paano kapag nag-tap ang estudyante gamit ang Apple Pay / Google Wallet sa Phone?
* Ang mga smartphone virtual wallets ay naglalabas ng randomized 4-byte UID na nagsisimula sa `0x08` (alinsunod sa ISO14443-3 Section 6.5.3.1).
* Naaamoy ito ng ating `PhoneNfcService`:
  - Nagbibigay ng madiin na haptic feedback (vibration).
  - Naglalabas ng notice: *"Smartphone virtual wallet detected. Students must tap their physical school RFID card."*

---

## 4. Offline Sync Architecture (Drift SQLite)

Kahit mawalan ng internet connection ang phone ni teacher habang nasa classroom:
1. **Lokal na Pagtatala:**
   - Binabasa ng repository ang lokal na kopya ng roster sa **Drift SQLite** (`app_database.dart`).
   - Sinusuri ang cutoffs at schedule nang lokal.
   - Ini-istore ang record sa `LocalAttendanceRecords` na may `syncStatus = 'pending'`.
2. **Offline Queue:**
   - Ipinapasok ang scan payload sa `OfflineSyncQueue` na may action `record_rfid_attendance`.
3. **Awtomatikong Pag-Sync:**
   - Sa sandaling magkaroon muli ng koneksyon sa internet, tinatawag ng repository ang `syncOfflineAttendanceQueue()`.
   - Isa-isang ipapasa sa Supabase ang mga naipong scans gamit ang eksaktong oras ng kanilang aktwal na tap.

---

## 5. Gabay sa Pagsubok sa Android Phone (Step-by-Step)

### A. Pag-Link ng RFID Card
1. Buksan ang **ClassRealm app** sa inyong Android phone (naka-on dapat ang NFC sa phone settings).
2. Mag-login bilang Teacher at pumunta sa **Attendance Workspace**.
3. Piliin ang inyong Subject at Section.
4. Sa roster table, hanapin ang estudyante at pindutin ang **`+ Link RFID`**.
5. Ang pindutan ay magiging kulay asul: **`Tap RFID Card (X)`**.
6. Idikit ang RFID card sa likod ng phone.
7. Magba-vibrate ang phone at lalabas ang berdeng kumpirmasyon:
   > *"RFID Card Linked: Linked to [Pangalan ng Estudyante]."*
8. Agad na magiging green/teal badge na may contactless chip icon ang tapat ng estudyante.
9. **I-check sa Supabase Table Editor:** Sa table na `student_profiles`, makikitang may laman na ang column na `rfid_uid` para sa estudyanteng iyon!

### B. Pagkuha ng Attendance Gamit ang Phone NFC
1. Sa parehong screen (Attendance Workspace), siguraduhing nasa **Take Attendance** view.
2. Sabihan ang estudyante na idikit ang kanyang RFID card sa likod ng phone ng guro.
3. Agad na mamamarkahan ang estudyante bilang **Present** (o Late depende sa oras).
4. Sa column ng **METHOD**, makikita ang teal badge na **`RFID`**.
5. Sa database, ang naitala ay `recording_method = 'RFID'` at `device_id = 'MOBILE_NFC'`.

---

## 6. Hardware Reader: Standalone ESP32 Door Scanner

Kung gagamitin ang nakalaang ESP32 scanner sa pinto ng silid-aralan:
1. **Kable at Wiring (Method 2 Off-Board Female-to-Male):**
   - RC522 3.3V $\rightarrow$ ESP32 3V3
   - RC522 RST $\rightarrow$ ESP32 GPIO 4
   - RC522 GND $\rightarrow$ ESP32 GND
   - RC522 MISO $\rightarrow$ ESP32 GPIO 19
   - RC522 MOSI $\rightarrow$ ESP32 GPIO 23
   - RC522 SCK $\rightarrow$ ESP32 GPIO 18
   - RC522 SDA/SS $\rightarrow$ ESP32 GPIO 5
2. **Koneksyon sa Supabase:**
   - Kumokonekta ang ESP32 sa school Wi-Fi at tumatawag sa Supabase HTTPS REST endpoint:
     `POST /rest/v1/rpc/record_rfid_attendance`
   - Ipinapasa nito:
     ```json
     {
       "p_rfid_uid": "04A1B2C3",
       "p_subject_offering_id": "YOUR_OFFERING_UUID",
       "p_scan_timestamp": "2026-11-04T07:45:00Z",
       "p_device_id": "HARDWARE_ESP32"
     }
     ```
3. **Live Sync sa Phone ng Guro:**
   - Naka-subscribe ang `teacher_attendance_tab.dart` sa **Supabase Realtime Postgres Changes** sa `attendance_records`.
   - Kapag nag-tap ang estudyante sa ESP32 sa may pintuan, **kusa at real-time na lilitaw ang Present mark sa screen ng guro** nang hindi kailangang mag-refresh!

---

## 7. Talaan ng mga Binagong Files para sa Proyekto

1. [`lib/features/teacher/sub_features/attendance/widgets/attendance_roster_table.dart`](file:///c:/Users/Admin/AndroidStudioProjects/class_realm01/lib/features/teacher/sub_features/attendance/widgets/attendance_roster_table.dart):
   - Tinanggal ang sticky/pinned column split para sa seamless single-table layout.
   - Pinaliit ang student name width sa 145px upang kumasya ang lahat ng columns.
   - Pinalitan ang progress indicators ng `LoadingAnimationWidget.staggeredDotsWave`.
2. [`lib/core/services/phone_nfc_service.dart`](file:///c:/Users/Admin/AndroidStudioProjects/class_realm01/lib/core/services/phone_nfc_service.dart):
   - Nagdagdag ng 3-second debounce cooldown per UID laban sa rapid duplicate scans.
   - Nagdagdag ng detection laban sa virtual Apple Pay / Google Wallet dynamic cards.
3. [`lib/features/teacher/sub_features/attendance/widgets/teacher_attendance_tab.dart`](file:///c:/Users/Admin/AndroidStudioProjects/class_realm01/lib/features/teacher/sub_features/attendance/widgets/teacher_attendance_tab.dart):
   - Inalis ang hex card codes sa user notifications (pangalan na lang ng estudyante ang ipinapakita).
   - Inalis ang transfer card confirmation dialog.
   - Pinanatiling laging buhay ang NFC session pagkatapos magsara ng dialogs.
4. [`lib/shared/widgets/modals/rfid_assignment_modal.dart`](file:///c:/Users/Admin/AndroidStudioProjects/class_realm01/lib/shared/widgets/modals/rfid_assignment_modal.dart):
   - Hinarang ang pag-reassign ng card na pag-aari na ng ibang estudyante.
5. **Supabase Database (Cloud Postgres):**
   - Na-apply ang haligi na `rfid_uid` sa `student_profiles`.
   - Na-apply ang haligi na `recording_method`, `time_in`, at `device_id` sa `attendance_records`.
   - Na-deploy ang RPC `record_rfid_attendance()`.
