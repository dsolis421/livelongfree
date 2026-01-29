extends CanvasLayer

func _ready() -> void:
	# Ensure it is hidden when the game starts/restarts
	visible = false 
	# Also ensure the game isn't paused by mistake
	get_tree().paused = false 

func _on_player_died() -> void:
	# This function listens for the player's death signal
	print("GAME OVER SCREEN ACTIVATED") # <--- Add this
	visible = true
	get_tree().paused = true

func _on_button_pressed() -> void:
	# Reset the manager
	GameManager.reset()
	# Unpause BEFORE reloading (critical!)
	get_tree().paused = false
	# Reload the entire scene
	get_tree().reload_current_scene()
