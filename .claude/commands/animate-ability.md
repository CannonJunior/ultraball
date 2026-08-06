# Animate Ability

Improve the VFX animation for an Ultraball ability. Argument: `$ARGUMENTS` (ability name or path, e.g. `mend` or `vitalist/mend`).

---

## Step 1 — Find and Read the Ability

Search `godot/data/abilities/` for a `.tres` file matching the argument. Read it fully.

Extract from the `.tres`:
- `ability_id`, `display_name`, `description` — understand what the ability DOES
- `slot` — 1=basic, 2-9=ability tier, 10=ultra
- `mana_type` — 0=free, 1=red/aggressive, 2=blue/temporal, 3=yellow/support, 4=gold/ultra
- `cooldown`, `mana_cost`, `range` — sense of scale and weight
- From `vfx_config` sub-resource: `cast_type`, `traversal_type`, `impact_type`, `sustained_type`, all colors, all radii, all durations

## Step 2 — Read the Current Implementations

In `godot/systems/AbilityVfxLayer.gd`, find the draw functions for each active effect type:

**Cast type → function name:**
- 0=none, 1→`_draw_cast_ring`, 2→`_draw_double_ring`, 3→`_draw_petal_bloom`
- 4→`_draw_compressed_rings`, 5→`_draw_spiral_cast`, 6→`_draw_cross_burst`
- 7→`_draw_strike_flash`, 8→`_draw_heal_spiral_cast`, 9→`_draw_blue_cloud_cast`

**Traversal type → function name:**
- 0=none, 1→`_draw_mote_ribbon`, 2→`_draw_strike_line`, 3→`_draw_disc_projectile`
- 4→`_draw_ring_projectile`, 5→`_draw_heal_spiral_travel`, 6→`_draw_blue_cloud_travel`

**Impact type → function name:**
- 0=none, 1→`_draw_burst_ring`, 2→`heal_rise` (rising_orbs), 3→`_draw_shield_collapse`
- 4→`hit_spark`+`buff_pulse` (sparks), 5→two-phase burst+ring, 6→`heal_spiral_cast` at target, 7→`_draw_blue_cloud_impact`

**Sustained type → function name:**
- 0=none, 1→`_draw_sustained_pulse`, 2→`_draw_rotating_arcs`

Also read the matching cases in `godot/systems/ViewLayer3D.gd` — search for the same string keys (e.g. `"heal_spiral_cast"`).

## Step 3 — Diagnose Visual Quality

Ask these questions for each phase:

**CAST** — does the animation feel like the ability is being charged/prepared? Does it point toward the target? Is its energy level proportionate to the ability's power (cooldown × mana_cost)?

**TRAVERSAL** — does the projectile travel in a way that reads as fast/slow, heavy/light? A bolt should be faster than a healing ribbon. High-range abilities need visible projectiles.

**IMPACT** — does landing feel satisfying? Damage = explosive outward. Heal = inward/descending gift. Buff = bloom or pulse. CC = sharp flash. Does it communicate the effect to someone watching?

**SUSTAINED** — is it readable but not distracting? Should indicate "something is happening to this player."

**SCALE** — VFX positions use game units that map roughly 1:1 to meters. Typical player radius ~0.5. Radius 1–3 = subtle. 5–10 = readable. 12+ = dramatic. Scale to the ability's importance.

**COLOR** — does it match the ability's theme and character class?
- Damage / aggressive: `C_DMG` (1,0.4,0.1) or `C_RED` (1,0.25,0.25)
- Heal / restore: `C_GREEN` (0.2,0.9,0.35) or `C_TEAL` (0.1,0.75,0.6)
- Support / buff: `C_GOLD` (1,0.82,0.1) or `C_YELLOW` (1,0.85,0.15)
- Debuff / control: `C_PURPLE` (0.65,0.15,0.85)
- Temporal / tech: `C_BLUE` (0.25,0.5,1) or `C_LIGHTNING` (0.55,0.85,1)

