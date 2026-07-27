## Regression test: FinalReport must become visible when EventBus.game_over fires.
##
## Run headlessly:
##   godot --headless --path godot/ tests/FinalReportShowsTest.tscn
##
## Or open tests/FinalReportShowsTest.tscn in the editor and press Play Scene.
extends Node

func _ready() -> void:
	await get_tree().process_frame
	_run_tests()

func _run_tests() -> void:
	var passed := 0
	var failed := 0

	# ── test: screen becomes visible after game_over ───────────────────────────
	var result := await _test_final_report_shows_on_game_over()
	if result.ok:
		passed += 1
		print("PASS  ", result.name)
	else:
		failed += 1
		print("FAIL  ", result.name, " — ", result.msg)

	# ── test: screen renders without crashing (children exist) ─────────────────
	var result2 := await _test_final_report_has_children_after_game_over()
	if result2.ok:
		passed += 1
		print("PASS  ", result2.name)
	else:
		failed += 1
		print("FAIL  ", result2.name, " — ", result2.msg)

	print("")
	print("Results: %d passed, %d failed" % [passed, failed])
	if failed > 0:
		get_tree().quit(1)
	else:
		get_tree().quit(0)

# ── Helpers ────────────────────────────────────────────────────────────────────

func _make_result(name: String, ok: bool, msg: String = "") -> Dictionary:
	return {"name": name, "ok": ok, "msg": msg}

func _seed_match_state() -> void:
	MatchState.players.clear()
	for i in 4:
		var pid := "p%d" % i
		var rec := MatchState.PlayerRecord.new()
		rec.player_id    = pid
		rec.display_name = "Player %d" % i
		rec.team_id      = 0 if i < 2 else 1
		rec.class_id     = "wrecker"
		rec.is_alive     = true
		rec.is_on_field  = true
		MatchState.players[pid] = rec
	MatchState.scores  = [14, 7, 0]
	MatchState.kills   = [3, 1, 0]
	MatchState.game_over = false

func _cleanup_match_state() -> void:
	MatchState.players.clear()
	MatchState.scores  = [0, 0, 0]
	MatchState.kills   = [0, 0, 0]
	MatchState.game_over = false

# ── Individual tests ───────────────────────────────────────────────────────────

func _test_final_report_shows_on_game_over() -> Dictionary:
	const NAME := "FinalReport becomes visible when game_over fires"
	_seed_match_state()

	var script := load("res://scenes/game/hud/FinalReport.gd")
	if script == null:
		return _make_result(NAME, false, "FinalReport.gd failed to load (parse error)")

	var fr: Control = script.new()
	add_child(fr)
	await get_tree().process_frame

	EventBus.game_over.emit(0, 14, 7, 0)
	await get_tree().process_frame

	var ok := fr.visible
	var msg := "" if ok else "visible == false after game_over emit"

	get_tree().paused = false
	fr.queue_free()
	_cleanup_match_state()
	return _make_result(NAME, ok, msg)

func _test_final_report_has_children_after_game_over() -> Dictionary:
	const NAME := "FinalReport builds UI children without crashing"
	_seed_match_state()

	var script := load("res://scenes/game/hud/FinalReport.gd")
	if script == null:
		return _make_result(NAME, false, "FinalReport.gd failed to load (parse error)")

	var fr: Control = script.new()
	add_child(fr)
	await get_tree().process_frame

	EventBus.game_over.emit(0, 14, 7, 0)
	await get_tree().process_frame

	var ok := fr.get_child_count() > 0
	var msg := "" if ok else "no children — _rebuild() likely crashed before add_child"

	get_tree().paused = false
	fr.queue_free()
	_cleanup_match_state()
	return _make_result(NAME, ok, msg)
