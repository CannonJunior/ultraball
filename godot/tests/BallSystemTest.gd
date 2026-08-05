## Unit tests for BallSystem — throw, explosion, reset, boundary bounce, phase lines.
##
## BallSystem._physics_process is suppressed by keeping MatchState.match_active = false
## throughout; each test directly calls the method under test.
##
## Run headlessly:
##   godot4 --headless --path godot/ tests/BallSystemTest.tscn
extends Node

var _sys: Node = null

func _ready() -> void:
	_sys = load("res://systems/BallSystem.gd").new()
	add_child(_sys)
	await get_tree().process_frame
	_run_tests()

func _run_tests() -> void:
	var passed := 0
	var failed := 0

	for result in [
		_test_throw_ball_sets_in_flight(),
		_test_throw_ball_clears_holder(),
		_test_throw_ball_wrong_holder_is_noop(),
		_test_charged_throw_sets_z_velocity(),
		_test_regular_throw_has_no_z_velocity(),
		_test_throw_ball_emits_ball_thrown(),
		_test_explode_ball_clears_holder(),
		_test_explode_ball_emits_signals(),
		_test_reset_ball_to_centre_2team(),
		_test_on_ball_dropped_clears_holder(),
		_test_on_ball_dropped_sets_position(),
		_test_boundary_bounce_left_edge(),
		_test_boundary_bounce_top_edge(),
		_test_phase_line_crossing_emits_signal(),
		_test_phase_line_resets_charge_timer(),
		_test_phase_line_already_crossed_not_re_emitted(),
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

func _reset() -> void:
	MatchState.reset_for_new_match()
	MatchState.is_three_team = false
	MatchState.match_active  = false
	_sys._prev_ball_x = 70.0
	_sys._prev_ball_pos = Vector2(70.0, 20.0)

## Set all 5 two-team phase line flags to the given value via element assignment
## (avoids the typed-array full-reassignment limitation from external scripts).
func _set_phase_lines(armed: bool) -> void:
	for i in 5:
		_sys._phase_lines_activated[i] = armed

func _ball() -> MatchState.BallStateRecord:
	return MatchState.ball

func _make_player_record(pid: String, team: int) -> MatchState.PlayerRecord:
	var rec := MatchState.PlayerRecord.new()
	rec.player_id    = pid
	rec.team_id      = team
	rec.is_alive     = true
	rec.is_on_field  = true
	rec.class_id     = "wrecker"
	rec.display_name = pid
	return rec

# ── Throw ─────────────────────────────────────────────────────────────────────

func _test_throw_ball_sets_in_flight() -> Dictionary:
	const NAME := "throw_ball sets ball.is_in_flight = true"
	_reset()
	_ball().holder_id = "p1"
	_sys.throw_ball("p1", Vector2.RIGHT, 20.0, false)
	var ok: bool = _ball().is_in_flight
	_reset()
	return _r(NAME, ok)

func _test_throw_ball_clears_holder() -> Dictionary:
	const NAME := "throw_ball clears ball.holder_id"
	_reset()
	_ball().holder_id = "p1"
	_sys.throw_ball("p1", Vector2.RIGHT, 20.0, false)
	var ok: bool = _ball().holder_id.is_empty()
	_reset()
	return _r(NAME, ok, "" if ok else "holder_id='%s'" % _ball().holder_id)

func _test_throw_ball_wrong_holder_is_noop() -> Dictionary:
	const NAME := "throw_ball ignores request when thrower is not the holder"
	_reset()
	_ball().holder_id    = "p2"
	_ball().is_in_flight = false
	_sys.throw_ball("p1", Vector2.RIGHT, 20.0, false)
	var ok: bool = not _ball().is_in_flight and _ball().holder_id == "p2"
	_reset()
	return _r(NAME, ok, "" if ok else "ball state changed despite wrong holder")

func _test_charged_throw_sets_z_velocity() -> Dictionary:
	const NAME := "charged throw sets ball.z_velocity > 0"
	_reset()
	_ball().holder_id = "p1"
	_sys.throw_ball("p1", Vector2.RIGHT, 20.0, true)
	var ok: bool = _ball().z_velocity > 0.0
	_reset()
	return _r(NAME, ok, "" if ok else "z_velocity=%.3f" % _ball().z_velocity)

func _test_regular_throw_has_no_z_velocity() -> Dictionary:
	const NAME := "regular (non-charged) throw leaves ball.z_velocity = 0"
	_reset()
	_ball().holder_id = "p1"
	_sys.throw_ball("p1", Vector2.RIGHT, 25.0, false)
	var ok: bool = _ball().z_velocity == 0.0
	_reset()
	return _r(NAME, ok, "" if ok else "z_velocity=%.3f" % _ball().z_velocity)

func _test_throw_ball_emits_ball_thrown() -> Dictionary:
	const NAME := "throw_ball emits ball_thrown signal"
	_reset()
	_ball().holder_id = "p1"
	var s := {"fired": false}
	var conn := func(_tid: String, _pos: Vector2, _charged: bool): s["fired"] = true
	EventBus.ball_thrown.connect(conn)
	_sys.throw_ball("p1", Vector2.RIGHT, 20.0, false)
	EventBus.ball_thrown.disconnect(conn)
	var fired: bool = s["fired"]
	_reset()
	return _r(NAME, fired, "" if fired else "ball_thrown not emitted")

# ── Explosion ─────────────────────────────────────────────────────────────────

func _test_explode_ball_clears_holder() -> Dictionary:
	const NAME := "_explode_ball clears ball.holder_id"
	_reset()
	MatchState.players["holder"] = _make_player_record("holder", 0)
	_ball().holder_id = "holder"
	_sys.call("_explode_ball", _ball())
	var ok: bool = _ball().holder_id.is_empty()
	_reset()
	return _r(NAME, ok, "" if ok else "holder_id='%s'" % _ball().holder_id)

func _test_explode_ball_emits_signals() -> Dictionary:
	const NAME := "_explode_ball emits ball_exploded and player_died for holder"
	_reset()
	MatchState.players["holder"] = _make_player_record("holder", 0)
	_ball().holder_id = "holder"
	var s := {"exploded_id": "", "died_id": ""}
	var conn_ex := func(hid: String): s["exploded_id"] = hid
	var conn_di := func(pid: String, _c: String, _k: String): s["died_id"] = pid
	EventBus.ball_exploded.connect(conn_ex)
	EventBus.player_died.connect(conn_di)
	_sys.call("_explode_ball", _ball())
	EventBus.ball_exploded.disconnect(conn_ex)
	EventBus.player_died.disconnect(conn_di)
	var ok: bool = s["exploded_id"] == "holder" and s["died_id"] == "holder"
	_reset()
	return _r(NAME, ok, "" if ok else "exploded_id='%s' died_id='%s'" % [s["exploded_id"], s["died_id"]])

# ── Reset ─────────────────────────────────────────────────────────────────────

func _test_reset_ball_to_centre_2team() -> Dictionary:
	const NAME := "_reset_ball_to_centre places ball at (70, 20) in 2-team mode"
	_reset()
	MatchState.is_three_team = false
	_ball().position  = Vector2(5.0, 35.0)
	_ball().holder_id = "p1"
	_sys.call("_reset_ball_to_centre")
	var ok: bool = _ball().position.is_equal_approx(Vector2(70.0, 20.0)) \
		       and _ball().holder_id.is_empty()
	_reset()
	return _r(NAME, ok, "" if ok else "position=%s" % _ball().position)

# ── Ball-dropped handler ───────────────────────────────────────────────────────

func _test_on_ball_dropped_clears_holder() -> Dictionary:
	const NAME := "ball_dropped signal clears ball.holder_id, is_in_flight, and charge_timer"
	_reset()
	_ball().holder_id    = "p1"
	_ball().is_in_flight = true
	_ball().charge_timer = 3.5
	EventBus.ball_dropped.emit(Vector2(10.0, 10.0), "fumble")
	var ok: bool = _ball().holder_id.is_empty() and not _ball().is_in_flight \
		       and _ball().charge_timer == 0.0
	_reset()
	return _r(NAME, ok, "" if ok else "holder='%s' in_flight=%s" % [_ball().holder_id, _ball().is_in_flight])

func _test_on_ball_dropped_sets_position() -> Dictionary:
	const NAME := "ball_dropped signal moves ball to the given non-zero position"
	_reset()
	_ball().position = Vector2(70.0, 20.0)
	var drop_pos := Vector2(15.0, 8.0)
	EventBus.ball_dropped.emit(drop_pos, "death")
	var ok: bool = _ball().position.is_equal_approx(drop_pos)
	_reset()
	return _r(NAME, ok, "" if ok else "position=%s expected %s" % [_ball().position, drop_pos])

# ── Boundary bounce ───────────────────────────────────────────────────────────

func _test_boundary_bounce_left_edge() -> Dictionary:
	const NAME := "_bounce_ball_at_boundary clamps to x=0 and zeroes x velocity"
	_reset()
	_ball().position = Vector2(-2.5, 10.0)
	_ball().velocity = Vector2(-8.0, 3.0)
	_sys.call("_bounce_ball_at_boundary", _ball())
	var ok: bool = _ball().position.x == 0.0 and _ball().velocity.x == 0.0
	_reset()
	return _r(NAME, ok, "" if ok else "pos.x=%.2f vel.x=%.2f" % [_ball().position.x, _ball().velocity.x])

func _test_boundary_bounce_top_edge() -> Dictionary:
	const NAME := "_bounce_ball_at_boundary clamps to y=0 and zeroes y velocity"
	_reset()
	_ball().position = Vector2(70.0, -3.0)
	_ball().velocity = Vector2(5.0, -4.0)
	_sys.call("_bounce_ball_at_boundary", _ball())
	var ok: bool = _ball().position.y == 0.0 and _ball().velocity.y == 0.0
	_reset()
	return _r(NAME, ok, "" if ok else "pos.y=%.2f vel.y=%.2f" % [_ball().position.y, _ball().velocity.y])

# ── Phase line detection ───────────────────────────────────────────────────────

func _test_phase_line_crossing_emits_signal() -> Dictionary:
	const NAME := "_check_phase_line_crossing emits ball_phase_line_crossed"
	_reset()
	_ball().possessing_team_id = 0
	_ball().holder_id          = ""
	_ball().position           = Vector2(30.5, 10.0)
	_sys._prev_ball_x          = 29.5
	_set_phase_lines(true)
	var captured: Array = []
	var conn := func(tid: int, li: int): captured.append([tid, li])
	EventBus.ball_phase_line_crossed.connect(conn)
	_sys.call("_check_phase_line_crossing", _ball())
	EventBus.ball_phase_line_crossed.disconnect(conn)
	if captured.size() != 1:
		_reset()
		return _r(NAME, false, "signal fired %d times (expected 1)" % captured.size())
	var args: Array = captured[0]
	var ok: bool = args[0] == 0 and args[1] == 0
	_reset()
	return _r(NAME, ok, "" if ok else "team=%s line=%s" % [args[0], args[1]])

func _test_phase_line_resets_charge_timer() -> Dictionary:
	const NAME := "phase line crossing resets ball.charge_timer to 0"
	_reset()
	_ball().possessing_team_id = 0
	_ball().holder_id          = ""
	_ball().position           = Vector2(50.5, 10.0)
	_ball().charge_timer       = 5.0
	_sys._prev_ball_x          = 49.5
	_set_phase_lines(false)
	_sys._phase_lines_activated[1] = true   # only arm line index 1 (x=50.0)
	_sys.call("_check_phase_line_crossing", _ball())
	var ok: bool = _ball().charge_timer == 0.0
	_reset()
	return _r(NAME, ok, "" if ok else "charge_timer=%.2f" % _ball().charge_timer)

func _test_phase_line_already_crossed_not_re_emitted() -> Dictionary:
	const NAME := "already-crossed phase line is not re-emitted"
	_reset()
	_ball().possessing_team_id = 0
	_ball().holder_id          = ""
	_ball().position           = Vector2(30.5, 10.0)
	_sys._prev_ball_x          = 29.5
	_set_phase_lines(false)   # all lines de-armed (already crossed)
	var count := 0
	var conn := func(_t: int, _l: int): count += 1
	EventBus.ball_phase_line_crossed.connect(conn)
	_sys.call("_check_phase_line_crossing", _ball())
	EventBus.ball_phase_line_crossed.disconnect(conn)
	_reset()
	return _r(NAME, count == 0, "" if count == 0 else "signal emitted %d times" % count)