## Step 4 — Propose Improvements

Write a brief analysis: what each phase currently looks like visually, what it should look like, and specifically what to change (effect type, color, radius, duration, or particle behavior). Wait for user approval before changing anything.

## Step 5 — Implement

Edit the `.tres` file for config-level changes (color, radius, duration, enum type).

For particle behavior changes, edit the draw function(s) in `AbilityVfxLayer.gd` AND the matching case(s) in `ViewLayer3D.gd`. **Both must always be updated together** — they render from the same pool.

---

## Core Particle Patterns

### Phase-staggered particles (use for everything except instant flashes)
```gdscript
const N := 16  # particle count
for i in N:
    var phase := float(i) / float(N) * 0.45  # stagger fraction (0.3–0.6)
    var dp := clampf((p - phase) / maxf(1.0 - phase, 0.01), 0.0, 1.0)
    if dp <= 0.0: continue
    var ep := _ease_out(dp)  # decelerate (use for rising/expanding)
    # For gravity/falling: ep = dp * dp * dp  (accelerate)
```

### Golden-angle spatial scatter
```gdscript
var ga := float(i) * 2.399963        # golden angle in radians
var sr := sqrt(float(i + 1) / float(N)) * RADIUS  # even area distribution
var ox := cos(ga) * sr
var oz := sin(ga) * sr  # 3D only; use 0 in 2D (scatter is x-only there)
```

### Rising sparks (cast / generation)
```gdscript
var rise := lerpf(0.0, 12.0, ep)    # 12 = full height in game units
var drift := sin(float(i) * 1.7 + ep * 2.0) * rise * 0.06
var pos: Vector2 = v.pos + Vector2(ox + drift, -rise)  # -Y = up in 2D
var spark_len := lerpf(2.8, 0.5, dp)
draw_line(pos, pos + Vector2(drift * 0.05, -spark_len), col, 0.20)
```

### Falling sparks (impact / delivery)
```gdscript
var fall := lerpf(12.0, 0.0, ep)    # starts at height, falls to target
var drift := sin(float(i) * 1.7 + ep * 2.0) * fall * 0.06
var pos: Vector2 = v.pos + Vector2(ox + drift, -fall)
var spark_len := lerpf(2.8, 0.5, dp)
draw_line(pos, pos + Vector2(drift * 0.05, spark_len), col, 0.20)  # +Y = down
```

### 3D coordinate mapping
```
2D: v.pos + Vector2(x, y)  →  3D: c + Vector3(x, height, -y)
Rising: base3 + Vector3(0, spark_len, 0)   (Y-up)
Falling: base3 + Vector3(0, -spark_len, 0)
```

### 3D helpers available in ViewLayer3D
- `_vring(c3, radius, color)` — horizontal circle
- `_varcs(c3, radius, color, count)` — arc segments around ring
- `_vdot(pos3, color)` — single point
- `_vline(a3, b3, color)` — line segment
- `_vspark(c3, radius, color, n)` — radial spokes outward (use for damage/burst impacts ONLY, not for healing)

---

## Critical GDScript Gotcha

**NEVER** infer types from Dictionary fields. GDScript's type inference fails on Variant:

```gdscript
# WRONG — causes parse error "Cannot infer the type of 'pos'"
var pos := v.pos + Vector2(1.0, 0.0)

# CORRECT — always use explicit types for Dictionary field reads
var pos: Vector2 = v.pos + Vector2(1.0, 0.0)
var col: Color = v.color
var dur: float = v.data.get("duration", 1.0)
```

This applies to every field read from the VFX pool entry (`v.pos`, `v.color`, `v.data.*`).

---

## Spawn function signatures (for adding new effect types)

