export const meta = {
  name: 'e2e',
  description: 'Drive the Flutter app on an Android device/emulator and report runtime UI bugs and errors',
  whenToUse:
    'Check something at runtime on Android — reproduce a UI bug, surface errors/crashes, or sanity-check current work on a screen. Pass what to check as args, e.g. /e2e "open the contacts list, check the search field layout".',
  phases: [
    { title: 'Setup', detail: 'Ensure a device is connected and the app is installed and running' },
    { title: 'Drive', detail: 'Attach Flutter, navigate the scenario, capture screenshots + widget tree + logs' },
    { title: 'Analyze', detail: 'Fan out: layout / runtime errors / logcat / network analyzers over captured artifacts' },
    { title: 'Report', detail: 'Synthesize a prioritized bug report' },
  ],
}

// ---------------------------------------------------------------------------
// What to check. Pass a free-form scenario as args (string or {scenario}).
// With no args, the workflow inspects whatever the running app shows now.
// ---------------------------------------------------------------------------
const scenario =
  typeof args === 'string' && args.trim()
    ? args.trim()
    : args && typeof args === 'object' && args.scenario
      ? String(args.scenario)
      : 'Inspect the current screen of the running app for UI bugs, layout issues, and runtime errors.'

// Project facts the agents need.
// TODO(MorkvaCRM): confirm the applicationId / launcher activity once the
// Android project is generated. Standard `flutter create` defaults are:
//   applicationId  -> com.example.morkvacrm   (check android/app/build.gradle)
//   launcher       -> .MainActivity           (check android/app/src/main/AndroidManifest.xml)
const APP_ID = 'com.example.morkvacrm' // TODO: verify in android/app/build.gradle(.kts)
const LAUNCH_ACTIVITY = `${APP_ID}/.MainActivity` // TODO: verify in AndroidManifest.xml
const PROJECT = `Project facts you MUST rely on:
- This is a standard Flutter app. The app package and launcher below are the expected defaults — VERIFY them before relying on them:
    App package (applicationId): ${APP_ID}   (read android/app/build.gradle or build.gradle.kts)
    Launcher activity:           ${LAUNCH_ACTIVITY}   (read android/app/src/main/AndroidManifest.xml; the MainActivity is usually package + .MainActivity)
- adb:      $ANDROID_HOME/platform-tools/adb
- emulator: $ANDROID_HOME/emulator/emulator   (list AVDs: emulator -list-avds)
- Prefer the standard Flutter toolchain. From the project root:
    Build + install + launch in one step:  flutter run -d <serial>   (or, to just build a debug APK: flutter build apk --debug -> build/app/outputs/flutter-apk/app-debug.apk)
    If you build the APK separately: adb install -r build/app/outputs/flutter-apk/app-debug.apk; adb shell am start -n ${LAUNCH_ACTIVITY}
- If the Dart MCP is available, mcp__dart__launch_app may work for a plain Flutter app; otherwise fall back to \`flutter run\` / \`flutter attach\`.
- flutter attach (from project root, to drive an already-running app): flutter attach -d <serial> --machine > <log> 2>&1 &  then parse the DTD ws:// uri:
    grep -oE '"app.dtd"[^}]*"uri":"ws://[^"]*' <log> | grep -oE 'ws://[^"]*'
  and connect with mcp__dart__connect_dart_tooling_daemon.
- If a flutter_driver / integration_test extension is wired up, mcp__dart__flutter_driver can drive taps directly. If it is NOT available, tap via uiautomator: adb shell uiautomator dump /sdcard/ui.xml; adb pull; find the element bounds (Flutter labels appear in content-desc); compute center; adb shell input tap X Y.
- Screenshot: adb -s <serial> exec-out screencap -p > <file>.png
- Logcat (app only): adb logcat --pid=$(adb shell pidof ${APP_ID}) -d -t 400`

// ---------------------------------------------------------------------------
// Schemas
// ---------------------------------------------------------------------------
const SETUP_SCHEMA = {
  type: 'object',
  additionalProperties: false,
  required: ['ready', 'deviceSerial', 'appRunning', 'artifactDir', 'notes'],
  properties: {
    ready: { type: 'boolean', description: 'true if a device is connected and the app is installed and running' },
    deviceSerial: { type: 'string', description: 'adb serial of the target device, or "" if none' },
    appRunning: { type: 'boolean' },
    built: { type: 'boolean', description: 'true if this run built/installed a fresh APK' },
    artifactDir: { type: 'string', description: 'absolute path of the created dir for screenshots and dumps' },
    notes: { type: 'string', description: 'what was done, and any blocker if ready=false' },
  },
}

