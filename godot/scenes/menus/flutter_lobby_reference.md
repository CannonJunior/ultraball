# Flutter Landing Page Reference — Ultraball Match Configuration

## Color Palette
- `_kBg`     = `#04050A`  — page/scaffold background
- `_kSurf`   = `#08080F`  — card surface
- `_kGold`   = `#FFCB3D`  — accent gold (headers, selected borders)
- `_kBorder` = `#1A1A2E`  — card border color

## Overall Layout (wide screen)
```
Column
  ├── Header (fixed height, centered text)
  └── Expanded
        └── Row
              ├── SizedBox(width=560)  ← Settings Panel (SingleChildScrollView)
              ├── VerticalDivider(color=#1A1A2E, width=1)
              └── Expanded            ← Rules Panel (SingleChildScrollView)
```

---

## Header (`_buildHeader`)
- Container with padding: vertical=24, horizontal=32
- Column (centered):
  - Text "ULTRABALL" — font Bangers, size 72, letterSpacing 10
    - Gradient shader: `#FFCC00` → `#FF6600` → `#FF0044`
  - SizedBox(height=6)
  - Text "A COMPETITIVE RAPID CHAOTIC SPORTS COMBAT GAME"
    - font chakra petch, size 10, color white@0.45, letterSpacing 3, w500

---

## Component: `_SectionHeader`
- Row:
  - Container: width=3, height=18, color=`_kGold`, margin right=8
  - Text: chakra petch, size=11, w700, color=`_kGold`, letterSpacing=3

## Component: `_FieldLabel`
- Text: chakra petch, size=9, w600, letterSpacing=2, color white@0.45

## Component: `_SettingCard`
- Container: padding=all(16), bg=`_kSurf`, borderRadius=6, border=`_kBorder` width=1

## Component: `_SpeedButton`
- Toggle button (GestureDetector → AnimatedContainer)
- padding: vertical=10, horizontal=8
- SELECTED: bg=`#1A1A2E`, border=`#FFCC00` width=1.5
- UNSELECTED: bg=transparent, border=`#333355` width=1
- Label: barlowCondensed, size=15, w700, italic, letterSpacing=1
  - selected → color=`_kGold`, unselected → color white@0.6
- Sublabel: chakra petch, size=8, color white@0.35, letterSpacing=0.5

## Component: `_ChoiceRadio`
- AnimatedContainer: margin-bottom=8, padding horizontal=12 vertical=8
- SELECTED: bg=`#1A1A2E`, border=`#FFCC00` width=1.5
- UNSELECTED: bg=transparent, border=`#333355` width=1
- Row: [emoji Text(size=18)] [SizedBox(10)] [Expanded Column: label+desc] [check icon if selected]
- Label: barlowCondensed, size=13, w700, italic, letterSpacing=0.5
  - selected → color=`_kGold`, unselected → white@0.75
- Desc: chakra petch, size=8.5, color white@0.38

## Component: `_RuleSection`
- ExpansionTile inside a card, initially collapsed
- Leading: emoji (size 18)
- Title: barlowCondensed, size=15, w700, italic, letterSpacing=1, white@0.85
- Rules: bullet list (4px gold circle dot + text white@0.7, barlowCondensed size=13)

---

## Settings Panel Sections (in order)

### 1. Section Header: "MATCH CONFIGURATION"

### 2. MATCH MODE (_SettingCard)
- _FieldLabel("MATCH MODE")
- Row of two _SpeedButtons (Expanded):
  - "2 TEAMS" / "Classic — linear field"
  - "3 TEAMS" / "Triangle field"

### 3. HOME / AWAY TEAM (_SettingCard × 2, side by side)
- _FieldLabel("HOME TEAM (Player)") + TeamDropdown
- _FieldLabel("AWAY TEAM (Opponent)") + TeamDropdown
- If 3 TEAMS mode: _FieldLabel("THIRD TEAM") + TeamDropdown (half width)

