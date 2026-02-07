extends CanvasLayer

func _ready() -> void:
	# find_child searches through all children, grandchildren, etc.
	# to find these buttons, so it works regardless of your container structure.
	var next_btn = find_child("NextSector", true, false)
	var return_btn = find_child("ReturnToBase", true, false)
	
	if next_btn:
		next_btn.pressed.connect(_on_next_mission_pressed)
	else:
		print("Error: Could not find 'NextSector'")
	
	if return_btn:
		return_btn.pressed.connect(_on_return_pressed)

func _on_next_mission_pressed() -> void:
	print("Loading Next Mission...")
	
	# 1. Reset Game State
	GameManager.reset()
	
	# 2. IMPORTANT: Unpause!
	get_tree().paused = false
	
	# 3. Reload Main Scene (Triggers Insertion Drone)
	get_tree().change_scene_to_file("res://scenes/Main.tscn")
	queue_free()

func _on_return_pressed() -> void:
	print("Returning to Base...")
	
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")
	queue_free()
