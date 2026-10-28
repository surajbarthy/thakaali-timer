# Thakaali Timer

A tiny pomodoro timer for macOS. Instead of a window, the timer is a thin line along the edge of your screen: **red** during a tomato (focus session) and **green** during a break. The line starts full and shrinks as time runs out.

Behaviour follows Tomato 2, minus the window, ads, goals and website blocking.

## Features

- Thin progress line on every display, click-through, and visible over full-screen apps
- Line position: top (default, just under the menu bar, clear of the notch), bottom, left or right
- The tomato line drains toward the top-right corner (bottom on the side edges); the break line grows back out of that corner until it is full. A "Reverse direction" setting anchors it at the left (top on the side edges) instead
- Line style: **Solid**, **Feathered** (soft edges, faded moving end) or **Haze** (wide, faint wash)
- Thickness slider for the resting size (default 3 pt). The line doubles when a session starts or when you rest the pointer on it for a moment, and shows a small "12 min left" tag
- Configurable durations: tomato 25 min, short break 5 min, long break 15 min, long break every 4 tomatoes
- When a session ends: **Toast in the corner** (default), **Menu from the menu bar**, **Alert**, or **Autostart next**. Hold ⌥ to extend by 15 min instead of 5
- Uses the Geist typeface (bundled, SIL Open Font License) for the toast, hover tag, countdown, menu and Settings
- Menu bar item with an optional countdown (off by default); no Dock icon
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
