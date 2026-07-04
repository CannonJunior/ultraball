# Dynamic Terrain System — Design Plan

The field surface changes radically during play: mountains and valleys rise and sink,
pits open, and hazardous zones appear and mutate. Terrain changes are triggered by
the game event scheduler, by the creature's abilities, and by player class abilities.

---

## Data Model (Phase 1)

### `lib/models/terrain_grid.dart`

The field is 140 × 40 world units. Divide into a grid of cells:

```
const int kTerrainCols = 28;   // 5-unit columns
const int kTerrainRows = 8;    // 5-unit rows
const double kCellW = 5.0;
const double kCellH = 5.0;
```

Each cell:

```dart
enum SurfaceType { normal, ice, mud, lava, spikes, electric, poison, void_, heatVent, acid }
enum HazardType  { none, fire, ice, electric, poison, physical, corrosive, wind }

class TerrainCell {
  double  height       = 0.0;   // world units above ground; negative = pit
  double  targetHeight = 0.0;   // smoothly lerps toward this
  double  lerpSpeed    = 2.0;   // units/sec
  SurfaceType surface  = SurfaceType.normal;
  HazardType  hazard   = HazardType.none;
  double  hazardTimer  = 0.0;   // seconds remaining; 0 = no hazard
  double  hazardDps    = 0.0;   // damage per second applied to units in cell
  double  speedMult    = 1.0;   // 1.0 = normal; <1 = slow; >1 = fast
  bool    isPit        = false; // units that enter a pit are ejected/stunned
}

class TerrainGrid {
  final List<List<TerrainCell>> cells; // [col][row]

  TerrainGrid()
      : cells = List.generate(kTerrainCols,
            (_) => List.generate(kTerrainRows, (_) => TerrainCell()));

  TerrainCell cellAt(double worldX, double worldY) { ... }
  List<TerrainCell> cellsInRadius(double cx, double cy, double radius) { ... }
}
```

Add `TerrainGrid terrain = TerrainGrid()` to `GameState`.

---

### `lib/models/terrain_event.dart`

17 event types, each defined by a type, epicentre, radius, intensity, and duration:

```dart
enum TerrainEventType {
  // Geometry changes
  riseMountain,     // raise cells toward positive height
  sinkValley,       // lower cells toward negative height
  flatten,          // lerp cells back to height 0
  openPit,          // set isPit=true + height drops to -3
  closePit,         // restore pit cells to ground
  fissure,          // long narrow pit along a world-space line

  // Surface hazards (timed, cause status effects)
  lavaPool,         // fire hazard, continuous burn damage
  icePatch,         // speedMult=1.8, no turn control debuff
  mudZone,          // speedMult=0.45, reduces player speed
  spikeField,       // physical hazard, damage on entry
  electricZone,     // electric hazard, stun on contact
  poisonCloud,      // poison hazard, DoT + green fog VFX
  acidPool,         // corrosive hazard, strips armor buffs

  // Force / movement events
  shockwave,        // radial outward push of all units in range
  heatVent,         // upward force launches airborne + heatVent surface
  windTunnel,       // strong directional force vector over a strip

  // Reset
  normalize,        // fully restore a region to default terrain
}

class TerrainEvent {
  final TerrainEventType type;
  final double worldX, worldY;  // epicentre
  final double radius;
  final double intensity;       // 0–1 scale for height / damage magnitude
  final double duration;        // seconds the hazard persists (0 = instant)
  final double? directionRad;   // for windTunnel / fissure orientation

  const TerrainEvent({ required this.type, required this.worldX,
      required this.worldY, required this.radius, this.intensity = 1.0,
      this.duration = 0.0, this.directionRad });
}
```

---

## Simulation (Phase 2)

### `lib/game/systems/terrain_system.dart`

Called each tick from `_update` in game_widget.dart, after player updates:

```dart
class TerrainSystem {
  static void update(GameState gs, double dt) {
    _tickHeightLerp(gs, dt);
    _tickHazards(gs, dt);
    _applyTerrainEffectsToPlayers(gs, dt);
  }

  // Smoothly move cell heights toward their targetHeight
  static void _tickHeightLerp(GameState gs, double dt) { ... }

  // Count down hazardTimer; clear hazard when timer expires
  static void _tickHazards(GameState gs, double dt) { ... }

  // Apply speedMult, hazardDps, isPit effects to every field player
  static void _applyTerrainEffectsToPlayers(GameState gs, double dt) { ... }

  // Public: apply a TerrainEvent to the grid
  static void applyEvent(GameState gs, TerrainEvent event) { ... }
}
```

Surface effect rules per SurfaceType:
- **ice**: `speedMult = 1.8`, turning speed × 0.3 while on ice
- **mud**: `speedMult = 0.45`
- **lava**: `hazardDps = 15`, `HazardType.fire` — continuous burn
- **spikes**: `hazardDps = 30` on entry tick (pulse, not continuous)
- **electric**: stun 1.5 s on contact, `HazardType.electric`
- **poison**: `hazardDps = 5`, applies `poisonTimer` buff on player
- **acid**: `hazardDps = 8`, removes any active damageBoostFactor / damageReductionFactor
- **void_** (pit): ejects unit to nearest non-pit cell, stuns 2 s, 20 HP damage
- **heatVent**: `zVelocity += 25` on entry, launches unit upward

---

## Event Scheduler (Phase 3)

### `lib/game/terrain_event_scheduler.dart`

Schedules random terrain events throughout the act based on act timer and intensity:

