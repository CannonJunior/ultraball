# Ability Hotkey Styling Guide

Ability slots in the HUD communicate what each ability does at a glance through two
independent visual channels: **background colour** (primary effect) and **border colour**
(secondary / rider effects). A player switching to an unfamiliar character can read
the slot grid and immediately understand what each key does before memorising names.

---

## Ability Ontology

Drawn from PVP games (World of Warcraft, SMITE, League of Legends, Overwatch) and
extended for Ultraball's unique mechanics.

### Primary Effect Categories

| Category | Definition | Examples (WoW analogy) | Ultraball examples |
|---|---|---|---|
| **Direct Damage** | Single hit that reduces target HP | Fireball, Sinister Strike | Volt, Iron Fist, Stonefist |
| **AoE Damage** | Damage applied to multiple enemies in an area | Blizzard, Rain of Fire, Starfall | Tremor, Shockwave, Ground Pound |
| **Damage over Time** | Repeated damage ticks applied to target | Ignite, Corruption, Rip | *(reserved for future DoT effects)* |
| **Direct Heal** | Instant HP restoration to self or ally | Flash Heal, Word of Glory | Mend, Refresh, Cascade |
| **Heal over Time** | Repeated healing ticks (HoT) | Rejuvenation, Renew, Regrowth | Infuse, Verdure, Sanctuary |
| **Self Buff** | Timed improvement to own stats (speed, damage, defence, immunity) | Bloodlust, Ice Barrier, Inner Fire | Ghost, Sprint, Stone Armor |
| **Ally Support** | Buff or resource restoration targeting a teammate | Power Word: Fortitude, Mana Tide | Empower, Fortify, Bulwark (Vitalist) |
| **Crowd Control** | Effect that restricts enemy actions: stun, knockback, confusion, pull | Polymorph, Kidney Shot, Charge | Sledge, Death Blow, Charge (Archon) |
| **Snare** | Speed reduction without full loss of control | Frostbolt, Hamstring, Earthbind | Slide Tackle, Fault Line, Crumple |
| **Debuff** | Stat penalty, mark, or resource drain on target | Curse of Weakness, Hex, Mortal Strike | Hex Strike, Mark (Corsair), Jinx |
| **Movement** | Repositions the caster without dealing damage | Blink, Heroic Leap, Shadowstep | Phase, Cutback, Aggressive Rush |
| **Terrain** | Alters the physical playing field or spawns a persistent hazard | Earthgrab Totem, Shockwave (terrain) | Raise Hill, Quagmire, Fissure |
| **Utility** | Cleanse, mana restore, buff extension, or creature manipulation | Dispel Magic, Innervate, Soulstone | Energize, Prolong, Creature Goad |
| **Ultra** | Slot-10 signature ability, fuelled by Ultra mana | Metamorphosis, Avenging Wrath | Ultraviolet, Demolish, Verdure |

### Secondary / Rider Effects (border indicators)

A secondary effect is something an ability does *in addition* to its primary function — the
"and also" that makes an ability more complex or dangerous.

| Border | Triggered by | Meaning |
|---|---|---|
| **Hard CC** | Stun · Knockback · Pull · Confusion | Target loses positional or directional control |
| **Snare** | SnareEffect | Target is slowed (retains movement, no full lock) |
| **Debuff modifier** | Hex · Mark | Target's damage output or damage taken is altered |
| **Ball interaction** | Fumble | Forces the ball to drop (unique Ultraball mechanic) |
| **Mana drain** | ManaDrainEffect | Depletes target's mana pool |

> Borders are only shown for *secondary* effects. If CC is the primary function of an ability
> (and therefore already shown through the background colour) the border is not repeated.

---

## Colour Scheme

### Background colours (primary effect)

