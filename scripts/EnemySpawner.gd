extends Node2D

# --- THE MENU ---
@export var goblin_scene: PackedScene
@export var sprinter_scene: PackedScene
@export var brute_scene: PackedScene
@export var phantom_scene: PackedScene
@export var boss_scene: PackedScene 

func _ready() -> void:
	# Listen for standard level ups (to reset timer rhythm)
	GameManager.level_up_triggered.connect(_on_level_up)
	
	# NEW: Listen for the Boss Request
	GameManager.boss_spawn_requested.connect(spawn_boss)

func _on_level_up(new_level: int) -> void:
	# Reset rhythm
	$Timer.stop()
	$Timer.start()
	pass
	
func _on_timer_timeout() -> void:
	var player = get_tree().get_first_node_in_group("player")
	if player == null: return

	# --- BOSS FIGHT SPAWN REDUCTION ---
	# If Boss is active, skip 75% of spawn cycles (Fodder throttle)
	if GameManager.is_boss_active:
		if randf() < 0.75: 
			return 
	# ----------------------------------

	var enemy_choice = pick_enemy_by_level()
	if enemy_choice == null: return

	var enemy = enemy_choice.instantiate()
	
	# Donut Spawn Logic
	# NEW: Rectangular Spawn Logic (Fits Portrait Mode)
	
	# 1. Get the real world size of the screen (Accounting for Zoom!)
	var camera = get_viewport().get_camera_2d()
	var zoom = camera.zoom if camera else Vector2.ONE
	var view_size = get_viewport_rect().size / zoom
	
	# 2. Add a buffer so they spawn slightly off-screen
	var buffer = 700 
	var half_w = (view_size.x / 2) + buffer
	var half_h = (view_size.y / 2) + buffer

	# 3. Pick a random edge (0=Top, 1=Bottom, 2=Left, 3=Right)
	var side = randi() % 4
	var spawn_offset = Vector2.ZERO

	match side:
		0: # Top Edge
			spawn_offset = Vector2(randf_range(-half_w, half_w), -half_h)
		1: # Bottom Edge
			spawn_offset = Vector2(randf_range(-half_w, half_w), half_h)
		2: # Left Edge
			spawn_offset = Vector2(-half_w, randf_range(-half_h, half_h))
		3: # Right Edge
			spawn_offset = Vector2(half_w, randf_range(-half_h, half_h))

	# 4. Apply position relative to player
	enemy.global_position = player.global_position + spawn_offset
	
	get_tree().current_scene.add_child(enemy)

func spawn_boss() -> void:
	if boss_scene == null:
		print("ERROR: No Boss Scene assigned!")
		return

	print("--- SPAWNER RECEIVED BOSS COMMAND ---")
	
	var boss = boss_scene.instantiate()
	
	var player = get_tree().get_first_node_in_group("player")
	if player:
		# 1. Calculate Dynamic Safe Distance
		# Get the screen dimensions
		var viewport_size = get_viewport_rect().size
		
		# Take the largest dimension (width or height), cut it in half, 
		# and add a healthy buffer (e.g., 400px) so he is DEFINITELY off-screen.
		var safe_distance = max(viewport_size.x, viewport_size.y) / 2 + 800
		
		# 2. Pick a random angle
		var angle = randf() * TAU
		
		# 3. Apply the distance
		var offset = Vector2(cos(angle), sin(angle)) * safe_distance
		boss.global_position = player.global_position + offset
	
	get_tree().current_scene.add_child(boss)

func pick_enemy_by_level() -> PackedScene:
	# Your existing logic remains exactly the same
	var current_level = GameManager.level
	var roll = randf() 
	
	if current_level >= 6:
		if roll < 0.05: return phantom_scene 
		elif roll < 0.15: return brute_scene 
		elif roll < 0.45: return sprinter_scene
		else: return goblin_scene
	elif current_level >= 3:
		if roll < 0.2: return sprinter_scene
		else: return goblin_scene
	else:
		return goblin_scene
