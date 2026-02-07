extends Node2D

# Update this path if you saved "Drone" in a different folder
var drone_scene = preload("res://scenes/objects/Drone.tscn")

func _ready() -> void:
	# Listen for the signal from GameManager
	GameManager.extraction_requested.connect(spawn_drone)
	spawn_insertion_drone()

func spawn_insertion_drone() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if not player: return
	
	# Create Drone
	var drone = drone_scene.instantiate()
	add_child(drone)
	
	# Connect the "Done" signal to the Game Start logic
	drone.insertion_complete.connect(_start_game_logic)
	
	# Go!
	drone.start_insertion(player)
	
func spawn_drone() -> void:
	# 1. Find the Player (The Drone needs a target)
	var player = get_tree().get_first_node_in_group("player")
	
	if not player:
		print("ERROR: Player dead or missing. Cannot extract.")
		GameManager.on_extraction_complete() # Failsafe: Trigger win anyway
		return

	print("MAIN: Spawning Drone...")

	# 2. Create the Drone
	var drone = drone_scene.instantiate()
	
	# 3. Add it to the world
	add_child(drone)
	
	# 4. Command the Drone to start the sequence
	if drone.has_method("start_extraction"):
		drone.start_extraction(player)
	else:
		print("ERROR: Drone script missing 'start_extraction' function!")
		
func _start_game_logic() -> void:
	print("--- DROP COMPLETE. MISSION START. ---")
	
	# 1. Enable Player Controls
	var player = get_tree().get_first_node_in_group("player")
	if player:
		player.set_physics_process(true)
		
	# 2. Reset the Timer
	# (So the 3 seconds of animation don't eat into the mission time)
	GameManager.reset()
	
	# 3. Start Spawners (Optional)
	# If your spawner has a "start" function, call it here.
	# Otherwise, it's fine if it was already running in background.