### 4. CREATURE (_SettingCard, full width)
- _FieldLabel("CREATURE") + neutral-site checkbox (top row)
- If not neutral: shows home team's creature (emoji + name + desc)
  - Kraken 🐙, Dragon 🐉, Hydra 🐍, Wraith 👻, Chaos ⚡
- If neutral: dropdown to pick creature type

### 5. HOME STRATEGY + TACTICS / OPPONENT STRATEGY + TACTICS (two _SettingCards, side by side)
Left card: HOME STRATEGY (label) + hint text + 5 _ChoiceRadio entries + divider + HOME TACTICS (label) + hint text + 6 _ChoiceRadio entries
Right card: OPPONENT STRATEGY (same) + OPPONENT TACTICS (same)

**AiStrategy values:**
- `💣` TEMPO TRAP — "Deny phase lines; force opponent to hold the ball until it explodes"
- `🔢` NUMBERS GAME — "Eliminate 2–3 opponents early; exploit the field numbers edge to score freely"
- `🦅` CHANNEL CONTROL — "Control creature channels for protected scoring corridors; funnel opponents into the kill zone"
- `🌊` FLOOD THE ZONE — "Flood 3–4 players simultaneously into/near the endzone; defense can't cover everyone"
- `🩸` BLEED OUT — "Never surrender the ball; drain the clock; only score when the lane is completely safe"

**AiTactics values:**
- `🎯` FOCUS FIRE — "All attackers lock onto one target at once; eliminate before moving on"
- `🏀` PICK & SCREEN — "Two players set hard screens for the carrier; others sprint decoy routes to the endzone"
- `⚡` QUICK RELEASE — "Pass at the first open window; chain passes to advance; never hold the ball more than 2–3 seconds"
- `👹` CREATURE FLANK — "Position on the opposite side of the carrier from the creature; herd the opponent into it"
- `🔺` WEDGE RUN — "Three players form a tight triangle around the carrier and move as one unit toward the endzone"
- `⭐` HERO BALL — "All units rally around and protect the star player; immediately pass the ball to them"

### 6. MATCH DURATION (_SettingCard)
- _FieldLabel("MATCH DURATION")
- Row of two _SpeedButtons:
  - "NORMAL" / "3min acts"
  - "FAST" / "1min acts"

### 7. VIEW MODE (_SettingCard)
- _FieldLabel("VIEW MODE")
- Row of three _SpeedButtons:
  - "2D" / "Top-down"
  - "3/4" / "Isometric" (disabled in 3-team mode)
  - "3D" / "Perspective" (disabled in 3-team mode)

### 8. CONTROLS (_SettingCard)
- _FieldLabel("CONTROLS")
- 14 control rows (key badge + description):
  | Key         | Description                            |
  |-------------|----------------------------------------|
  | W / S       | Move forward / backward                |
  | A / D       | Turn left / right                      |
  | Q / E       | Strafe left / right                    |
  | 1           | Tackle (basic attack)                  |
  | 2           | Power Slam (25 Red Mana)               |
  | 3           | Sprint (20 Blue Mana)                  |
  | F           | Pass ball to teammate                  |
  | SPACE       | Jump (evades tackles while airborne)   |
  | SPACE ×2    | Double-jump (costs 15 Blue Mana)       |
  | TAB         | Cycle enemy target                     |
  | SHIFT+TAB   | Switch controlled player               |
  | M           | Toggle damage / healing meter          |
  | C           | Cycle player class (Test Mode only)    |
  | ESC         | Clear target / Pause                   |

- Key badge: bg=`#333355`, border=`#556688`, radius=3, padding h6 v2
- Key text: color=`#CCDDFF`, size=11, monospace, bold
- Desc text: white@0.6, size=11

### 9. TEST MODE (_SettingCard)
- Row: [Column: "TEST MODE" label + value text] [Switch]
- OFF: "Full match (7v7)"
- ON: "1v1 dummy — C key cycles class"

### 10. START MATCH button
- Full width, gradient bg: `#CC8800` → `#DD2200`
- Glow shadow: `#FF4400`@0.4
- Text: "START MATCH", font Bangers, size=30, letterSpacing=6

---

