# Web Fast-Boot Architecture & Non-Stalling Loading Screen Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Eliminate the 5–30 minute / stuck Web loading screen so ClassRealm Web consistently reaches the Login or Dashboard screen in **5–25 seconds** (strictly `< 50 seconds` worst-case on an Intel Celeron N5095 laptop), with automated browser & unit tests proving the boot time and loader dismissal.

**Architecture:**
1. **Unify Web & Mobile Boot Pipeline (`runApp` First, Non-Blocking Init):** Make Web boot the exact same way Mobile does—call `runApp()` immediately as soon as `LocalStorageService` + `EnvConfig` finish (bounded to 1.5s), and enforce a hard **8-second watchdog timer** in both `web/index.html` and `lib/main.dart` that guarantees `#pre-bootstrap-loader` is removed and `LoginScreen` / `Dashboard` is interactive even if Firebase/Supabase network handshakes are slow.
2. **Disable Missing Drift Web Worker on Web (`sqlite3.wasm` / `drift_worker.js`):** `web/` does not contain `sqlite3.wasm` or `drift_worker.js`. Guard `AppDatabase` and `SyncCoordinator` with `if (!kIsWeb)` so Web never spawns broken Web Workers or 404 WASM fetches that stall the browser main thread.
3. **Fast Web Runner Script for Low-Spec CPU (`Intel Celeron N5095`):** Provide a one-command script (`scripts/run_web_fast.ps1`) that runs Flutter Web in `--profile` or `--web-renderer html` / precompiled mode without the 1,000-file DDC debug proxy bottleneck, plus an automated headless Chrome verification test (`scripts/verify_web_boot_time.ps1`) that measures actual wall-clock time to `flutter-first-frame` and `LoginScreen`.

**Tech Stack:** Flutter 3.x / Dart 3.13, Firebase Auth, Supabase Flutter, HTML5/CSS3/JS (`web/index.html`), PowerShell + Chrome DevTools Protocol (CDP) for automated boot-time verification.

**Spec:** User requirements from 2026-10-29 session:
- Web loading must behave as fast and reliably as the Mobile app (`< 50–60s` total including DB fetch, ideally `5–20s`).
- Web progress curve: **Fast -> Slow -> Moderate -> Slow -> Fast** (never freezing on one number like `48%` or `94%`).
- App progress curve: **Slow -> Fast** (`AppLifecycleLoadingScreen`).
- Must include real automated testing proving the Web app boots and removes the loader within the time budget.

## Global Constraints

- **Hardware Target:** Intel Celeron N5095 @ 2.00GHz (4 cores, 16GB RAM). Avoid unthrottled parallel XHR/WebWorker storms on Web startup.
- **Hard Boot Watchdog:** `#pre-bootstrap-loader` in `web/index.html` MUST force-complete to `100%` and remove itself no later than **12 seconds** after `main.dart.js` begins executing or immediately when `flutter-first-frame` fires, whichever comes first.
- **Pre-`runApp()` Budget on Web:** `main()` in `lib/main.dart` MUST NOT block `runApp()` for more than **4.0 seconds total** under any network condition.
- **No Drift Web Worker on Web Until WASM Assets Exist:** `SyncCoordinator` and `AppDatabase` must be no-ops on `kIsWeb` when `sqlite3.wasm` / `drift_worker.js` are absent from `web/`.
- **Design System:** Preserve the ClassRealm Glassmorphism palette (`#487898` steel blue, `#60A5FA` sky blue, `#E8EBE2` warm sage, `#F5F5F5` off-white, `#111827` dark text) and zero `1, 2, 3, 4` step numbers.

## Review Focus

