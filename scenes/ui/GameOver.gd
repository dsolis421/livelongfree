extends CanvasLayer

func _ready() -> void:
	# This ensures the menu works even if we pause the game
	process_mode = Node.PROCESS_MODE_ALWAYS

func _on_button_pressed() -> void:
	# Unpause the game (if we paused it)
	get_tree().paused = false
	# Reload the current scene (Main.tscn)
	get_tree().reload_current_scene()
