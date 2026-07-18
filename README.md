# Ultraball

A competitive, rapid, chaotic sports-combat game built with Flutter for the web.

Two (or three) teams of up to 7 active players compete across 5 acts to carry or pass the **Ultraball** into the opposing endzone while fighting, stunning, and killing each other. A giant creature patrols both channel zones, devouring anyone in its path — friend or foe.

**Scoring:**
| Name | Points | Trigger |
|------|--------|---------|
| Ultra | 7 | Carry the ball into the opposing endzone |
| Meta | 3 | Pass the ball to a teammate already in the endzone |
| Killa | 1 | Kill any opposing player (any cause) |

---

## Prerequisites

### Both platforms

- **Flutter SDK ≥ 3.35** (web target required — `flutter channel stable`)
- **Dart SDK ≥ 3.9** (bundled with Flutter)
- A Chromium-based browser (Chrome, Edge, Brave) for local development

### Ubuntu / Debian

```bash
# Install Flutter via snap (includes Dart)
sudo snap install flutter --classic
flutter sdk-path          # confirm install path
flutter doctor            # check for missing deps

# Chrome is required for flutter run -d web-server
sudo apt install google-chrome-stable   # or chromium-browser
```

### macOS

```bash
# Install Flutter via Homebrew
brew install --cask flutter
flutter doctor            # check for missing deps (Xcode, etc.)

# Chrome is pre-installed on most Macs; if not:
brew install --cask google-chrome
```

---

## Building & Running

All commands run from the **`ultraball_game/`** directory (where `pubspec.yaml` lives).

### Quick start (both platforms)

The repo ships a convenience launcher at the repository root:

```bash
# From the repo root:
bash start.sh
```

This kills any stale process on port 7777, runs `flutter pub get`, and starts the game at **http://localhost:7777**.

### Manual steps

```bash
cd ultraball_game

# Fetch dependencies
flutter pub get

# Run in browser (development — hot-reload enabled)
flutter run -d web-server --web-port=7777 --web-hostname=localhost
# Then open http://localhost:7777 in Chrome/Edge/Brave
```

### Production web build

```bash
flutter build web --release
# Output: build/web/  — serve with any static file server
python3 -m http.server 8080 --directory build/web
```

---

## Project Layout

```
ultraball_game/
├── lib/
│   ├── main.dart               # App entry point, theme load
│   ├── models/                 # Data: player, ultraball, terrain, settings …
│   ├── game/
│   │   ├── game_state.dart     # Central mutable state (roster, ball, timers)
│   │   ├── game_widget.dart    # Flutter widget driving the game loop
│   │   ├── field_painter.dart  # 2-D field canvas painter
│   │   └── systems/            # ECS-style update systems
│   │       ├── act_system.dart      # Act clock, scoring, substitutions
│   │       ├── ai_system.dart       # Opponent & friendly AI
│   │       ├── ball_system.dart     # Ball physics, possession, charge
│   │       ├── combat_system.dart   # Abilities, damage, mana
│   │       ├── collision_system.dart
│   │       ├── creature_system.dart
│   │       └── terrain_system.dart
│   ├── game3d/                 # Optional 3-D renderer (WebGL via dart:js)
│   ├── ai/                     # AI strategy / policy definitions
│   ├── ui/                     # Flutter widgets: scoreboard, mana bars, HUD …
│   └── rendering3d/            # WebGL mesh & rig primitives
├── assets/
│   ├── fonts/                  # Bangers (display font)
│   └── ui/
│       ├── theme.json          # Overridable color / layout tokens
│       ├── class_icons/        # Per-class SVG icons (currentColor tinted)
│       └── score_icons/        # Ultra / Meta / Killa SVG icons
├── test/                       # Unit & widget tests (flutter test)
└── web/                        # Flutter web shell (index.html, manifest …)
```

---

## Player Classes

Each roster slot is assigned a class by `rosterIndex % 8`:

| # | Class | Role | Mana |
|---|-------|------|------|
| 0 | Spectre | Speed / evasion | Blue |
| 1 | Corsair | Disruption / strip | Yellow |
| 2 | Geomancer | Terrain control | Red |
| 3 | Archon | Defense / fortress | Blue |
| 4 | Warden | Support / field control | Blue |
| 5 | Trickster | Illusion / traps | Red |
| 6 | Wrecker | Brute force damage | Red |
| 7 | Vitalist | Healing / renewal | Yellow |

Classes can be toggled inactive in the pre-game settings screen. Inactive-class players are removed from the field roster but still consume a permanent death slot if killed.

---

## Theming

Edit `assets/ui/theme.json` to override any color or layout token without recompiling. Unknown keys are silently ignored and fall back to compiled defaults. Hot-restart (`r` in the terminal) to apply changes.

---

## Running Tests

```bash
cd ultraball_game
flutter test
```

Tests live in `test/` and cover core game systems (combat math, scoring logic, ability interactions). The test suite does not require a browser.

---

## Controls (in-game)

| Input | Action |
|-------|--------|
| **WASD / Arrow keys** | Move selected player |
| **Space** | Tackle / pick up ball |
| **Shift** | Sprint |
| **Q** | Slam |
| **1–0** | Class abilities (slots 1–10) |
| **Tab** | Cycle target |
| **T** | Throw / aim pass |
| **P** | Pause |
| **Esc** | Cancel aim / open menu |
