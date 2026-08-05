## Unit tests for MatchState singleton — pure data logic, no scene tree needed.
##
## Run headlessly:
##   godot4 --headless --path godot/ tests/MatchStateTest.tscn
extends Node

func _ready() -> void:
	await get_tree().process_frame
	_run_tests()

func _run_tests() -> void:
	var passed := 0
	var failed := 0

	for result in [
		_test_team_for_player_known(),
		_test_team_for_player_unknown(),
		_test_add_score_increments(),
		_test_add_score_emits_signal(),
		_test_living_on_field_excludes_dead(),
		_test_living_on_field_excludes_benched(),
		_test_all_players_for_team_includes_dead_and_benched(),
		_test_team_color_no_config(),
		_test_reset_for_new_match(),
		_test_reset_for_new_act_default_timer(),
		_test_reset_for_new_act_clears_flag(),
		_test_stat_creates_record(),
		_test_stat_returns_same_record(),
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

func _make_player(pid: String, team: int, alive: bool = true, on_field: bool = true) -> MatchState.PlayerRecord:
	var rec := MatchState.PlayerRecord.new()
	rec.player_id    = pid
	rec.team_id      = team
	rec.is_alive     = alive
	rec.is_on_field  = on_field
	rec.class_id     = "wrecker"
	rec.display_name = pid
	return rec

func _reset() -> void:
	MatchState.reset_for_new_match()

# ── Tests ──────────────────────────────────────────────────────────────────────

func _test_team_for_player_known() -> Dictionary:
	const NAME := "team_for_player returns correct team id"
	_reset()
	MatchState.players["p1"] = _make_player("p1", 1)
	var team := MatchState.team_for_player("p1")
	_reset()
	return _r(NAME, team == 1, "" if team == 1 else "expected 1, got %d" % team)

func _test_team_for_player_unknown() -> Dictionary:
	const NAME := "team_for_player returns -1 for unregistered player"
	_reset()
	return _r(NAME, MatchState.team_for_player("nobody") == -1)

func _test_add_score_increments() -> Dictionary:
	const NAME := "add_score increments scores[team]"
	_reset()
	MatchState.add_score(0, 7)
	var s := MatchState.scores[0]
	_reset()
	return _r(NAME, s == 7, "" if s == 7 else "expected 7, got %d" % s)

func _test_add_score_emits_signal() -> Dictionary:
	const NAME := "add_score emits score_display_updated"
	_reset()
	var s := {"fired": false}
	var conn := func(_h: int, _a: int, _t: int): s["fired"] = true
	EventBus.score_display_updated.connect(conn)
	MatchState.add_score(1, 3)
	EventBus.score_display_updated.disconnect(conn)
	var fired: bool = s["fired"]
	_reset()
	return _r(NAME, fired, "" if fired else "score_display_updated not emitted")

func _test_living_on_field_excludes_dead() -> Dictionary:
	const NAME := "living_on_field excludes dead players"
	_reset()
	MatchState.players["alive"] = _make_player("alive", 0, true,  true)
	MatchState.players["dead"]  = _make_player("dead",  0, false, false)
	var living := MatchState.living_on_field(0)
	if living.size() != 1:
		_reset()
		return _r(NAME, false, "expected 1 alive, got %d" % living.size())
	var rec: MatchState.PlayerRecord = living[0]
	var ok: bool = rec.player_id == "alive"
	_reset()
	return _r(NAME, ok, "" if ok else "wrong player: %s" % rec.player_id)

func _test_living_on_field_excludes_benched() -> Dictionary:
	const NAME := "living_on_field excludes alive-but-benched players"
	_reset()
	MatchState.players["field"] = _make_player("field", 0, true, true)
	MatchState.players["bench"] = _make_player("bench", 0, true, false)
	var living := MatchState.living_on_field(0)
	var ok := living.size() == 1
	_reset()
	return _r(NAME, ok, "" if ok else "expected 1, got %d" % living.size())

func _test_all_players_for_team_includes_dead_and_benched() -> Dictionary:
	const NAME := "all_players_for_team includes dead and benched players"
	_reset()
	MatchState.players["p1"] = _make_player("p1", 0, true,  true)
	MatchState.players["p2"] = _make_player("p2", 0, false, false)
	MatchState.players["p3"] = _make_player("p3", 0, true,  false)
	MatchState.players["p4"] = _make_player("p4", 1, true,  true)   # other team, excluded
	var all := MatchState.all_players_for_team(0)
	var ok := all.size() == 3
	_reset()
	return _r(NAME, ok, "" if ok else "expected 3, got %d" % all.size())

func _test_team_color_no_config() -> Dictionary:
	const NAME := "team_color without config returns TEAM_COLOR_PALETTE[team_id]"
	_reset()
	var c := MatchState.team_color(0)
	var expected := MatchState.TEAM_COLOR_PALETTE[0]
	return _r(NAME, c == expected, "" if c == expected else "color mismatch")

func _test_reset_for_new_match() -> Dictionary:
	const NAME := "reset_for_new_match clears scores, kills, players, and match_active"
	MatchState.scores[0]    = 99
	MatchState.kills[1]     = 5
	MatchState.match_active = true
	MatchState.players["p"] = _make_player("p", 0)
	MatchState.reset_for_new_match()
	var ok := MatchState.scores[0] == 0 and MatchState.kills[1] == 0 \
		   and MatchState.players.is_empty() and not MatchState.match_active
	return _r(NAME, ok)

func _test_reset_for_new_act_default_timer() -> Dictionary:
	const NAME := "reset_for_new_act restores act_timer to 180 s (no config)"
	_reset()
	MatchState.act_timer = 0.0
	MatchState.reset_for_new_act()
	var t := MatchState.act_timer
	_reset()
	return _r(NAME, t == 180.0, "" if t == 180.0 else "expected 180, got %f" % t)

func _test_reset_for_new_act_clears_flag() -> Dictionary:
	const NAME := "reset_for_new_act clears act_ended flag"
	_reset()
	MatchState.act_ended = true
	MatchState.reset_for_new_act()
	var ok := not MatchState.act_ended
	_reset()
	return _r(NAME, ok)

func _test_stat_creates_record() -> Dictionary:
	const NAME := "stat() creates a fresh PlayerStatRecord for an unknown player"
	_reset()
	var s := MatchState.stat("newcomer")
	var ok := s != null and s.dmg == 0.0 and s.kills == 0
	_reset()
	return _r(NAME, ok)

func _test_stat_returns_same_record() -> Dictionary:
	const NAME := "stat() returns the same record on repeated calls"
	_reset()
	var s1 := MatchState.stat("p1")
	s1.dmg = 42.0
	var s2 := MatchState.stat("p1")
	var ok := s2.dmg == 42.0
	_reset()
	return _r(NAME, ok, "" if ok else "expected dmg=42, got %f" % s2.dmg)
