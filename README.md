# Thakaali Timer

A tiny pomodoro timer for macOS. Instead of a window, the timer is a thin line along the edge of your screen: **red** during a tomato (focus session) and **green** during a break. The line starts full and shrinks as time runs out.

Behaviour follows Tomato 2, minus the window, ads, goals and website blocking.

## Features

- Thin progress line on every display, click-through, and visible over full-screen apps
- Line position: top (default), bottom, left or right
- Line thickness slider (1–30 pt), previewed live while Settings is open
- Configurable durations: tomato 25 min, short break 5 min, long break 15 min, long break every 4 tomatoes
- When a session ends: **Ask what to do** (start next, extend 5 min, or hold ⌥ to extend 15 min) or **Autostart next**
- Menu bar item with the time left; no Dock icon
- Hold ⌥ Option in the menu to **Pause** instead of Stop

## Build and run

Requires macOS 13 or later and the Xcode command line tools (`xcode-select --install`).

```sh
scripts/build-app.sh
open "build/Thakaali Timer.app"
```

For quick iteration you can also run `swift run` from the repo root.

To keep it around, drag `build/Thakaali Timer.app` into `/Applications`.

Every push also builds the app on GitHub Actions; the zipped app is attached to each run as an artifact. Because it is only ad-hoc signed, right-click it and choose **Open** the first time.