| Category | Colour swatch | GDScript constant | Rationale |
|---|---|---|---|
| Direct Damage | ![#61100F](https://placehold.co/16x16/61100F/61100F.png) Dark crimson | `SLOT_BG_DAMAGE` | Red = harm |
| AoE Damage | ![#662804](https://placehold.co/16x16/662804/662804.png) Dark amber-red | `SLOT_BG_AOE_DMG` | Redder-orange = wider harm |
| Heal | ![#0F5215](https://placehold.co/16x16/0F5215/0F5215.png) Dark forest green | `SLOT_BG_HEAL` | Green = life/recovery |
| HoT | ![#0A423A](https://placehold.co/16x16/0A423A/0A423A.png) Dark teal | `SLOT_BG_HOT` | Teal = sustained life |
| Self Buff | ![#0F1A61](https://placehold.co/16x16/0F1A61/0F1A61.png) Dark royal blue | `SLOT_BG_SELF_BUFF` | Blue = empowerment |
| Ally Support | ![#0A3857](https://placehold.co/16x16/0A3857/0A3857.png) Dark cyan | `SLOT_BG_SUPPORT` | Cyan = team care |
| Movement | ![#2E0757](https://placehold.co/16x16/2E0757/2E0757.png) Dark violet | `SLOT_BG_MOVEMENT` | Purple = speed/phase |
| Debuff | ![#380747](https://placehold.co/16x16/380747/380747.png) Dark magenta | `SLOT_BG_DEBUFF` | Purple-red = corruption |
| Crowd Control | ![#524004](https://placehold.co/16x16/524004/524004.png) Dark amber | `SLOT_BG_CC` | Amber = caution/lock |
| Terrain | ![#331F04](https://placehold.co/16x16/331F04/331F04.png) Dark earth | `SLOT_BG_TERRAIN` | Brown = ground/earth |
| Utility | ![#1A1F33](https://placehold.co/16x16/1A1F33/1A1F33.png) Dark slate | `SLOT_BG_UTILITY` | Neutral = general purpose |
| Ultra | ![#4D3804](https://placehold.co/16x16/4D3804/4D3804.png) Dark gold | `SLOT_BG_ULTRA` | Gold = ultimate power |

### Border colours (secondary effect)

Borders are bright and vivid so they are legible on dark backgrounds.

| Secondary effect | Colour swatch | GDScript constant |
|---|---|---|
| Hard CC | ![#E6BF00](https://placehold.co/16x16/E6BF00/E6BF00.png) Bright amber | `SLOT_BORDER_HARD_CC` |
| Snare | ![#E66600](https://placehold.co/16x16/E66600/E66600.png) Bright orange | `SLOT_BORDER_SNARE` |
| Debuff modifier | ![#CC1ACC](https://placehold.co/16x16/CC1ACC/CC1ACC.png) Magenta | `SLOT_BORDER_DEBUFF` |
| Ball interaction | ![#E6B20D](https://placehold.co/16x16/E6B20D/E6B20D.png) Gold | `SLOT_BORDER_FUMBLE` |
| Mana drain | ![#2659E6](https://placehold.co/16x16/2659E6/2659E6.png) Bright blue | `SLOT_BORDER_MANA` |

---

## Classification Algorithm

The classifier (`CharacterPanel._classify_slot_style`) inspects each ability's `effects`
array using GDScript `is` type-checks. Classification is performed once per player-change
and cached per slot.

### Primary background priority (first match wins)

1. `mana_type == 4` → **Ultra**
2. `AoEDamageEffect` present → **AoE Damage**
3. `DamageEffect` present → **Direct Damage** (even if a dash delivers it)
4. `HoTEffect` or `PeriodicHoTEffect` present → **HoT**
5. `HealEffect` or `AoEHealEffect` present → **Heal**
6. `DashEffect` or `TeleportEffect` present, **and no damage effect** → **Movement**
7. Any buff effect (`SpeedBoostEffect`, `DamageBoostEffect`, `DamageReductionEffect`,
   `InvulnerabilityEffect`, `StunImmuneEffect`), `target_mode == NearestAlly` → **Ally Support**
8. Any buff effect, self-targeted → **Self Buff**
9. `TerrainShapeEffect` or `TrapSpawnEffect` present → **Terrain**
10. `HexEffect`, `MarkEffect`, `ManaDrainEffect`, or `FumbleEffect` present → **Debuff**
11. `StunEffect`, `KnockbackEffect`, `PullEffect`, `ConfusionEffect`, or `SnareEffect` → **CC**
12. Anything else → **Utility**

### Secondary border priority (first match, only if not already the primary)

1. `StunEffect` · `KnockbackEffect` · `PullEffect` · `ConfusionEffect` → **Hard CC**
   *(suppressed when background is already CC)*
2. `SnareEffect` → **Snare** *(suppressed when background is CC)*
3. `HexEffect` or `MarkEffect` → **Debuff modifier** *(suppressed when background is Debuff)*
4. `FumbleEffect` → **Ball interaction** *(suppressed when background is Debuff)*
5. `ManaDrainEffect` → **Mana drain** *(suppressed when background is Debuff)*

---

## Out-of-Range State

When an ability is off cooldown but the current target is outside its range:
- Background: classified colour darkened by 45 % (hue preserved, clearly inactive)
- Border: classified border darkened by 45 %
- Text: `⊘` replaces the cooldown timer

This preserves category readability while signalling the ability cannot fire.

---

## Quick-Reference: All Ultraball Abilities

| Class | Slot | Name | Background | Border |
|---|---|---|---|---|
| Archon | 1 | Stonefist | Damage | Hard CC |
| Archon | 2 | Fault Line | Damage | Snare |
| Archon | 3 | Sprint | Self Buff | — |
| Archon | 4 | Bulwark | Self Buff | — |
| Archon | 5 | Mend | Heal | — |
| Archon | 6 | Charge | Damage | Hard CC |
| Archon | 7 | Second Wind | Heal | — |
| Archon | 8 | Fortify | Ally Support | — |
| Archon | 9 | Rally | Heal | — |
| Archon | 10 | SANCTUARY | Ultra | — |
| Corsair | 1 | Blitz Strike | Damage | — |
| Corsair | 2 | Strip Tackle | Damage | Hard CC + Fumble |
| Corsair | 3 | Sprint | Self Buff | — |
| Corsair | 4 | Aggressive Rush | Movement | Snare |
| Corsair | 5 | Pack Hunter | Self Buff | — |
| Corsair | 6 | Clothesline | Damage | Hard CC |
| Corsair | 7 | Mark | Debuff | — |
| Corsair | 8 | Intimidate | CC | — |
| Corsair | 9 | Creature Bait | CC | Debuff modifier |
| Corsair | 10 | BLOOD RUSH | Ultra | — |
| Geomancer | 1 | Earth Fist | Damage | — |
| Geomancer | 2 | Raise Hill | Terrain | — |
| Geomancer | 3 | Seismic Shove | Damage | Hard CC |
| Geomancer | 4 | Quagmire | Terrain | — |
| Geomancer | 5 | Tremor | AoE Damage | Snare |
| Geomancer | 6 | Stone Armor | Self Buff | — |
| Geomancer | 7 | Earthmend | Heal | — |
| Geomancer | 8 | Crevasse | Terrain | — |
| Geomancer | 9 | Fissure | Terrain | — |
| Geomancer | 10 | TERRA NOVA | Ultra | — |
| Spectre | 1 | Volt | Damage | — |
| Spectre | 2 | Slide Tackle | Damage | Snare |
| Spectre | 3 | Sprint | Self Buff | — |
| Spectre | 4 | Phase | Movement | — |
| Spectre | 5 | Ghost | Self Buff | — |
| Spectre | 6 | Eye Gouge | Damage | Hard CC |
| Spectre | 7 | Clear Out | Heal | — |
| Spectre | 8 | Cutback | Movement | Snare |
| Spectre | 9 | Feint | Self Buff | — |
| Spectre | 10 | ULTRAVIOLET | Ultra | — |
| Trickster | 1 | Hex Strike | Damage | Debuff modifier |
| Trickster | 2 | Phantom Step | Movement | — |
| Trickster | 3 | Fox Sprint | Self Buff | — |
| Trickster | 4 | Befuddle | Debuff | Hard CC |
| Trickster | 5 | Creature Goad | Utility | — |
| Trickster | 6 | Position Swap | Utility | — |
| Trickster | 7 | Jinx | CC | Mana drain |
| Trickster | 8 | Hex Nova | Debuff | — |
| Trickster | 9 | Chaos Fumble | Debuff | Hard CC |
| Trickster | 10 | PANDEMONIUM | Ultra | — |
| Vitalist | 1 | Tap | Damage | — |
| Vitalist | 2 | Mend | HoT | — |
| Vitalist | 3 | Infuse | HoT | — |
| Vitalist | 4 | Empower | Ally Support | — |
| Vitalist | 5 | Bulwark | Ally Support | — |
| Vitalist | 6 | Refresh | Heal | — |
| Vitalist | 7 | Cascade | Heal | — |
| Vitalist | 8 | Rebuke | Damage | Hard CC + Fumble |
| Vitalist | 9 | Prolong | Utility | — |
| Vitalist | 10 | VERDURE | Ultra | — |
| Warden | 1 | Quick Jab | Damage | — |
| Warden | 2 | Ankle Snap | Damage | Snare |
| Warden | 3 | Field Medic | Heal | — |
| Warden | 4 | Energize | Utility | — |
| Warden | 5 | Sprint | Self Buff | — |
| Warden | 6 | Suppress | Damage | Hard CC |
| Warden | 7 | Trauma Pack | Heal | — |
| Warden | 8 | Team Rally | Utility | — |
| Warden | 9 | Intercept | Damage | Hard CC |
| Warden | 10 | GAME PLAN | Ultra | — |
| Wrecker | 1 | Iron Fist | Damage | — |
| Wrecker | 2 | Sledge | Damage | Hard CC |
| Wrecker | 3 | Bull Rush | Damage | Hard CC |
| Wrecker | 4 | Crumple | Damage | Snare |
| Wrecker | 5 | Shockwave | AoE Damage | Hard CC |
| Wrecker | 6 | Spine Breaker | Damage | Hard CC |
| Wrecker | 7 | Wrecking Ball | AoE Damage | Hard CC |
| Wrecker | 8 | Ground Pound | AoE Damage | Hard CC |
| Wrecker | 9 | Death Blow | Damage | Hard CC |
| Wrecker | 10 | DEMOLISH | Ultra | Hard CC |
