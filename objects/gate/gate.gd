# GateContainer.gd
extends Node2D
class_name Gate

func open_gate() -> void:
	$AnimationPlayer.play("open")

func close_gate() -> void:
	$AnimationPlayer.play("close")
