extends Node

# ── Ability System ─────────────────────────────────────────────────────────────
signal ability_used(caster_id: String, slot: int)
signal ability_resolved(caster_id: String, slot: int, hit_ids: Array)
signal ability_failed(caster_id: String, slot: int, reason: String)
signal ability_queued(player_id: String, slot: int)
signal gcd_started(player_id: String, duration: float)

# ── Damage and Death ───────────────────────────────────────────────────────────
## payload keys: attacker_id, target_id, amount, knockback_distance, facing
signal damage_requested(payload: Dictionary)
signal damage_applied(attacker_id: String, target_id: String, amount: float, is_kill: bool)
signal healing_applied(healer_id: String, target_id: String, amount: float)
## cause: "combat" | "pit" | "creature" | "explosion"
signal player_died(player_id: String, cause: String, killer_id: String)
signal player_subbed_in(player_id: String, replaced_id: String, team_id: int)

# ── Ball System ────────────────────────────────────────────────────────────────
signal ball_picked_up(player_id: String)
## cause: "fumble" | "throw" | "death" | "explosion"
signal ball_dropped(position: Vector2, cause: String)
## Player requests a throw — BallSystem validates and executes.
signal throw_requested(thrower_id: String, direction: Vector2, is_charged: bool)
signal ball_thrown(thrower_id: String, target_position: Vector2, is_charged: bool)
signal ball_caught(catcher_id: String)
signal ball_phase_line_crossed(team_id: int, line_index: int)
signal ball_entered_endzone_3t(holder_id: String)
signal ball_exploded(holder_id: String)
signal ball_possession_changed(new_holder_id: String, team_id: int)
## Fired after Ultra/Meta score or act transition — ball snapped to centre.
signal ball_reset(new_position: Vector2)
## Fired at act transitions — all players should return to start positions.
signal positions_reset()

# ── Scoring ────────────────────────────────────────────────────────────────────
signal ultra_scored(team_id: int, scorer_id: String)
signal meta_scored(team_id: int, scorer_id: String)
signal killa_scored(team_id: int, killer_id: String, victim_id: String)

# ── Act Management ─────────────────────────────────────────────────────────────
signal act_started(act_number: int)
signal act_ended(act_number: int, home_score: int, away_score: int, third_score: int)
signal act_transition_complete(next_act: int)
signal game_over(winner_team_id: int, final_home: int, final_away: int, final_third: int)

# ── Terrain ────────────────────────────────────────────────────────────────────
## event_type: "hill" | "valley" | "mud" | "lava" | "ice" | "pit" | "shockwave"
signal terrain_modified(event_type: String, world_pos: Vector2, radius: float, duration: float, intensity: float)
signal pit_opened(world_pos: Vector2, radius: float, duration: float)
signal terrain_reset(cell_col: int, cell_row: int)
signal trap_spawn_requested(world_pos: Vector2, owner_team_id: int, trap_radius: float, snare_duration: float, slow_factor: float, trap_timer: float)

# ── Creature ───────────────────────────────────────────────────────────────────
signal creature_killed_player(victim_id: String, team_id: int)
signal creature_goaded(target_player_id: String, duration: float)
signal creature_direction_reversed(duration: float)

# ── Status Effects ─────────────────────────────────────────────────────────────
signal buff_applied(player_id: String, buff_name: String, duration: float)
signal debuff_applied(player_id: String, debuff_name: String, duration: float, params: Dictionary)
signal periodic_hot_applied(payload: Dictionary)

# ── Network ────────────────────────────────────────────────────────────────────
signal peer_connected(peer_id: int)
signal peer_disconnected(peer_id: int)
signal lobby_created(lobby_id: int)
signal lobby_joined(lobby_id: int)
signal match_starting(config: Resource)

# ── UI Feedback (logic → HUD only; HUD never emits back to logic) ──────────────
signal event_message_shown(message: String, duration: float)
signal combo_message_shown(message: String)
signal damage_indicator_spawned(world_pos: Vector2, text: String, indicator_type: String)
signal throw_charge_changed(charge_pct: float)
signal act_timer_changed(seconds_remaining: float)
signal score_display_updated(home: int, away: int, third: int)
