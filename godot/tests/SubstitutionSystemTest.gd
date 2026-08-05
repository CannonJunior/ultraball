## Unit tests for SubstitutionSystem — death marking, sub-in flow, act-end revival.
##
## Run headlessly:
##   godot4 --headless --path godot/ tests/SubstitutionSystemTest.tscn
extends Node

var _sys: Node = null

func _ready() -> void:
	_sys = load("res://systems/SubstitutionSystem.gd").new()
	add_child(_sys)
	await get_tree().process_frame
	_run_tests()

func _run_tests() -> void:
	var passed := 0
	var failed := 0

	for result in [
		await _test_death_marks_player_dead_and_off_field(),
		await _test_first_death_triggers_sub_in(),
		await _test_second_death_same_act_no_sub(),
		await _test_reserve_lowest_deploy_slot_first(),
		await _test_act5_every_death_triggers_sub(),
		await _test_roster_depleted_no_crash(),
		await _test_act_started_resets_subs_used(),
		await _test_act_ended_revives_dead_players(),
	]:
		if result.ok:
			passed += 1
			print("PASS  ", result.name)
		else:
			failed += 1
			print("FAIL  ", result.name, " — ", result.msg)

	print("")
	print("Results: %d passed, %d failed" % [passed, failed])
	get_tree().quit(1 if failed > 0 else 0)

func _r(name: String, ok: bool, msg: String = "") -> Dictionary:
	return {"name": name, "ok": ok, "msg": msg}

func _make_player(pid: String, team: int, alive: bool = true, on_field: bool = true, deploy_slot: int = 0) -> MatchState.PlayerRecord:
	var rec := MatchState.PlayerRecord.new()
	rec.player_id    = pid
	rec.team_id      = team
	rec.is_alive     = alive
	rec.is_on_field  = on_field
	rec.class_id     = "wrecker"
	rec.display_name = pid
	rec.deploy_slot  = deploy_slot
	return rec

func _reset() -> void:
	MatchState.reset_for_new_match()
	MatchState.current_act = 1
	_sys._subs_used.clear()

# ── Tests ──────────────────────────────────────────────────────────────────────

func _test_death_marks_player_dead_and_off_field() -> Dictionary:
	const NAME := "player_died marks player is_alive=false and is_on_field=false"
	_reset()
	MatchState.players["p"] = _make_player("p", 0, true, true)
	EventBus.player_died.emit("p", "combat", "")
	await get_tree().process_frame
	var rec: MatchState.PlayerRecord = MatchState.players["p"]
	var ok := not rec.is_alive and not rec.is_on_field
	_reset()
	return _r(NAME, ok, "" if ok else "alive=%s on_field=%s" % [rec.is_alive, rec.is_on_field])

func _test_first_death_triggers_sub_in() -> Dictionary:
	const NAME := "first death (act 1) subs in reserve player"
	_reset()
	MatchState.players["field"]   = _make_player("field",   0, true,  true,  0)
	MatchState.players["reserve"] = _make_player("reserve", 0, true,  false, 1)
	EventBus.player_died.emit("field", "combat", "")
	await get_tree().process_frame
	var reserve: MatchState.PlayerRecord = MatchState.players["reserve"]
	var ok := reserve.is_on_field
	_reset()
	return _r(NAME, ok, "" if ok else "reserve is_on_field=%s" % reserve.is_on_field)

func _test_second_death_same_act_no_sub() -> Dictionary:
	const NAME := "second death same team same act does not trigger another sub (acts 1-4)"
	_reset()
	MatchState.players["f1"] = _make_player("f1", 0, true,  true,  0)
	MatchState.players["f2"] = _make_player("f2", 0, true,  true,  1)
	MatchState.players["r1"] = _make_player("r1", 0, true,  false, 2)
	MatchState.players["r2"] = _make_player("r2", 0, true,  false, 3)
	EventBus.player_died.emit("f1", "combat", "")   # first death → r1 subs in
	await get_tree().process_frame
	EventBus.player_died.emit("f2", "combat", "")   # second death → NO sub
	await get_tree().process_frame
	var r2: MatchState.PlayerRecord = MatchState.players["r2"]
	var ok := not r2.is_on_field
	_reset()
	return _r(NAME, ok, "" if ok else "r2 unexpectedly subbed in on second death")

