---
name: run-for-web
description: "Run the MorkvaCRM Flutter app on Chrome with a PERSISTENT browser profile"
when_to_use: "run web app, run web, run on chrome, start web, flutter web, web version, запусти веб, веб версію, запусти на хромі"
---

# Run Web App (persistent profile)

Run the app on Chrome so the Google session stays logged in between launches.

## Run

From the project root:

```bash
# The ONE shared, signed-in profile: always the main checkout's, also from worktrees.
PROFILE="/home/naik/Dev/MorkvaCRM/.dart_tool/chrome-device"
flutter run -d chrome --web-hostname localhost --web-port 8088 \
  --web-browser-flag=--user-data-dir="$PROFILE"
```

Two flags make login persist, and **both** are required:

- `--web-browser-flag=--user-data-dir=…` — a **dedicated persistent profile dir** instead of Flutter's default throwaway temp profile.
- `--web-hostname localhost --web-port 8088` — a **fixed origin**. This is the one people miss: Firebase Auth stores the web session in IndexedDB keyed by origin (`host:port`), and `flutter run` picks a *random* port each launch. A new port = a new origin = the previous login is invisible = login screen every time. Pin the port and the origin stays constant, so the session carries over.

The user signs in once at `localhost:8088`; every later run auto-resumes.

Run it in the background if the session should outlive the command (`nohup … &` and `disown`), or in the foreground to keep Flutter's `r` (hot reload) / `R` (hot restart) keys.

Against the local Firestore emulator (e2e; no production data, persistence off), start
`firebase emulators:start --only firestore --project morkvacrm` and add
`--dart-define=MORKVA_FIRESTORE_EMULATOR=127.0.0.1:8080`; the stored Google sign-in still works.

## Notes

- **Use `-d chrome`**, not `-d web-server` — only the chrome device launches a real browser to attach the profile to.
- Always use the **shared** profile `/home/naik/Dev/MorkvaCRM/.dart_tool/chrome-device` (the owner's signed-in session), never `~/.morkva-chrome-profile` (signed out, retired) and never the user's real Chrome profile. Don't ask the owner to sign in. Check no other Chrome holds it first (`ps -eo args | grep [c]hrome-device`).
- `flutter clean` in the main checkout deletes `.dart_tool`, and the sign-in with it.
- First web compile is slow (~30–60s); later runs are faster.
- The user must complete the Google sign-in popup **once** per profile; it persists afterward.

## If it won't launch

`Failed to launch browser after 3 tries` means a stale Chrome still holds the profile lock:

```bash
pkill -9 -f "remote-debugging-port"
rm -f /home/naik/Dev/MorkvaCRM/.dart_tool/chrome-device/Singleton{Lock,Cookie,Socket}
```

Then run again.