```dart
class TerrainEventScheduler {
  double _nextEventTimer = 0.0;

  void update(GameState gs, double dt) {
    _nextEventTimer -= dt;
    if (_nextEventTimer <= 0) {
      _fireRandomEvent(gs);
      _nextEventTimer = _calcNextInterval(gs);
    }
  }

  // Interval shrinks as act timer gets low (more chaotic late-game)
  double _calcNextInterval(GameState gs) {
    final progress = 1.0 - gs.actState.timerSeconds / gs.actState.maxTimer;
    return math.max(8.0, 25.0 - progress * 18.0);
  }

  void _fireRandomEvent(GameState gs) {
    // Pick a random field region, pick event type weighted by game situation
    // e.g. if ball is in midfield → more geometry events
    //      if ball is in endzone  → more hazard events around defenders
    ...
    TerrainSystem.applyEvent(gs, event);
    gs.showEvent(_labelFor(event.type));
  }
}
```

Add `TerrainEventScheduler _scheduler = TerrainEventScheduler()` to `GameState` and
call `_scheduler.update(gs, dt)` inside `TerrainSystem.update`.

---

## 3D Mesh Rendering (Phase 4)

Replace the flat coloured quads in `_paint3D` / `_paintFull3D` with a displaced mesh.

### threeQuarter view (`field_painter.dart`)

Currently draws 9 zone quads as flat projected quadrilaterals. Replace with a
tessellated grid that displaces each vertex by `cell.height`:

```
For each terrain cell (col, row):
  - Compute 4 world-space corners: (col*kCellW, row*kCellH, cell.height)
  - Project all 4 with _camera3D.project(wx, wy, height)
  - Fill the quad with zone colour + height-based shading
  - Overlay hazard tint (lava = red glow, ice = cyan tint, etc.)
```

Height shading: `brightness = 0.7 + 0.3 * (cell.height / 5.0).clamp(-1, 1)`

Shadow: mountains cast a small offset dark quad at `height=0` beneath them.

### full3D view (`ultraball_render_system.dart`)

Build a dynamic vertex buffer for the field mesh each frame (or on dirty flag):
- 28 × 8 grid of quads → (29 × 9) vertices
- Each vertex Y = `cell.height` (already in the 3D Y-up space)
- Upload to WebGL as a dynamic position buffer
- Separate static UV buffer for texture coordinates
- Draw with a simple phong-lit shader; bind a grass/turf texture

Hazard zones: draw additive blended coloured overlays (lava = red, ice = blue, etc.)
on a second pass with depth-test = EQUAL so they sit on the displaced surface.

---

## Creature Terrain Abilities (Phase 5)

Each creature type gets 1–2 terrain signature abilities, triggered by `CreatureSystem`
when the creature reaches certain HP thresholds or act-timer milestones:

| Creature   | Ability 1                              | Ability 2                           |
|------------|----------------------------------------|-------------------------------------|
| Kraken     | **Tidal Surge** — mud + slow strip across midfield | **Undertow Pit** — opens 3 pits around ball carrier |
| Dragon     | **Lava Scar** — lava pool line along creature's path | **Magma Burst** — riseMountain + lava at epicentre |
| Hydra      | **Acid Rain** — 5-cell acid pool scatter | **Regenerate Earth** — normalize entire field |
| Wraith     | **Void Rift** — 2 fissures + electric zones | **Spectral Frost** — ice patch covering 40 % of field |

---

## Player Terrain Abilities (Phase 6)

Terrain abilities tied to class slots (slot 4 or 5 on specific classes):

| Class     | Ability Name        | Effect |
|-----------|---------------------|--------|
| Striker   | **Ground Pound**    | On landing from jump: shockwave radius 6, stuns nearby units 1 s, slight riseMountain at epicentre |
| Bruiser   | **Earthshaker**     | Charges forward; on stop: fissure along charge path + spike field flanking it |
| Guardian  | **Sacred Circle**   | Normalize 8-unit radius around self + freeze terrain in that area for 5 s (no further changes) |
| Spectre   | **Phase Sink**      | Create void_ pit under a targeted enemy, then immediately closePit after 2 s |
| Warden    | **Entangle**        | Mud zone + spike field combo centred on target location; 4 s duration |

Ability costs: 3–5 blue mana. Cooldowns: 12–20 s.

---

## AI Terrain Awareness (Phase 7)

`AiSystem` queries the terrain grid when choosing movement targets and pass decisions:

- **Pathfinding weight**: cells with `speedMult < 0.6` or `hazardDps > 0` add a
  penalty to the AI's movement cost function so it routes around hazards.
- **Hazard avoidance**: if the ball carrier's current cell has an active hazard,
  the AI immediately attempts a pass or charges toward a normal cell.
- **Terrain exploitation**: if an opponent is on a hazard cell, the AI prioritises
  engaging them (they're slowed/damaged = easier to tackle).
- **Pit awareness**: the AI treats pit cells as impassable and will not path into them.
- **Trigger timing**: `LearningAi` reward signal gets a +0.2 bonus when an AI
  ability triggers a terrain event that directly leads to a turnover within 3 s.

---

## Implementation Order

```
Phase 1  terrain_grid.dart + terrain_event.dart + GameState.terrain field
Phase 2  terrain_system.dart + wire into game loop
Phase 3  terrain_event_scheduler.dart + wire into TerrainSystem.update
Phase 4  3D rendering — threeQuarter mesh displacement, then full3D vertex buffer
Phase 5  Creature abilities in creature_system.dart
Phase 6  Player abilities in combat_system.dart + player_class.dart
Phase 7  AI pathfinding weights in ai_system.dart
```

Each phase is independently shippable and testable before the next begins.