const DRIVE_SCHEMA = {
  type: 'object',
  additionalProperties: false,
  required: ['stepsExecuted', 'artifacts', 'rawObservations', 'driveNotes'],
  properties: {
    stepsExecuted: {
      type: 'array',
      items: {
        type: 'object',
        additionalProperties: false,
        required: ['step', 'result'],
        properties: {
          step: { type: 'string' },
          screenshot: { type: 'string', description: 'absolute path of the screenshot captured for this step, if any' },
          result: { type: 'string' },
        },
      },
    },
    artifacts: {
      type: 'object',
      additionalProperties: false,
      required: ['screenshots', 'widgetTreeDump', 'logcatDump', 'runtimeErrorsDump'],
      properties: {
        screenshots: { type: 'array', items: { type: 'string' } },
        widgetTreeDump: { type: 'string', description: 'path to a text file holding the get_widget_tree output' },
        logcatDump: { type: 'string', description: 'path to a text file holding captured logcat' },
        runtimeErrorsDump: { type: 'string', description: 'path to a text file holding Dart runtime errors / app logs' },
        networkDump: { type: 'string', description: 'path to a network/console dump if captured, else ""' },
      },
    },
    rawObservations: { type: 'array', items: { type: 'string' }, description: 'plain things observed while driving' },
    driveNotes: { type: 'string' },
  },
}

const FINDINGS_SCHEMA = {
  type: 'object',
  additionalProperties: false,
  required: ['dimension', 'findings'],
  properties: {
    dimension: { type: 'string' },
    findings: {
      type: 'array',
      items: {
        type: 'object',
        additionalProperties: false,
        required: ['severity', 'title', 'evidence'],
        properties: {
          severity: { type: 'string', enum: ['critical', 'high', 'medium', 'low'] },
          title: { type: 'string' },
          evidence: { type: 'string', description: 'concrete evidence: file path, log line, widget id, or screenshot region' },
          location: { type: 'string', description: 'screen / widget / file, if known' },
        },
      },
    },
  },
}

// ---------------------------------------------------------------------------
// Phase 1 — Setup: one agent, no parallelism (single device).
// ---------------------------------------------------------------------------
phase('Setup')
log(`e2e: ${scenario}`)

const setup = await agent(
  `You are preparing an Android device to run end-to-end runtime checks of the MorkvaCRM Flutter app.

Scenario to check later: "${scenario}"

${PROJECT}

Do, in order:
1. Load the tools you need: ToolSearch "select:Bash". (Dart MCP is loaded by the Drive phase, not here.)
2. Run \`$ANDROID_HOME/platform-tools/adb devices\`. If no device/emulator is connected, list AVDs and boot one: \`$ANDROID_HOME/emulator/emulator -avd <name> -no-snapshot-load &\`, then \`adb wait-for-device\` and poll \`adb shell getprop sys.boot_completed\` until it returns 1. If there are several AVDs and none running, pick the first and note the choice.
3. Verify the real applicationId and launcher activity from android/app/build.gradle(.kts) and android/app/src/main/AndroidManifest.xml; if they differ from the assumed defaults in the project facts, use the real values for the rest of this run and note them.
4. Decide whether to (re)build. If the app (pidof <applicationId>) is already running and the scenario does NOT ask for fresh/built/deployed code, DO NOT rebuild — just reuse it. Otherwise build+install+launch per the project facts (prefer \`flutter run -d <serial>\`, or build the debug APK and install it). If the build fails, set ready=false and explain the blocker in notes — do not guess.
5. Launch the app if it is installed but not running, and wait until it is foregrounded.
6. Create an artifact dir for this run: \`mkdir -p "$PWD/.claude/e2e-artifacts/run-$(date +%Y%m%d-%H%M%S)"\` and capture its absolute path. (Use the shell's date; do not invent a timestamp.)

Return the result object. Set ready=false with a clear blocker in notes if you cannot get the app running.`,
  { label: 'setup-device', phase: 'Setup', schema: SETUP_SCHEMA },
)

if (!setup || !setup.ready) {
  return {
    status: 'blocked',
    scenario,
    blocker: setup ? setup.notes : 'setup agent failed to return',
    setup,
  }
}

// ---------------------------------------------------------------------------
// Phase 2 — Drive: one agent attaches and exercises the scenario, capturing
// every signal as a file in artifactDir. Only this phase touches the device.
// ---------------------------------------------------------------------------
phase('Drive')

const drive = await agent(
  `You are driving the running MorkvaCRM Flutter app on Android to exercise this scenario and capture runtime signals.

Scenario: "${scenario}"

Device serial: ${setup.deviceSerial}
Artifact dir (write ALL captures here): ${setup.artifactDir}

${PROJECT}

Do:
1. Load tools: ToolSearch "select:Bash,mcp__dart__connect_dart_tooling_daemon,mcp__dart__get_widget_tree,mcp__dart__get_runtime_errors,mcp__dart__get_app_logs,mcp__dart__hot_reload".
2. Clear logcat first: \`adb logcat -c\`.
3. \`flutter attach\` from the project root and connect Dart MCP per the project facts. If attach fails, continue with adb-only driving and note it.
4. Take a baseline screenshot into the artifact dir.
5. Carry out the scenario. Navigate by reading the widget tree (mcp__dart__get_widget_tree summaryOnly:true) to find targets, then tapping — via mcp__dart__flutter_driver if a driver extension is available, otherwise via uiautomator dump + adb input tap. After each meaningful step take a screenshot named step-NN-<short-label>.png in the artifact dir and re-read the widget tree to confirm the new state.
6. If the scenario is a generic "inspect current screen", just capture the current screen thoroughly (screenshot + full widget tree).
7. Capture the remaining signals into files in the artifact dir:
   - widget-tree.txt  <- the get_widget_tree output for the final / most relevant screen
   - runtime-errors.txt <- mcp__dart__get_runtime_errors output, plus mcp__dart__get_app_logs (Dart/Flutter side errors and prints)
   - logcat.txt <- adb logcat --pid=$(adb shell pidof <applicationId>) -d -t 400
   - network.txt <- only if you can observe HTTP/network or webview console signals; otherwise skip and report networkDump:"".
8. Do not analyze deeply here — just exercise and capture faithfully. Record what you literally saw in rawObservations.

Return absolute paths of every file you wrote.`,
  { label: 'drive-app', phase: 'Drive', schema: DRIVE_SCHEMA },
)

