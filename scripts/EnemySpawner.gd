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

func _on_level_up() -> void:
	# Reset rhythm
	$Timer.stop()
	$Timer.start()
	
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
	var viewport_size = get_viewport_rect().size
	var safe_distance = max(viewport_size.x, viewport_size.y) / 2 + 1000 # Slightly tighter
	var angle = randf() * TAU
	var spawn_pos = player.global_position + (Vector2(cos(angle), sin(angle)) * safe_distance)
	
	enemy.global_position = spawn_pos
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
