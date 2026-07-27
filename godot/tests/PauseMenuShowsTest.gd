## Regression test: PauseMenu must appear when EventBus.game_paused(true) fires
## and disappear when EventBus.game_paused(false) fires.
##
## Run headlessly:
##   godot --headless --path godot/ tests/PauseMenuShowsTest.tscn
##
## Or open tests/PauseMenuShowsTest.tscn in the editor and press Play Scene.
extends Node

func _ready() -> void:
	await get_tree().process_frame
	_run_tests()

func _run_tests() -> void:
	var passed := 0
	var failed := 0

	for result in [
		await _test_shows_on_game_paused_true(),
		await _test_hides_on_game_paused_false(),
		await _test_children_built(),
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

func _make_result(name: String, ok: bool, msg: String = "") -> Dictionary:
	return {"name": name, "ok": ok, "msg": msg}

func _load_pause_menu() -> Control:
	var script := load("res://scenes/game/hud/PauseMenu.gd")
	if script == null:
		return null
	var pm: Control = script.new()
	add_child(pm)
	return pm

# ── Individual tests ───────────────────────────────────────────────────────────

func _test_shows_on_game_paused_true() -> Dictionary:
	const NAME := "PauseMenu becomes visible when game_paused(true) fires"
	var pm := _load_pause_menu()
	if pm == null:
		return _make_result(NAME, false, "PauseMenu.gd failed to load (parse error)")

	await get_tree().process_frame
	EventBus.game_paused.emit(true)
	await get_tree().process_frame

	var ok := pm.visible
	get_tree().paused = false
	pm.queue_free()
	return _make_result(NAME, ok, "" if ok else "visible == false after game_paused(true)")

func _test_hides_on_game_paused_false() -> Dictionary:
	const NAME := "PauseMenu hides when game_paused(false) fires"
	var pm := _load_pause_menu()
	if pm == null:
		return _make_result(NAME, false, "PauseMenu.gd failed to load (parse error)")

	await get_tree().process_frame
	EventBus.game_paused.emit(true)
	await get_tree().process_frame
	EventBus.game_paused.emit(false)
	await get_tree().process_frame

	var ok := not pm.visible
	get_tree().paused = false
	pm.queue_free()
	return _make_result(NAME, ok, "" if ok else "visible == true after game_paused(false)")

func _test_children_built() -> Dictionary:
	const NAME := "PauseMenu builds UI children without crashing"
	var pm := _load_pause_menu()
	if pm == null:
		return _make_result(NAME, false, "PauseMenu.gd failed to load (parse error)")

	await get_tree().process_frame
	var ok := pm.get_child_count() > 0
	pm.queue_free()
	return _make_result(NAME, ok, "" if ok else "no children — _build_ui() likely crashed")