if (!drive) {
  return { status: 'drive-failed', scenario, setup }
}

// ---------------------------------------------------------------------------
// Phase 3 — Analyze: fan out independent analyzers over the captured files.
// No device contention here — they read artifacts, not the device.
// ---------------------------------------------------------------------------
phase('Analyze')

const a = drive.artifacts
const driveContext = `Scenario: "${scenario}"
Steps driven: ${JSON.stringify(drive.stepsExecuted)}
Raw observations: ${JSON.stringify(drive.rawObservations)}
Artifact dir: ${setup.artifactDir}`

const ANALYZERS = [
  {
    key: 'layout',
    prompt: `You are a UI/layout reviewer. ${driveContext}

Read the screenshots (use Read on each PNG — it renders the image) and the widget tree file (${a.widgetTreeDump}).
Screenshots: ${JSON.stringify(a.screenshots)}

Find real, visible UI/layout defects ONLY: overflow / RenderFlex overflow stripes, clipped or truncated text, overlapping widgets, misalignment, broken spacing, off-screen content, unreadable contrast, missing/placeholder/empty states, broken images, wrong widths (e.g. progress bars resizing), RTL/locale breakage. Tie every finding to a specific screenshot or widget id. Do not invent issues you cannot see.`,
  },
  {
    key: 'runtime-errors',
    prompt: `You are a Flutter runtime-error analyst. ${driveContext}

Read ${a.runtimeErrorsDump}. Identify Dart/Flutter exceptions, framework assertion failures, RenderFlex/layout exceptions, null errors, failed futures, BLoC/ViewModel/state-management errors, and repeated error spam. Quote the exact error lines as evidence. Ignore benign debug prints.`,
  },
  {
    key: 'logcat',
    prompt: `You are a native-Android log analyst. ${driveContext}

Read ${a.logcatDump}. Identify native crashes, FATAL EXCEPTION, ANRs, plugin/JNI errors, permission denials, and StrictMode violations relevant to the app. Quote the exact log lines. Ignore unrelated system noise.`,
  },
  {
    key: 'network-console',
    prompt: `You are a network/console analyst. ${driveContext}

Network/console dump: ${a.networkDump || '(none captured)'}. If a dump exists, read it and identify failed requests (4xx/5xx), timeouts, auth failures, and HTTP client / WebView console errors. If no dump was captured, return an empty findings list (do not speculate).`,
  },
]

const analysis = await parallel(
  ANALYZERS.map((d) => () =>
    agent(d.prompt, { label: `analyze:${d.key}`, phase: 'Analyze', schema: FINDINGS_SCHEMA }),
  ),
)

const allFindings = analysis
  .filter(Boolean)
  .flatMap((r) => (r.findings || []).map((f) => ({ ...f, dimension: r.dimension })))

// ---------------------------------------------------------------------------
// Phase 4 — Report: synthesize one prioritized report.
// ---------------------------------------------------------------------------
phase('Report')

const report = await agent(
  `Write a concise runtime e2e report for the MorkvaCRM Flutter app on Android.

Scenario: "${scenario}"
Built fresh APK this run: ${setup.built ? 'yes' : 'no (reused running app)'}
Steps driven: ${JSON.stringify(drive.stepsExecuted)}
Artifact dir: ${setup.artifactDir}
Findings (raw, across dimensions): ${JSON.stringify(allFindings)}

Produce GitHub-flavored markdown:
1. One-line verdict: PASS / ISSUES FOUND / BLOCKED.
2. A table of findings sorted by severity (critical first): Severity | Dimension | Title | Location | Evidence.
3. A short "Repro" list of the steps that were driven.
4. A "What to look at" line pointing to the artifact dir (screenshots + dumps).
Drop duplicate findings reported by more than one dimension. If there are zero findings, say so plainly and report PASS. Be terse — no preamble.`,
  { label: 'synthesize-report', phase: 'Report' },
)

return {
  status: allFindings.length ? 'issues-found' : 'pass',
  scenario,
  built: !!setup.built,
  artifactDir: setup.artifactDir,
  findingCount: allFindings.length,
  report,
}