func _test_reserve_lowest_deploy_slot_first() -> Dictionary:
	const NAME := "reserve with lowest deploy_slot is chosen when multiple are available"
	_reset()
	MatchState.players["field"] = _make_player("field", 0, true,  true,  0)
	MatchState.players["r_hi"]  = _make_player("r_hi",  0, true,  false, 9)
	MatchState.players["r_lo"]  = _make_player("r_lo",  0, true,  false, 2)
	EventBus.player_died.emit("field", "combat", "")
	await get_tree().process_frame
	var r_lo: MatchState.PlayerRecord = MatchState.players["r_lo"]
	var r_hi: MatchState.PlayerRecord = MatchState.players["r_hi"]
	var ok := r_lo.is_on_field and not r_hi.is_on_field
	_reset()
	return _r(NAME, ok, "" if ok else "r_lo.on_field=%s r_hi.on_field=%s" % [r_lo.is_on_field, r_hi.is_on_field])

func _test_act5_every_death_triggers_sub() -> Dictionary:
	const NAME := "act 5: every death triggers a sub-in"
	_reset()
	MatchState.current_act = 5
	MatchState.players["f1"] = _make_player("f1", 0, true,  true,  0)
	MatchState.players["f2"] = _make_player("f2", 0, true,  true,  1)
	MatchState.players["r1"] = _make_player("r1", 0, true,  false, 2)
	MatchState.players["r2"] = _make_player("r2", 0, true,  false, 3)
	EventBus.player_died.emit("f1", "combat", "")
	await get_tree().process_frame
	EventBus.player_died.emit("f2", "combat", "")
	await get_tree().process_frame
	var r1: MatchState.PlayerRecord = MatchState.players["r1"]
	var r2: MatchState.PlayerRecord = MatchState.players["r2"]
	var ok := r1.is_on_field and r2.is_on_field
	_reset()
	return _r(NAME, ok, "" if ok else "r1.on_field=%s r2.on_field=%s" % [r1.is_on_field, r2.is_on_field])

func _test_roster_depleted_no_crash() -> Dictionary:
	const NAME := "roster depleted: player dies with no reserve — no crash"
	_reset()
	MatchState.players["lone"] = _make_player("lone", 0, true, true, 0)
	EventBus.player_died.emit("lone", "combat", "")
	await get_tree().process_frame
	# If we reach here without crashing, the test passes.
	var lone: MatchState.PlayerRecord = MatchState.players["lone"]
	var ok := not lone.is_alive
	_reset()
	return _r(NAME, ok)

func _test_act_started_resets_subs_used() -> Dictionary:
	const NAME := "act_started clears subs_used, allowing a sub in the new act"
	_reset()
	# Use first sub in act 1
	MatchState.players["f1"] = _make_player("f1", 0, true,  true,  0)
	MatchState.players["r1"] = _make_player("r1", 0, true,  false, 1)
	EventBus.player_died.emit("f1", "combat", "")
	await get_tree().process_frame
	# Advance to act 2
	MatchState.current_act = 2
	EventBus.act_started.emit(2)   # clears _subs_used
	await get_tree().process_frame
	# Kill another player — sub should be available again
	MatchState.players["f2"] = _make_player("f2", 0, true,  true,  2)
	MatchState.players["r2"] = _make_player("r2", 0, true,  false, 3)
	EventBus.player_died.emit("f2", "combat", "")
	await get_tree().process_frame
	var r2: MatchState.PlayerRecord = MatchState.players["r2"]
	var ok := r2.is_on_field
	_reset()
	return _r(NAME, ok, "" if ok else "r2 not subbed in despite new act")

func _test_act_ended_revives_dead_players() -> Dictionary:
	const NAME := "act_ended revives all dead players and fills field to players_per_side"
	_reset()
	# Two dead players; one already on field
	MatchState.players["alive"] = _make_player("alive", 0, true,  true,  0)
	MatchState.players["dead1"] = _make_player("dead1", 0, false, false, 1)
	MatchState.players["dead2"] = _make_player("dead2", 0, false, false, 2)
	# Emit act_ended (SubstitutionSystem handles revival; config is null so pps=7)
	EventBus.act_ended.emit(1, 0, 0, 0)
	await get_tree().process_frame
	var d1: MatchState.PlayerRecord = MatchState.players["dead1"]
	var d2: MatchState.PlayerRecord = MatchState.players["dead2"]
	var ok := d1.is_alive and d2.is_alive
	_reset()
	return _r(NAME, ok, "" if ok else "dead1.alive=%s dead2.alive=%s" % [d1.is_alive, d2.is_alive])