```gdscript
# _spawn(type_key, position, color, duration, data_dict)
_spawn("my_effect", cpos, vfx.cast_color, vfx.cast_duration, {"radius": vfx.cast_radius})

# In _draw(), dispatch by type key:
"my_effect": _draw_my_effect(v, p)

# Draw function signature:
func _draw_my_effect(v: Dictionary, p: float) -> void:
    # v.pos: Vector2, v.color: Color, v.data: Dictionary, p: 0→1 progress
```

For new effect types, add to both `_draw()` dispatch and `_draw_vfx_3d()` in ViewLayer3D.

---

## Design Principles

| Ability role | Cast feel | Traversal | Impact feel |
|---|---|---|---|
| Damage | Charge outward, directional | Fast, direct | Explosive radial burst |
| **Melee / Physical** | **Strike flash at caster** | **None (range ≤ 8)** | **Comic starburst (see section below)** |
| Heal (instant) | Rise from caster | Arcing ribbon | Descend onto target |
| HoT (over time) | Rise from caster | Arcing ribbon | Descend + periodic falling sparks |
| Buff | Inward compression → bloom | Orbiting ring | Shield-collapse + pulse |
| Debuff / CC | Sharp cross/flash | Lightning lines | Sharp flash + status indicator |
| AoE | Petal bloom / ring | None (centered) | Multi-ring burst |
| Ultra | Spiral + double ring | Multiple chains | Full-screen radial |

**Visual language of direction:**
- Upward = creation, growth, healing emanating from within
- Downward = delivery, grace, healing raining from above
- Outward = explosion, release, burst of energy
- Inward = charge, focus, absorption, shield

---

## Comic Book / Superhero Melee Impact Style

This is a **separate visual language** from the lightning/energy effects used by Uberblitzer. Use it for physical melee hits, punches, earth-shattering impacts — any ability where the Archon or a physical attacker connects.

### Core Rules

1. **Flat opaque colors, no soft glows.** Comic effects are opaque at peak and then disappear. No additive alpha-blend halos.
2. **Black outlines on everything.** Draw the black version (slightly wider/larger) first, then the color on top. This mimics ink outlining color in a printed comic panel.
3. **Total duration: 0.22–0.30s.** Fighting game speed. No lingering. Viewers shouldn't have time to analyze the shape.
4. **Color sequence:** pure white (instant) → bright yellow `Color(1, 0.92, 0.10)` → orange `Color(1, 0.55, 0.05)` as it fades.
5. **Scale big.** The impact ring should reach 2.0–2.5 game units. Spikes 2.0–2.5 for long, 1.0–1.2 for short.

### The 4-Layer Stack (draw in this order so layers compose correctly)

```
Layer 1 (back):  Speed lines — 24 thin dark radial lines
Layer 2:         Thick shockwave ring — wide at birth, razor thin at death, black-outlined
Layer 3:         Comic starburst — 8 alternating long/short spikes, black-outlined
Layer 4 (front): White core flash — filled circle, cuts off at 0.12s
```

### Layer 1: Speed Lines (background radial hatching)

```gdscript
# Duration: 0 → 0.18s
var sl_p := clampf(p / 0.18, 0.0, 1.0)
if sl_p < 1.0:
    var sl_ep := _ease_out(sl_p)
    var sl_a  := lerpf(0.50, 0.0, sl_p)
    for i in 24:
        var angle := float(i) * TAU / 24.0
        var d := Vector2(cos(angle), sin(angle))
        draw_line(pos + d * lerpf(0.35, 0.55, sl_ep),   # inner radius
                  pos + d * lerpf(1.60, 2.40, sl_ep),   # outer radius
                  Color(0.0, 0.0, 0.0, sl_a * 0.40), 0.025)
```

Key: 24 lines (high density reads as comic-book), very thin (0.025), dark not black-black. Lines expand outward with the effect.

### Layer 2: Thick Shockwave Ring (born wide, dies thin)

