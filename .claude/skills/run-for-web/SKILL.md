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
PROFILE="$HOME/.morkva-chrome-profile"; mkdir -p "$PROFILE"
flutter run -d chrome --web-hostname localhost --web-port 8088 \
  --web-browser-flag=--user-data-dir="$PROFILE"
```

Two flags make login persist, and **both** are required:

- `--web-browser-flag=--user-data-dir=…` — a **dedicated persistent profile dir** instead of Flutter's default throwaway temp profile.
- `--web-hostname localhost --web-port 8088` — a **fixed origin**. This is the one people miss: Firebase Auth stores the web session in IndexedDB keyed by origin (`host:port`), and `flutter run` picks a *random* port each launch. A new port = a new origin = the previous login is invisible = login screen every time. Pin the port and the origin stays constant, so the session carries over.

The user signs in once at `localhost:8088`; every later run auto-resumes.

Run it in the background if the session should outlive the command (`nohup … &` and `disown`), or in the foreground to keep Flutter's `r` (hot reload) / `R` (hot restart) keys.

## Notes

- **Use `-d chrome`**, not `-d web-server` — only the chrome device launches a real browser to attach the profile to.
- Use a **dedicated** profile dir (`~/.morkva-chrome-profile`), never the user's real Chrome profile — that collides with their everyday Chrome and locks.
- First web compile is slow (~30–60s); later runs are faster.
- The user must complete the Google sign-in popup **once** per profile; it persists afterward.

## If it won't launch

`Failed to launch browser after 3 tries` means a stale Chrome still holds the profile lock:

```bash
pkill -9 -f "remote-debugging-port"
rm -f "$HOME/.morkva-chrome-profile"/Singleton{Lock,Cookie,Socket}
```

Then run again.
