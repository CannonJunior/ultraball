class_name QuickReleaseTactics
extends "res://systems/ai/tactics/BalancedTactics.gd"

## Pass as soon as anyone is even slightly ahead — always prefer throwing to running.

func _pass_threshold() -> float:
	return 1.0  # almost any forward position triggers a pass
