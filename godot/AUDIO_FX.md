# Ultraball Audio FX

Sound effects are stubbed and ready to activate. The architecture is wired; only asset files and one project setting are missing.

---

## Quick Activation Checklist

1. **Add a SFX audio bus** in the Godot editor:
   - Open **Project → Project Settings → Audio → Buses**
   - Click **Add Bus**, rename it `SFX`
   - Set its send to `Master`
   - Recommended starting levels: Volume = 0 dB, no effects

2. **Source audio files** (see recommendations below) and place them at:
   ```
   godot/assets/audio/sfx/thunder_01.ogg
   godot/assets/audio/sfx/thunder_02.ogg
   godot/assets/audio/sfx/thunder_03.ogg
   ```
   Files must be `.ogg` (Godot's preferred format for streaming SFX).

3. **Uncomment three lines** in `godot/systems/ThunderAudio.gd`:
   ```gdscript
   # Line 14-18: uncomment the _SOUNDS constant block
   const _SOUNDS: Array[AudioStream] = [
       preload("res://assets/audio/sfx/thunder_01.ogg"),
       preload("res://assets/audio/sfx/thunder_02.ogg"),
       preload("res://assets/audio/sfx/thunder_03.ogg"),
   ]

   # Line 36: uncomment the early-return guard
   if _SOUNDS.is_empty(): return

   # Line 42: uncomment the stream assignment
   player.stream = _SOUNDS.pick_random()

   # Line 48: uncomment the play call
   player.play()
   ```

---

## How It Works

### ThunderAudio (`systems/ThunderAudio.gd`)

A pool of 4 `AudioStreamPlayer` nodes handles polyphonic playback. Chain Lightning fires up to 3 bolts in quick succession — the pool ensures each bounce gets its own player without clipping.

**Timing model:** Thunder is delayed relative to the bolt's visual arrival at the target:

```
bolt fires → (BOLT_TRAVEL_DUR = 0.22s) → visual impact → (+0.05s pad) → thunder plays
```

The pad gives the screen flash time to land before the crack hits. For chain lightning each bounce adds `BOLT_TRAVEL_DUR + CHAIN_INTERVAL (0.34s)` to its delay, so thunder echoes naturally follow the chain.

**Distance model:**

| Parameter | Value | Meaning |
|---|---|---|
| `_SPEED_OF_SOUND` | 12 game units/sec | Exaggerated (real ~340 m/s) for drama |
| `_MAX_VOL_DB` | −6 dB | Volume at point-blank range |
| `_MIN_VOL_DB` | −26 dB | Volume at max audible range |
| `_MAX_RANGE` | 55 game units | Beyond this, thunder is at minimum volume |

**Pitch variation:** Each crack is pitched between 0.88× and 1.14× to avoid mechanical repetition.

### LightningFlashOverlay (`scenes/game/vfx/LightningFlashOverlay.gd`)

A `CanvasLayer` at layer 15 (above the HUD at layer 10) with a full-screen `ColorRect`. Two animations are built programmatically in `_ready()`:

| Animation | Duration | Shape | Use |
|---|---|---|---|
| `bolt_flash` | 0.30s | Sharp spike at 0.55α, decays to 0 by 0.045s | Single bolt (Lightning Bolt, Static Shock) |
| `chain_flash` | 0.45s | Strong spike (0.70α), partial echo at 0.16s | Chain Lightning |

The flash fires at the moment of bolt impact, not at cast time.

---

## Adding Audio for Other Abilities

`ThunderAudio` is currently wired only to lightning bolts (called from `AbilityVfxLayer._spawn_bolt()`). To add SFX for other abilities:

1. Add sound files to `assets/audio/sfx/`
2. Create a new manager (model it on `ThunderAudio`) or extend it with additional `_SOUNDS_*` arrays and a new `play_*` method
3. Instantiate the manager in `GameScene.gd` (same pattern as `ThunderAudio`)
4. Call `play_*()` from the relevant signal handler in `AbilityVfxLayer.gd`

**EventBus signals available for audio hooks:**

| Signal | Good for |
|---|---|
| `ability_resolved` | Cast sounds keyed to ability slot/class |
| `damage_applied` | Hit sounds, impact grunts |
| `healing_applied` | Heal chime or pulse |
| `periodic_hot_applied` | Soft tick sound on each HoT proc |
| `player_died` | Death sound |
| `ultra_scored` | Score fanfare |
| `ball_picked_up` | Pickup click |

---

## Recommended Free Audio Sources

- **Freesound.org** — search "thunder crack" or "lightning strike"; filter by CC0 license
- **OpenGameArt.org** — curated CC0/CC-BY game audio packs
- **Kenney.nl** — Impact Sounds pack includes electrical hits

Prefer mono `.ogg` files at 44100 Hz, −1 dB peak, for best in-engine control over panning and volume.

---

## Folder Layout (target state)

```
godot/assets/
  audio/
    sfx/
      thunder_01.ogg
      thunder_02.ogg
      thunder_03.ogg
      (future: hit_01.ogg, heal_chime.ogg, ...)
  shaders/
    lightning_bolt.gdshader
```