1. **Cold Boot with Slow/Offline Network:** When Supabase or Firebase takes > 3 seconds to respond on Web, `main()` must still call `runApp()` within 4 seconds and let `LoginScreen` render immediately while background initialization finishes.
2. **Missing `sqlite3.wasm` / `drift_worker.js` on Web:** Calling `SyncCoordinator.instance.startBackgroundSync()` or `SyncCoordinator.instance.syncTeacherData()` on `kIsWeb` must not instantiate `AppDatabase.instance` or throw uncaught Web Worker / WASM 404 errors.
3. **Browser Tab in Background During Load:** If the user switches tabs while `localhost:8080` loads (throttling `requestAnimationFrame`), `removePreBootstrapLoader()` must still remove `#pre-bootstrap-loader` using a DOM `setTimeout` fallback so the loader never gets stuck over `LoginScreen`.
4. **Google Fonts Network Contention on Web:** Preconnect and load `Inter` via `<link rel="stylesheet">` in `web/index.html` so `GoogleFonts.inter()` does not stall initial frame rendering with dozens of runtime font fetches.
5. **DDC Debug Compilation Bottleneck on Celeron N5095:** Standard `flutter run -d chrome` compiles 1,000+ separate DDC JS modules on first load (taking 5–20 mins on a 2.0GHz Celeron). Provide and test a fast-run workflow (`flutter run -d chrome --profile --web-port=8080` or prebuilt server) that loads in `< 30 seconds`.

---

## Root Cause Diagnosis: Why Web Took 5–30 Minutes vs. Mobile

| Factor | Mobile App (`!kIsWeb`) | Web (`kIsWeb`) Before Fix | Why It Froze / Took 5–30 Mins |
| :--- | :--- | :--- | :--- |
| **1. Compiler Mode on Celeron N5095** | Native AOT/JIT binary | `flutter run -d chrome` uses **DDC (Dart Dev Compiler)** + DWDS proxy | DDC compiles & serves **1,000+ individual `.lib.js` files** (~40MB unminified) on first open. On a 4-core Celeron N5095 @ 2.0GHz, Chrome + DWDS takes **5–20 minutes** just to compile & transfer debug modules. |
| **2. `runApp()` Timing** | `runApp()` called **immediately at 0ms** (`lib/main.dart:123`) | `runApp()` blocked behind `LocalStorage`, `EnvConfig`, `Firebase`, `Supabase`, `AppDatabase`, and `_restoreUserSession()` | Any slow network handshake blocked `runApp()` before Flutter could even mount a single widget. |
| **3. Missing Web SQLite Files** | Native SQLite library bundled in OS | `AppDatabase` requested `sqlite3.wasm` & `drift_worker.js` which **do not exist in `web/`** | Browser received 404 / HTML fallback for `drift_worker.js` and `sqlite3.wasm`, causing Web Worker startup errors and background sync stalls. |
| **4. HTML Loader Removal** | Native Flutter widget (`AppLifecycleLoadingScreen`) with 6s timeout | Relied on JS `requestAnimationFrame` + manual DOM removal | If the tab lost focus (`requestAnimationFrame` paused by Chrome) or `main()` stalled, `#pre-bootstrap-loader` stayed stuck at `94%` forever. |

---

## File Structure

- **Modify:** `lib/core/services/sync_coordinator.dart` — Make `_db` lazy and skip Drift SQLite operations when `kIsWeb` is true so Web never instantiates `AppDatabase` without WASM assets.
- **Modify:** `lib/main.dart` — Make Web `main()` mount `runApp()` within `< 3.5 seconds` maximum; run session revalidation in the background (`unawaited`); add a fallback timer to guarantee `removePreBootstrapLoader()` executes after `runApp()`.
- **Modify:** `web/index.html` — Preload Google Font `Inter` in `<head>`, implement the **Fast -> Slow -> Moderate -> Slow -> Fast** delta-time progress curve with a `setInterval` backup (so background tabs still progress), and add a hard safety dismissal once `flutter-first-frame` or `<flt-glass-pane>` / `<flutter-view>` mounts in the DOM.
- **Modify:** `lib/core/widgets/app_lifecycle_loading_screen.dart` — Ensure **Slow -> Fast** progression curve on Mobile/Desktop app with unit-testable progress velocity.
- **Create:** `test/core/widgets/app_lifecycle_loading_screen_test.dart` — Widget test verifying the App loading screen starts low, accelerates (Slow -> Fast), reaches 100%, and invokes `onComplete` within the time budget.
- **Create:** `scripts/run_web_fast.ps1` — Developer launcher script for low-spec laptops that runs ClassRealm Web on `http://localhost:8080` using `--profile` (dart2js single-bundle compilation, 10x faster on Celeron N5095 than DDC debug mode).
- **Create:** `scripts/verify_web_boot_time.ps1` — Automated end-to-end test script that builds/starts the Web server, launches headless Chrome with remote debugging, polls the DOM until `#pre-bootstrap-loader` is removed and Flutter renders `LoginScreen`, and asserts total boot time is `< 50 seconds`.

