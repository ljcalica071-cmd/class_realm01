# ClassRealm Tech Stack Documentation

This document serves as the official reference for the technologies and architecture used in the ClassRealm System.

## 1. Frontend & Backend Framework
* **Flutter + Dart**
  * **Platforms:** Web (for Admin and Teacher portal) and Mobile App (for Student and Parent).
  * **Purpose:** Single codebase for a seamless and responsive user interface across all target devices.

## 2. Authentication
* **Firebase Authentication**
  * **Purpose:** Handles secure user login, registration, password management, and session handling across the Web and Mobile apps.

## 3. Main Database (Cloud)
* **Supabase**
  * **Purpose:** The central, online PostgreSQL database.
  * **Usage:** Stores all master records including user profiles, student information, class schedules, enrolled subjects, and finalized attendance records. Serves as the ultimate source of truth when the system is online.

## 4. Hardware (IoT)
* **ESP32 Microcontroller**
* **RFID Scanner Module**
* **RFID Tags (for students)**
  * **Purpose:** Portable hardware used by the teacher for scanning student IDs in the classroom. Capable of communicating over a local Wi-Fi network (hotspot) even without internet access.

## 5. Local Storage / Offline Architecture
* **Docker + Local SQL Server (or XAMPP + MySQL)**
  * **Purpose:** Acts as the "Edge Server" or "Tagasalo" for offline attendance tracking.
  * **How it works:** 
    1. The Teacher opens a Local Hotspot on their laptop.
    2. The ESP32 connects to this hotspot and transmits RFID scans.
    3. The Local Docker/XAMPP server running on the laptop receives and saves the logs securely in a local SQL database.
    4. The Flutter Web App reads from this local database to show real-time attendance to the teacher.
    5. Once the laptop detects an active internet connection, the system automatically pushes/syncs the saved local attendance records up to the Supabase Cloud.

## 6. Lightweight Browser Caching
* **Hive (Flutter Package)**
  * **Purpose:** Used strictly for minor, fast key-value caching inside the Flutter App (e.g., saving user theme preferences, "Remember Me" login tokens, and UI states). Not used for heavy relational data.
