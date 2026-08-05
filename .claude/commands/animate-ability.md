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