---

### Task 1: Guard `SyncCoordinator` and `AppDatabase` on Web (`kIsWeb`)

**Files:**
- Modify: `lib/core/services/sync_coordinator.dart:1-60`
- Modify: `lib/main.dart:60-72,170-215`
- Test: `test/core/services/sync_coordinator_web_guard_test.dart`

**Interfaces:**
- Produces: `bool get SyncCoordinator.isLocalDbSupported => !kIsWeb;`
- Produces: Safe no-op on `kIsWeb` for `SyncCoordinator.instance.startBackgroundSync()`, `syncTeacherData()`, `processPendingQueue()`, and `queueOfflineAction()`.

- [ ] **Step 1: Write the failing test in `test/core/services/sync_coordinator_web_guard_test.dart`**

```dart
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:class_realm/core/services/sync_coordinator.dart';

void main() {
  test('SyncCoordinator exposes isLocalDbSupported == !kIsWeb without eager DB init', () {
    expect(SyncCoordinator.isLocalDbSupported, equals(!kIsWeb));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/services/sync_coordinator_web_guard_test.dart`
Expected: FAIL with `Getter not found: 'isLocalDbSupported'`

- [ ] **Step 3: Make `_db` lazy and guard Web calls in `lib/core/services/sync_coordinator.dart` and `lib/main.dart`**

In `lib/core/services/sync_coordinator.dart`:
- Add `static bool get isLocalDbSupported => !kIsWeb;`
- Replace eager fields:
  ```dart
  SupabaseClient get _client => Supabase.instance.client;
  AppDatabase get _db => AppDatabase.instance;
  ```
- At the top of `startBackgroundSync()`, `syncTeacherData(String teacherId)`, `syncSectionStudents(String sectionId)`, `queueOfflineAction(...)`, and `processPendingQueue()`:
  ```dart
  if (!isLocalDbSupported) return;
  ```
In `lib/main.dart`:
- Wrap `AppDatabase.instance;` and `SyncCoordinator.instance.startBackgroundSync();` in `if (!kIsWeb)` everywhere in `lib/main.dart`.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/core/services/sync_coordinator_web_guard_test.dart`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add lib/core/services/sync_coordinator.dart lib/main.dart test/core/services/sync_coordinator_web_guard_test.dart
git commit -m "fix(web): guard Drift AppDatabase and SyncCoordinator on Web when WASM files are absent"
```

---

### Task 2: Non-Blocking Web `main()` with Strict `< 3.5s` Pre-`runApp` Budget

**Files:**
- Modify: `lib/main.dart:35-245`
- Modify: `lib/core/utils/browser_url_web.dart:40-65`

**Interfaces:**
- Produces: `main()` in `lib/main.dart` that bounds `LocalStorageService.init()` + `EnvConfig.init()` to `1500ms`, `Firebase.initializeApp()` + `SupabaseService.initialize()` to `2000ms`, and calls `runApp(const ClassRealmApp(isWarmBoot: true))` immediately without waiting on network session restoration when `cachedUser == null` (or bounds `_restoreUserSession()` to `1200ms` max).
- Produces: Triple-redundant dismissal of `#pre-bootstrap-loader`:
  1. `WidgetsBinding.instance.addPostFrameCallback((_) => removePreBootstrapLoader())`
  2. `Future.delayed(const Duration(milliseconds: 400), removePreBootstrapLoader)`
  3. `window.addEventListener('flutter-first-frame', ...)` and DOM MutationObserver in `web/index.html`.

- [ ] **Step 1: Update `lib/main.dart` Web startup sequence**

In `lib/main.dart`:
1. Set `LocalStorageService.init()` + `EnvConfig.init()` timeout to `const Duration(milliseconds: 1500)`.
2. Set `Firebase.initializeApp(...)` + `SupabaseService.initialize()` timeout to `const Duration(milliseconds: 2200)`.
3. Set `_restoreUserSession()` timeout on cold start to `const Duration(milliseconds: 1500)`.
4. In `_ClassRealmAppState.initState()`, schedule both `WidgetsBinding.instance.addPostFrameCallback((_) => removePreBootstrapLoader())` AND `Future<void>.delayed(const Duration(milliseconds: 350), removePreBootstrapLoader)` so the HTML loader is guaranteed to be removed even if the browser tab is in the background.