## Rules Panel Sections (in order)

### 0. Section Header: "GAME RULES"

### 1. Roster Editor (dynamic — shows team rosters with class drag-reorder)
   (skipped in Godot — too complex)

### 2. THE FIELD 🏟
Rules depend on match mode. 2-team version:
- "Total field: 140m × 40m"
- "Left & Right endzones: 20m deep — score here!"
- "Left & Right channels: 10m — patrolled by the creature"
- "Main field: 80m with 5 PHASE LINES at 20m intervals"
- "Phase lines reset ball charge when crossed"

### 3. SCORING 🏆
- "ULTRA (7 pts) — Ball carrier walks/runs into enemy endzone"
- "META (3 pts) — Pass caught by player already in enemy endzone"
- "KILLA (1 pt) — Opposing player dies (combat, creature, explosion)"

### 4. THE ULTRABALL ⚡
- "Holding the ball builds CHARGE — explodes after 7 seconds!"
- "Explosion kills holder, stuns teammates 1 second"
- "Passing resets charge: +1 second per meter thrown"
- "Crossing a PHASE LINE fully resets charge to 0"
- "Phase lines deactivate when crossed (reactivate on possession change)"
- "Failed pass: entire passing team stunned 1 second"

### 5. THE CREATURE 👹
- "Circles the entire field counter-clockwise at moderate speed"
- "Instantly kills any player it touches — both teams!"
- "Awards 1 KILLA point to the opposite team on each kill"
- "Three creature types: Kraken, Dragon, or Hydra (cosmetic)"

### 6. COMBAT ⚔
- "RED MANA: 0–100, gained by dealing damage (+5/hit), decays after 3s"
- "BLUE MANA: 0–100, auto-regens at 8/sec passively"
- "TACKLE (Q): 15 dmg, 0.8s cooldown — no mana cost"
- "POWER SLAM (E): 35 dmg + knockback, costs 25 Red Mana, 3s CD"
- "SPRINT (Shift): +50% speed for 3s, costs 20 Blue Mana, 6s CD"
- "POWER PASS (F+): +50% pass distance, costs 30 Blue Mana"
- "3-HIT COMBO: 3 attacks in 4s = COMBO! +30 red mana + knockback"

### 7. TEAMS 👥
- "7 players per team on field, 15-player roster total"
- "Deaths are PERMANENT within a match"
- "1 substitution allowed per act when a player dies"
- "After 1st death: sub used; subsequent deaths = disadvantage"
- "Teams restock to 7 at the start of each new act"
- "All 15 players dead = FORFEIT"

### 8. THE ACTS 📋
- "Acts 1–4: 3-minute countdown timer (1 min in Fast mode)"
- "Act 5: Ends when the leading team scores an ULTRA..."
- "...OR the trailing team comes back and scores an ULTRA"
- "Highest score at end of Act 5 wins the match!"

---

## Key Godot Layout Rule (CRITICAL)
In Godot 4, `ScrollContainer` must have a direct `VBoxContainer` child.
The VBoxContainer must have SIZE_EXPAND_FILL horizontal only (NOT vertical).
This lets VBoxContainer grow taller than the ScrollContainer, triggering scrollbars.
NEVER wrap columns in HBoxContainer inside a single ScrollContainer — minimum size
propagation breaks and content gets clipped without a scrollbar.

Correct structure for two-column scrollable layout:
```
VBoxContainer (PRESET_FULL_RECT, root)
  ├── Header (Label/Container, SIZE_SHRINK_CENTER or fixed min height)
  ├── NetworkBar (Container, fixed min height)
  └── HBoxContainer (SIZE_EXPAND_FILL vertical = gets all remaining height)
        ├── ScrollContainer (SIZE_EXPAND_FILL both)
        │     └── VBoxContainer (SIZE_EXPAND_FILL horizontal ONLY)
        │           └── [all settings cards]
        └── ScrollContainer (SIZE_EXPAND_FILL both)
              └── VBoxContainer (SIZE_EXPAND_FILL horizontal ONLY)
                    └── [all rules cards]
```
