---
name: emulator
description: "Manage Android emulator lifecycle and app deployment, and navigate the running app via Dart MCP. Run/close emulator, build and install the app, check logcat, attach to Flutter to read the widget tree and drive taps. Use when the user asks to start emulator, stop emulator, run app, build APK, deploy to emulator, check logs, logcat, attach flutter, inspect widget tree, navigate app, or tap a widget."
when_to_use: "run emulator, start emulator, close emulator, stop emulator, kill emulator, build and run, deploy app, install apk, logcat, check logs, android logs, attach flutter, dart mcp, widget tree, navigate app, tap widget, inspect ui, запусти емулятор, зупини емулятор, логи, логкат, навігація по застосунку"
---

# Android Emulator

Manage the Android emulator, build and deploy the app, and inspect logs.

## Environment

`ANDROID_HOME` must be set in the shell. Tools live at `$ANDROID_HOME/emulator/emulator` and `$ANDROID_HOME/platform-tools/adb`.

List installed AVDs: `$ANDROID_HOME/emulator/emulator -list-avds`. Ask the user which to start if more than one exists.

**Java requirement**: Gradle commands must run with a `JAVA_HOME` pointing at a JDK compatible with this project. Do not hardcode a Java version, and do not change the developer's system default Java or global Flutter config; other projects may use another Java version.

```bash
JAVA_HOME=<PROJECT_JAVA_HOME> ./gradlew <task>
```

If `PROJECT_JAVA_HOME` is unknown, ask the user for the project-compatible JDK path. <!-- TODO: record the project's required JDK path/version here once known. -->

## Commands

### Run Emulator

Start the emulator in the background. If the user specifies a device name, use it; otherwise list AVDs and ask which to start.

```bash
$ANDROID_HOME/emulator/emulator -avd <AVD_NAME> -no-snapshot-load -gpu host &
```

`-gpu host` uses the host machine's GPU for hardware-accelerated rendering, which improves emulator speed and stability. Drop it only if the host has no usable GPU (e.g. some headless CI) — fall back to `-gpu swiftshader_indirect` there.

Wait for boot to complete:
```bash
$ANDROID_HOME/platform-tools/adb wait-for-device
$ANDROID_HOME/platform-tools/adb shell getprop sys.boot_completed | grep -q 1
```

If the emulator is already running (`adb devices` shows an emulator), tell the user and skip.

### Close Emulator

Kill the running emulator:
```bash
$ANDROID_HOME/platform-tools/adb emu kill
```

If multiple emulators are running, list them with `adb devices` and ask which to kill, or kill all if the user says so.

### Build and Run App

For a standalone Flutter app, the simplest path is the Flutter CLI, which builds, installs, and launches in one step:
```bash
flutter run -d <DEVICE_ID>
```

If the user specifically wants a Gradle build and manual install:

**Build debug APK via Gradle** from the `android/` directory:
```bash
JAVA_HOME=<PROJECT_JAVA_HOME> ./gradlew assembleDebug
```
The output APK is at `android/app/build/outputs/apk/debug/app-debug.apk`.

**Install and launch** (application id `ua.naiksoftware.morkvacrm`, launcher activity `ua.naiksoftware.morkvacrm.MainActivity`):
```bash
$ANDROID_HOME/platform-tools/adb install -r android/app/build/outputs/apk/debug/app-debug.apk
$ANDROID_HOME/platform-tools/adb shell am start -n ua.naiksoftware.morkvacrm/ua.naiksoftware.morkvacrm.MainActivity
```

If the user says "run app" or "build and run", prefer `flutter run` (or build then install and launch).
If the user says "just build", skip install.
If the user says "just install" or "just deploy", skip build and install the existing APK.

### Check Logcat

Show recent logs filtered to the app (resolve `ua.naiksoftware.morkvacrm` from the manifest):
```bash
$ANDROID_HOME/platform-tools/adb logcat --pid=$($ANDROID_HOME/platform-tools/adb shell pidof ua.naiksoftware.morkvacrm) -d -t 100
```

Common filters the user might request:

