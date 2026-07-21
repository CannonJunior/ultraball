class_name AiTactics
extends Resource

## Base class for AI tactics — shared helpers for all subclasses.

const PASS_SPEED      := 25.0   # must match BallSystem.PASS_SPEED
const CHARGE_DANGER   := 0.55   # charge_pct threshold for urgent pass
const CREATURE_AVOID  := 6.0    # avoidance radius around creature (m)
const PLAYER_AVOID    := 2.5    # separation radius between AI players (m)
const ATTACK_RANGE_SQ := 16.0   # 4 m radius² for opportunistic ability use

# ── Shared helpers ─────────────────────────────────────────────────────────────

## Movement direction toward target with creature + player avoidance blended in.
func navigate_toward(agent: AiView.PlayerView, target: Vector2, view: AiView) -> Vector2:
	var dir := target - agent.position
	if dir.length_squared() < 0.25:
		dir = Vector2.ZERO
	else:
		dir = dir.normalized()
	return _blend_avoidance(agent, view, dir)

func _blend_avoidance(agent: AiView.PlayerView, view: AiView, dir: Vector2) -> Vector2:
	var avoid := Vector2.ZERO
	for c in view.creatures:
		var diff := agent.position - c.position
		var dsq := diff.length_squared()
		if dsq > 0.0 and dsq < CREATURE_AVOID * CREATURE_AVOID:
			avoid += diff.normalized() * (1.0 - sqrt(dsq) / CREATURE_AVOID) * 2.0
	for p in view.all_players:
		if p.player_id == agent.player_id: continue
		var diff := agent.position - p.position
		var dsq := diff.length_squared()
		if dsq > 0.0 and dsq < PLAYER_AVOID * PLAYER_AVOID:
			avoid += diff.normalized() * (1.0 - sqrt(dsq) / PLAYER_AVOID) * 1.5
	if avoid.length_squared() < 0.01:
		return dir
	var blended := dir + avoid
	if blended.length_squared() < 0.01:
		return dir
	return blended.normalized()

## Count alive enemies within 5 m of agent.
func enemy_pressure(agent: AiView.PlayerView, view: AiView) -> int:
	var count := 0
	for e in view.enemies():
		if not e.is_alive: continue
		if agent.position.distance_squared_to(e.position) < 25.0: count += 1
	return count

## Find the best pass receiver for a holder.
## pass_threshold = metres ahead the receiver must be (ignored when charge is critical).
func find_best_receiver(
	agent: AiView.PlayerView,
	view: AiView,
	pass_threshold: float
) -> AiView.PlayerView:
	var tid := view.requesting_team_id
	var charge_danger := view.ball.charge_pct > CHARGE_DANGER
	var allies := view.allies()
	var enemies := view.enemies()
	var best: AiView.PlayerView = null
	var best_score := -INF

	for ally in allies:
		if ally.player_id == agent.player_id or not ally.is_alive: continue
		var is_ahead: bool
		if charge_danger:
			is_ahead = true
		elif tid == 0:
			is_ahead = ally.position.x > agent.position.x + pass_threshold
		else:
			is_ahead = ally.position.x < agent.position.x - pass_threshold
		if not is_ahead: continue

		var near_enemies := 0
		var closest_sq := INF
		for e in enemies:
			if not e.is_alive: continue
			var sq := ally.position.distance_squared_to(e.position)
			if sq < 25.0: near_enemies += 1
			if sq < closest_sq: closest_sq = sq
		if near_enemies > (1 if charge_danger else 0): continue

		var goal_x := AiStrategy.endzone_x(tid)
		var advance := -absf(ally.position.x - goal_x)
		var openness := minf(sqrt(closest_sq) / 10.0, 2.0)
		var score := advance + openness
		if score > best_score:
			best_score = score
			best = ally

	# Under heavy pressure: take any open teammate regardless of position
	if best == null and enemy_pressure(agent, view) >= 2:
		for ally in allies:
			if ally.player_id == agent.player_id or not ally.is_alive: continue
			var near := 0
			for e in enemies:
				if not e.is_alive: continue
				if ally.position.distance_squared_to(e.position) < 16.0: near += 1
			if near == 0:
				return ally

	return best

## Queue slot 1 (basic attack) when an enemy wanders within attack range.
func try_queue_ability(agent: AiView.PlayerView, view: AiView, input: InputState) -> void:
	for e in view.enemies():
		if not e.is_alive or e.is_stunned: continue
		if agent.position.distance_squared_to(e.position) < ATTACK_RANGE_SQ:
			input.queued_ability_slot = 1
			return

# ── Override in subclass ───────────────────────────────────────────────────────

func produce_input(
	agent: AiView.PlayerView,
	goal: Vector2,
	view: AiView,
	policy: Dictionary
) -> InputState:
	push_error("AiTactics.produce_input() not implemented: " + resource_path)
	return InputState.new()