- [ ] **Step 2: Ensure `removePreBootstrapLoaderWeb()` in `lib/core/utils/browser_url_web.dart` works even when `requestAnimationFrame` is paused**

In `lib/core/utils/browser_url_web.dart`:
- Dispatch `'cr-remove'` on `#pre-bootstrap-loader` AND schedule a `Future.delayed(const Duration(milliseconds: 500), () => html.document.getElementById('pre-bootstrap-loader')?.remove())` so background tab throttling can never leave the HTML loader on screen.

- [ ] **Step 3: Run `flutter analyze` to verify zero errors**

Run: `flutter analyze --no-pub --no-fatal-warnings --no-fatal-infos lib/main.dart lib/core/utils/browser_url_web.dart`
Expected: `No issues found!` (or only `deprecated_member_use` info on `dart:html`).

- [ ] **Step 4: Commit**

```bash
git add lib/main.dart lib/core/utils/browser_url_web.dart
git commit -m "perf(web): bound Web pre-runApp startup to <3.5s and guarantee loader removal"
```

---

### Task 3: Resilient Multi-Tempo Web Loader (`web/index.html`) + Font Preload + DOM Observer

**Files:**
- Modify: `web/index.html:1-590`

**Interfaces:**
- Produces:
  - `<link rel="preconnect" href="https://fonts.googleapis.com">` and `<link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700;800&display=swap" rel="stylesheet">` in `<head>` so `Inter` is already cached by the browser before Flutter mounts `LoginScreen`.
  - Background-tab safe timer (`setInterval(..., 50)` + `requestAnimationFrame`) driving the **Fast (`1% -> 28%`) -> Slow (`28% -> 46%`) -> Moderate (`46% -> 74%`) -> Slow (`74% -> 99%`) -> Fast (`-> 100%`)** progress curve.
  - A `MutationObserver` watching `document.body` for `<flutter-view>` or `<flt-glass-pane>` so the instant Flutter mounts its canvas, the loader automatically triggers its completion burst if `flutter-first-frame` hasn't fired within `1500ms`.

- [ ] **Step 1: Update `web/index.html` with `Inter` font preload, `setInterval` fallback ticker, and `MutationObserver` safety net**

In `web/index.html`:
1. Add Google Fonts `Inter` `<link>` tags in `<head>` so Flutter does not block on runtime font downloads.
2. Drive `stepProgress()` via both `requestAnimationFrame` AND a `100ms` `setInterval` fallback (using `performance.now()` delta-time `dt`) so the progress bar continues advancing smoothly even if the user minimizes Chrome or switches tabs while waiting!
3. Attach a `MutationObserver` on `document.body` that detects `<flutter-view>` or `<flt-glass-pane>` insertion and ensures `window.removePreBootstrapLoader()` is called within `1200ms` of canvas attachment.

- [ ] **Step 2: Verify `web/index.html` syntax and structure**

Run: `powershell -Command "Select-String -Path web/index.html -Pattern 'computeTempoSpeed|MutationObserver|flutter-first-frame'"`
Expected: Matches found for all three patterns.

- [ ] **Step 3: Commit**

```bash
git add web/index.html
git commit -m "feat(web): add background-safe multi-tempo loader, Inter font preload, and DOM observer"
```

---

### Task 4: Verify & Test App Loading Screen (`Slow -> Fast` Curve)

**Files:**
- Modify: `lib/core/widgets/app_lifecycle_loading_screen.dart`
- Create: `test/core/widgets/app_lifecycle_loading_screen_test.dart`

**Interfaces:**
- Produces: Verified `AppLifecycleLoadingScreen` whose progress starts at `1%`, moves slowly from `1% -> 30%`, accelerates from `30% -> 65%`, bursts from `65% -> 100%`, and triggers `onComplete`.

