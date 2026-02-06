extends CanvasLayer

func _ready() -> void:
	# Ensure this screen creates a clean slate feel
	# (Optional: Play a victory sound here!)
	pass

func _on_return_button_pressed() -> void:
	# 1. Unpause the game (so the Menu can run)
	get_tree().paused = false
	
	# 2. Reset the Manager for the next run (Important!)
	GameManager.reset() # We need to make sure this function exists and resets the timer!
	
	# 3. Go to Menu
	get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")
