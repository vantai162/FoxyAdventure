extends Control

signal continue_game
signal new_game

@onready var panel := $Panel


func on_continue_pressed():
	print("Continue pressed!")
	emit_signal("continue_game")
	queue_free() 

func on_new_game_pressed():
	print("New game pressed!")
	emit_signal("new_game")
	queue_free()
func _on_cancel_pressed():
	queue_free()
