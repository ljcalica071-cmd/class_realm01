# Unified RFID Attendance & Teacher Phone NFC Offline Engine Plan

> **Goal:** Magkaroon si Teacher ng 100% maaasahang Attendance Taking at RFID Card Registration gamit ang Phone NFC, na gumagana nang walang internet (Drift SQLite local cache) at awtomatikong nag-si-sync sa Supabase.
> 
> **Pangunahing Batas:** Ang recording method ay TATLO LAMANG sa buong system:
> 1. `RFID` (Iisa lang ang tawag at column value sa ESP32 man o sa Phone NFC nag-tap!)
> 2. `Manual` (Kapag kinlik ni teacher sa screen gamit ang kamay)
> 3. `System` (Awtomatikong absent ng 11:59 PM system cron)

---

## 1. Paano Hinaharap ang mga Na-scan Nang RFID Cards?

Kapag ang card ng estudyante ay **na-scan na kanina** sa ESP32 man o sa Phone:

1. **Anti-Duplicate Protection:**
   - Protektado ang database via unique constraint `(student_id, subject_offering_id, attendance_date)`. Hindi kailanman magkakaroon ng dalawang row ang parehong estudyante sa parehong klase sa parehong araw.
2. **Instant Feedback sa Screen (Scenario 15):**
   - Kapag itinap ulit ang card ng batang recorded na kanina:
     - **Hindi ito magtatala ng panibagong attendance.**
     - Magpa-pop up ang Amber Warning Banner:  
       `"Already Recorded: [Pangalan ng Estudyante] was already marked PRESENT at [Oras ng Time-in]"`
     - Magbibigay ng distinct warning vibration/sound para alam agad ni teacher at student na nakatala na siya.
3. **Pagsasama ng ESP32 at Phone (Idempotent Merge - Scenario 23):**
   - Kung nag-tap ang bata sa ESP32 sa pintuan kanina, at itinap din offline sa phone ni teacher:
   - Pag-sync sa Supabase, kukunin ng database ang pinakaunang oras (`LEAST(time_in)`) upang pabor sa estudyante ang oras ng kanyang pagpasok. Walang error na lalabas.
4. **Time-Out / Dismissal (Scenario 18):**
   - Kung uwian na o tapos na ang klase at inilipat ni teacher ang mode sa **"Time-Out"**:
   - Ang tap ng card ay magtatala naman ng kanyang `time_out` (oras ng paglabas) nang hindi binubura ang kanyang `time_in`.

---

## 2. Arkitektura: Iisang RFID Method Lang

```
[ RC522 Door Scanner (ESP32) ] ──┐
                                 ├──► [ recording_method = 'RFID' ] ──► [ attendance_records ]
[ Teacher Phone NFC Scanner  ] ──┘
```

* **Sa Database:** `attendance_records.recording_method = 'RFID'`
* **Sa UI:** Parehong may badge na **`RFID`** (Emerald badge)
* **Sa Card Registry:** Parehong nagbabasa sa `student_profiles.rfid_uid`

---

## 3. Mga Hakbang sa Pagpapatupad

### Hakbang 1: Pag-extend sa Umiiral na Drift Local Tables
* Gamitin ang existing `LocalStudents`, `LocalEnrollments`, `LocalSchedules`, `LocalAttendanceCutoffs`, `LocalAttendanceRecords`, at `OfflineSyncQueue` sa `lib/data/datasources/local/tables.dart`.
* Tiyaking may `recordingMethod = 'RFID'` para offline pa lang ay naka-tag na bilang RFID.

### Hakbang 2: Pagpapahusay sa `PhoneNfcService`
* Palakasin ang umiiral na `lib/core/services/phone_nfc_service.dart`.
* Maglagay ng 4-second cooldown para hindi ma-double scan kapag nakadiin ang card sa likod ng phone.

### Hakbang 3: Pagbuo ng `RfidAttendanceEngine` (30 Edge Scenarios)
* Humahawak sa lahat ng logic (Online man o Offline):
  - Check unregistered card (Scenario 11 & 12)
  - Check cross-section enrollment (Scenario 13)
  - Check grace period at late cutoffs (Scenario 17)
  - Check schedule at holiday (Scenario 16)
  - Check already-recorded cards (Scenario 15)

### Hakbang 4: Offline-to-Online Background Sync Worker
* Kapag nagka-internet, awtomatikong ipinapadala sa Supabase:
  - Priority 1: Mga bagong rehistrong RFID card.
  - Priority 2: Mga naipong offline RFID attendance scans gamit ang orihinal na oras ng pag-tap.

### Hakbang 5: Teacher Attendance UI & Live Hero Modal
* I-integrate sa umiiral na `TeacherAttendanceTab`.
* Malaking Hero Card na nagpapakita ng pangalan, status (`PRESENT` / `LATE` / `ALREADY RECORDED`), at 1-tap manual overrides.