```gdscript
# Duration: 0.03s → 0.22s
var rp : float = clampf((p - 0.03) / 0.19, 0.0, 1.0)
if rp > 0.0:
    var rep    := _ease_out(rp)
    var ring_r := lerpf(0.10, 2.10, rep)        # expands outward
    var ring_w := lerpf(0.24, 0.02, rp)         # born thick, dies thin — the comic ring signature
    var ring_a := lerpf(1.0, 0.0, rp * rp)
    # Black outline — draw FIRST, slightly wider
    draw_arc(pos, ring_r, 0.0, TAU, 48, Color(0.0, 0.0, 0.0, ring_a * 0.85), ring_w + 0.05)
    # Color ring on top
    draw_arc(pos, ring_r, 0.0, TAU, 48, Color(1.0, 0.92, 0.10, ring_a), ring_w)
```

The `ring_w = lerpf(0.24, 0.02, rp)` thick-to-thin transition is the **defining comic book ring signature**. Generic effects use constant width.

### Layer 3: Comic Starburst (alternating long/short spikes)

```gdscript
# Duration: 0.05s → 0.26s
var sp : float = clampf((p - 0.05) / 0.21, 0.0, 1.0)
var sa := lerpf(1.0, 0.0, sp * sp)
if sa > 0.01:
    var sep := _ease_out(sp)
    for i in 8:
        var angle   := float(i) * TAU / 8.0 + PI / 8.0   # 22.5° offset
        var d       := Vector2(cos(angle), sin(angle))
        var is_long := i % 2 == 0                          # alternating pattern
        var r_tip   : float = lerpf(0.0, 2.20 if is_long else 1.10, sep)
        var r_base  : float = lerpf(0.0, 0.22, sep)
        var sw      : float = lerpf(0.12 if is_long else 0.07, 0.03, sp)
        # Black outline behind spike — draw FIRST
        draw_line(pos + d * r_base, pos + d * r_tip,
            Color(0.0, 0.0, 0.0, sa * 0.80), sw + 0.05)
        # Colored spike on top — yellow fades to orange
        draw_line(pos + d * r_base, pos + d * r_tip,
            Color(1.0, lerpf(0.95, 0.42, sp), lerpf(0.05, 0.08, sp), sa), sw)
```

Key: **alternating spike lengths** (2.20 / 1.10 ratio) create the jagged starburst POW silhouette. Uniform spikes look like a generic energy burst.

### Layer 4: White Core Flash (on top)

```gdscript
# Duration: 0 → 0.12s — sharp cutoff, no lingering
var fl_p := clampf(p / 0.12, 0.0, 1.0)
if fl_p < 1.0:
    draw_circle(pos, lerpf(0.0, 1.0, _ease_out(fl_p)),
        Color(1.0, 1.0, 1.0, lerpf(1.0, 0.0, fl_p)))
```

Pure white, no color tint. Drawn last (on top of everything). This sells the "moment of contact" — the viewer's eye registers white before anything else.

### 3D Equivalent (ViewLayer3D)

Black outlines don't translate to 3D, but the shape does. Use `_vring` for the ring, `_vline` for spikes:

```gdscript
# Shockwave ring
var st_rp : float = clampf((p - 0.03) / 0.19, 0.0, 1.0)
if st_rp > 0.0:
    _vring(c, lerpf(0.10, 2.10, _eo(st_rp)),
        _ca(Color(1.0, 0.92, 0.10), lerpf(1.0, 0.0, st_rp * st_rp)))
# Alternating spikes
var st_sp : float = clampf((p - 0.05) / 0.21, 0.0, 1.0)
var st_sa := lerpf(1.0, 0.0, st_sp * st_sp)
if st_sa > 0.01:
    var st_sep := _eo(st_sp)
    for i in 8:
        var st_ang  := float(i) * TAU / 8.0 + PI / 8.0
        var st_long := i % 2 == 0
        var st_d3   := Vector3(cos(st_ang), 0.0, sin(st_ang))
        var st_tip  : float = lerpf(0.0, 2.20 if st_long else 1.10, st_sep)
        var st_base : float = lerpf(0.0, 0.22, st_sep)
        _vline(c + st_d3 * st_base, c + st_d3 * st_tip,
            _ca(Color(1.0, 0.92, 0.10), st_sa))
# White core
var st_fl := clampf(p / 0.12, 0.0, 1.0)
if st_fl < 1.0:
    _vring(c, lerpf(0.0, 1.0, _eo(st_fl)),
        _ca(Color(1.0, 1.0, 1.0), lerpf(1.0, 0.0, st_fl)))
```