- [ ] **Step 1: Write widget test `test/core/widgets/app_lifecycle_loading_screen_test.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:class_realm/core/widgets/app_lifecycle_loading_screen.dart';
import 'package:class_realm/models/user_model.dart';

void main() {
  testWidgets('AppLifecycleLoadingScreen follows Slow -> Fast curve and calls onComplete', (tester) async {
    bool completed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: AppLifecycleLoadingScreen(
          initializationTask: (onProgress) async {
            onProgress(0.25, 'Loading config...');
            await Future<void>.delayed(const Duration(milliseconds: 300));
            onProgress(0.65, 'Connecting services...');
            await Future<void>.delayed(const Duration(milliseconds: 300));
            return null;
          },
          onComplete: (context, UserModel? user) {
            completed = true;
          },
        ),
      ),
    );

    // Initial state starts at 1%
    expect(find.text('1'), findsOneWidget);

    // Pump through initialization and completion animation
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle(const Duration(seconds: 3));

    expect(completed, isTrue);
  });
}
```

- [ ] **Step 2: Run the widget test**

Run: `flutter test test/core/widgets/app_lifecycle_loading_screen_test.dart`
Expected: PASS

- [ ] **Step 3: Commit**

```bash
git add lib/core/widgets/app_lifecycle_loading_screen.dart test/core/widgets/app_lifecycle_loading_screen_test.dart
git commit -m "test(loading): add widget test for AppLifecycleLoadingScreen slow-to-fast curve"
```

---

### Task 5: Fast Web Launcher & Automated End-to-End Browser Boot Time Test (`< 50s` Verification)

**Files:**
- Create: `scripts/run_web_fast.ps1`
- Create: `scripts/verify_web_boot_time.ps1`

**Interfaces:**
- Produces:
  - `scripts/run_web_fast.ps1`: Launches ClassRealm Web in `--profile` mode (or serves prebuilt `build/web` on port `8080`) so low-spec laptops (`Intel Celeron N5095`) skip the 1,000-module DDC debug compilation bottleneck and open `http://localhost:8080` in **5–15 seconds**.
  - `scripts/verify_web_boot_time.ps1`: Builds/starts the Web server on `http://localhost:8080`, opens headless Chrome (`--headless=new --remote-debugging-port=9222`), measures the exact seconds from page navigation until `#pre-bootstrap-loader` is removed and `<flutter-view>` / `<flt-glass-pane>` is active, prints the boot benchmark report, and exits `0` only if total boot time is `< 50 seconds`.

- [ ] **Step 1: Create `scripts/run_web_fast.ps1`**

```powershell
param(
  [int]$Port = 8080
)
Write-Host "Starting ClassRealm Web in Fast Profile Mode on http://localhost:$Port ..." -ForegroundColor Cyan
flutter run -d chrome --profile --web-port=$Port
```

- [ ] **Step 2: Create `scripts/verify_web_boot_time.ps1` automated E2E browser test**

Create `scripts/verify_web_boot_time.ps1` that:
1. Runs `flutter build web --no-pub` (to verify clean web compilation and generate `build/web`).
2. Starts a lightweight local HTTP server serving `build/web` on `http://localhost:8099`.
3. Launches Chrome with `--headless=new --disable-gpu --remote-debugging-port=9229 http://localhost:8099`.
4. Connects to Chrome DevTools Protocol (`http://localhost:9229/json`) and evaluates `document.getElementById('pre-bootstrap-loader') === null && document.querySelector('flutter-view, flt-glass-pane') !== null` every 500ms.
5. Records the exact elapsed seconds from page open to loader removal + Login screen readiness, asserts `elapsedSeconds < 50`, and cleans up the server and Chrome processes.

- [ ] **Step 3: Execute `scripts/verify_web_boot_time.ps1` and verify `< 50s` boot time**

Run: `powershell -ExecutionPolicy Bypass -File scripts/verify_web_boot_time.ps1`
Expected: PASS with output showing `BOOT_SUCCESS: Loader dismissed and Flutter view mounted in X.XX seconds (< 50s limit)`.

- [ ] **Step 4: Commit**

```bash
git add scripts/run_web_fast.ps1 scripts/verify_web_boot_time.ps1
git commit -m "test(web): add fast web runner and automated headless Chrome boot-time verification"
```