- **Crashes / exceptions:**
  ```bash
  $ANDROID_HOME/platform-tools/adb logcat *:E -d -t 200 | grep -i -E "exception|crash|fatal|ANR"
  ```

- **Flutter logs:**
  ```bash
  $ANDROID_HOME/platform-tools/adb logcat -d -t 200 | grep -i flutter
  ```

- **Live tail** (use interactive mode):
  ```bash
  $ANDROID_HOME/platform-tools/adb logcat --pid=$($ANDROID_HOME/platform-tools/adb shell pidof ua.naiksoftware.morkvacrm)
  ```

- **Clear and watch fresh:**
  ```bash
  $ANDROID_HOME/platform-tools/adb logcat -c
  $ANDROID_HOME/platform-tools/adb logcat --pid=$($ANDROID_HOME/platform-tools/adb shell pidof ua.naiksoftware.morkvacrm)
  ```

If the app is not running (`pidof` returns empty), fall back to filtering by a tag substring from the app's package name:
```bash
$ANDROID_HOME/platform-tools/adb logcat -d -t 200 | grep -i <APP_TAG>
```

### Attach to Flutter (Dart MCP)

Inspect the running Flutter UI through Dart MCP. Use this for navigation or state verification without screenshots.

**Prerequisites:**
- App installed and running in debug mode (see Build and Run above).
- `JAVA_HOME` for any Gradle-backed command must point to a project-compatible JDK for that command only.

**1. Start `flutter attach` in background** from the project root (where `pubspec.yaml` lives):
```bash
flutter attach -d <DEVICE_ID> --machine > /tmp/flutter_attach.log 2>&1 &
```

**2. Wait ~10s, read the DTD URI:**
```bash
grep -oE '"app.dtd"[^}]*"uri":"ws://[^"]*' /tmp/flutter_attach.log | grep -oE 'ws://[^"]*'
```

**3. Connect via Dart MCP:**
Pass the URI to `mcp__dart__connect_dart_tooling_daemon`.

**4. Inspect the widget tree:**
```
mcp__dart__get_widget_tree(summaryOnly: true)
```
Returns the tree with `textPreview`, `valueId`, and widget keys like `<'send_button'>`. Grep for the target widget.

**5. Tap a target:**
If the app includes the Flutter driver extension, prefer `mcp__dart__flutter_driver`. Otherwise tap via adb:

a. Dump UI to read bounds (Flutter exposes labels in `content-desc`):
```bash
adb -s <DEVICE_ID> shell uiautomator dump /sdcard/ui.xml
adb -s <DEVICE_ID> pull /sdcard/ui.xml /tmp/ui.xml
grep -oE 'content-desc="<LABEL>"[^/]*bounds="[^"]*"' /tmp/ui.xml
```
b. Compute the bounds center, then `adb shell input tap X Y`.

**6. Verify:** call `get_widget_tree` again. The tree shows the new screen state.

**Notes:**
- For a standard standalone Flutter app, `mcp__dart__launch_app` and `flutter run` both work. (If this project is ever restructured as an add-to-app module, native Gradle build + `flutter attach` is the reliable path instead.)
- Other Dart MCP calls worth knowing: `set_widget_selection_mode` + `get_selected_widget` (user picks a widget on screen), `hot_reload`, `hot_restart`.
- For pure-MCP taps, the codebase needs an `enableFlutterDriverExtension()` entrypoint (e.g. `lib/driver_main.dart`) launched with `--target=lib/driver_main.dart`.

## Important

- Always check `adb devices` before any operation to confirm emulator/device connectivity.
- If `adb` is not responding, try `adb kill-server && adb start-server`.
- Application id: `ua.naiksoftware.morkvacrm`; launcher activity: `ua.naiksoftware.morkvacrm.MainActivity` (defined in `android/app/build.gradle.kts` and `android/app/src/main/AndroidManifest.xml`).
- Gradle requires an explicit per-command `JAVA_HOME` pointing at a project-compatible JDK; do not assume or modify the user's default Java version.
- For release builds, use `assembleRelease` instead of `assembleDebug` (or `flutter build apk --release`).
