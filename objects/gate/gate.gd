# GateContainer.gd
extends Node2D
class_name Gate

func open_gate() -> void:
	$AnimationPlayer.play("open")

func close_gate() -> void:
	$AnimationPlayer.play("close")


func _on_lever_lever_activated() -> void:
	pass # Replace with function body.