### Reference implementation

The Archon's **Stonefist** (`impact_type = 8`, `"stonefist_hit"`) is the canonical example. Study `_draw_stonefist_hit` in `AbilityVfxLayer.gd` and its matching case in `ViewLayer3D.gd` before writing new comic-book style effects.

### Tuning guide

| Parameter | Subtle hit | Normal hit | Big hit |
|---|---|---|---|
| Total duration | 0.20s | 0.28s | 0.35s |
| Long spike radius | 1.4 | 2.2 | 3.0 |
| Short spike radius | 0.7 | 1.1 | 1.5 |
| Ring max radius | 1.4 | 2.1 | 2.8 |
| Speed line count | 16 | 24 | 32 |
| Core flash radius | 0.6 | 1.0 | 1.4 |

### Future: Hit Stop (not yet implemented)

The single highest-impact technique for melee feel. When implemented, call this at the moment of ability resolution:
```gdscript
# In AbilitySystem or a dedicated GameFeel autoload:
func trigger_hit_stop(duration: float = 0.06) -> void:
    Engine.time_scale = 0.05
    # CRITICAL: 4th arg must be true (ignore_time_scale) or timer never fires
    await get_tree().create_timer(duration, true, false, true).timeout
    Engine.time_scale = 1.0
```
Duration 0.05–0.08s. Shorter than 0.04s = imperceptible. Longer than 0.10s = feels like a bug.

---

## Long-Term Animation UI Architecture

This skill is a stepping stone toward an in-game animation editor. When making changes, nudge the system toward this roadmap:

### Stage 1 (now): Named functions + enum selector
The current state. Each effect type is a hand-coded draw function. Config stores only enum ints + color/radius/duration.

### Stage 2: Data-driven particle config
Migrate magic numbers from draw functions into `AbilityVfxConfig` resource fields:
```gdscript
# Add to AbilityVfxConfig.gd:
@export var cast_particle_count: int = 16
@export var cast_rise_height: float = 12.0
@export var cast_scatter_radius: float = 1.75
@export var cast_spark_length_start: float = 2.8
@export var cast_spark_length_end: float = 0.5
@export var cast_stagger: float = 0.45
@export var cast_ease_mode: int = 0  # 0=ease_out, 1=ease_in, 2=linear
```
The draw functions then become a single generic renderer reading these fields. **When you find yourself hardcoding particle counts or heights in a draw function, consider whether it belongs in the config instead.**

### Stage 3: Godot EditorPlugin preview
A `godot/addons/ability_animator/` EditorPlugin with:
- Custom dock with parameter sliders/color pickers bound to `AbilityVfxConfig` fields
- SubViewport showing the ability animation looping at 1× and 2× speed
- Preset dropdown (maps enum types to default parameter sets)
- "Apply to .tres" button

### Stage 4: Portable web tool
The core math (golden angle, lerp, ease functions) compiles directly to JavaScript/Canvas2D. A standalone web app can:
- Load `.tres` files via a local file-watching server
- Render previews using the same particle math
- Write parameter changes back to `.tres`
- Export particle configs as JSON for use in Unity, Godot, or web games

**When evaluating changes, prefer solutions that separate "what" (data in .tres) from "how" (rendering code), as this is what makes Stage 3/4 achievable without a full rewrite.**
