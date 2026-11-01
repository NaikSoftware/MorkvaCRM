---
name: run-for-web
description: Run the MorkvaCRM Flutter app as a web server on a fixed port and open it in the user's own Chrome, so their existing login is reused - run web app, run web, run on chrome, start web, flutter web, web version, запусти веб, веб версію, запусти на хромі
---

# Run Web App (web server, user's own Chrome)

Serve the app on a fixed origin; the user opens it in **their everyday Chrome**, so their Google /
Firebase session carries over. Don't launch a browser for them.

## Run

From the project root, in the background, so it outlives the command:

```bash
LOG=<scratchpad>/web-run.log
nohup sh -c "tail -f /dev/null | flutter run -d web-server --web-hostname localhost --web-port 8088" > "$LOG" 2>&1 & disown
timeout 180 sh -c "until grep -qE 'is being served at|Error|Failed|finished' $LOG; do sleep 1; done"; tail -3 "$LOG"
curl -s -o /dev/null -w '%{http_code}\n' http://localhost:8088/   # expect 200
```

Then tell the user to open **http://localhost:8088** in their Chrome.

- **The port must be fixed.** Firebase Auth keeps the web session in IndexedDB keyed by origin
  (`host:port`). `flutter run` picks a random port each launch, and a new origin means a new
  login every time. With `localhost:8088` the user signs in once and stays signed in.
- **Pipe `tail -f /dev/null` into stdin.** In the background with no terminal, `flutter run` hits
  EOF on stdin and exits right after start ("Application finished"). Holding stdin open keeps it running.
- `-d web-server` doesn't attach a debugger, so Dart `print` output only appears in the browser
  console, not in the log.
- First compile takes about 30–60s.

## Reload / stop

There's no terminal for `r`/`R`, so restart instead. Stop it with
`pkill -f "flutter_tools.snapshot run -d web-server"` and `pkill -f "tail -f /dev/null"`, then run
it again; the user refreshes the tab. Run each `pkill` as its own command: a pattern that also
appears in the current shell's command line kills that shell (exit 144).

If port 8088 is busy, an old server is still running: `ss -ltnp | grep 8088`, and stop it as above.
